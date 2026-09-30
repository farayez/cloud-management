#!/bin/bash

# Initialize execution
. ./utils/prepare_runtime.sh

config_templates_file=$root_directory/templates/config_templates.json
configurations_directory=$root_directory/configurations
new_config_option="+ Create new configuration"

fn_validate_json_in_file() {
    jq -e . "$1" >/dev/null || fn_fatal "Invalid JSON in $1"
}

# Names end up in file paths and JSON, so restrict them to a safe character set
fn_validate_name() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || fn_fatal "Invalid name '$1'. Allowed characters: letters, digits, '.', '_', '-'"
}

# Usage: fn_update_json_file <file> [jq options...] <filter>
fn_update_json_file() {
    local file=$1
    shift
    local updated
    updated=$(jq "$@" "$file") || fn_fatal "Failed to update $file"
    echo "$updated" >"$file"
}

fn_create_config_file() {
    local config_name
    fn_request_mandatory_text_input "Enter new configuration name: " config_name
    fn_validate_name "$config_name"

    config=$config_name.config.json
    local file=$configurations_directory/$config
    [ -e "$file" ] && fn_fatal "Configuration file $file already exists"

    local content
    content=$(jq --arg name "$config_name" '{config: (.common + {
        config_name: $name,
        task_definitions_directory: "resources/\($name)/task_definitions",
        ssm_parameters_directory: "resources/\($name)/ssm_parameters",
        cf_parameter_file_directory: "resources/\($name)/cloudformation_parameters"
    })}' "$config_templates_file") || fn_fatal "Failed to create $file"
    echo "$content" >"$file"

    fn_info "Configuration file created in $file"
}

# Populates config_file from the config argument or user selection
fn_select_config_file() {
    if [ -z "$config" ]; then
        local config_files=() file
        for file in "$configurations_directory"/*.config.json; do
            [ -f "$file" ] && config_files+=("$(basename "$file")")
        done
        fn_choose_from_menu "Select configuration file:" config "${config_files[@]}" "$new_config_option"
    fi

    if [ "$config" = "$new_config_option" ]; then
        fn_create_config_file
    fi

    fn_validate_name "$config"
    config_file=$configurations_directory/$config
    [ -f "$config_file" ] || fn_fatal "Configuration file $config_file not found"
    fn_validate_json_in_file "$config_file"
}

fn_add_resource_to_config_file() {
    fn_request_mandatory_text_input "Enter $resource_tag name for initialization: " resource_name
    fn_validate_name "$resource_name"

    if jq -e --arg tag "$resource_tag" --arg name "$resource_name" \
        '(.[$tag] // [])[] | select(.name == $name)' "$config_file" >/dev/null; then
        fn_fatal "$resource_tag $resource_name already exists in $config"
    fi

    local resource_template
    resource_template=$(jq -e --arg tag "$resource_tag" '.[$tag]' "$config_templates_file") ||
        fn_fatal "No template found for $resource_tag"

    fn_update_json_file "$config_file" \
        --arg tag "$resource_tag" \
        --arg name "$resource_name" \
        --argjson template "$resource_template" \
        '.[$tag] = ((.[$tag] // []) + [{name: $name} + $template])'

    fn_info "$resource_tag $resource_name added to $config_file"
}

fn_create_task_definition_file() {
    local task_definitions_directory
    task_definitions_directory=$(jq -r '.config.task_definitions_directory // empty' "$config_file")
    local directory=$root_directory/${task_definitions_directory:-task_definitions}
    local file=$directory/$resource_name.json

    if [ -f "$file" ]; then
        fn_warning "Task definition file $file already exists. Not overwriting."
        return
    fi

    mkdir -p "$directory" || fn_fatal
    local content
    content=$(jq --arg family "$resource_name" '.family = $family' \
        "$root_directory/templates/task-definition.template.json") || fn_fatal "Failed to create $file"
    echo "$content" >"$file"

    fn_info "Task definition file created in $file"
}

fn_clone_repo() {
    local git_url
    fn_request_mandatory_text_input "Enter Git repository URL for initialization: " git_url
    mkdir -p "$root_directory/repos" || fn_fatal
    git -C "$root_directory/repos" clone -- "$git_url" || fn_fatal
}

fn_parse_arguments "$@" || fn_fatal

[ -f "$config_templates_file" ] || fn_fatal "Config template file $config_templates_file not found"
fn_validate_json_in_file "$config_templates_file"

mapfile -t resource_tags < <(jq -r 'del(.common) | keys_unsorted[]' "$config_templates_file")
fn_choose_from_menu "Select resource to initialize:" resource_tag "${resource_tags[@]}" "repo"

# Repos are cloned into repos/ and referenced by name from config files
if [ "$resource_tag" = "repo" ]; then
    fn_clone_repo
    fn_success "Repo Initialized"
fi

fn_select_config_file
fn_add_resource_to_config_file

if [ "$resource_tag" = "task_definition" ]; then
    fn_create_task_definition_file
fi

fn_success "Resource Initialized"
