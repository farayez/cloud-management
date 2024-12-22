#!/bin/bash

# Initialize execution
. ./utils/prepare_runtime.sh

fn_validate_json_in_file() {
    fn_info "Validating JSON in $1"
    local t
    if ! t=$(jq -re . "$1"); then
        fn_error "Invalid JSON in $1"
        fn_fatal
    fi
}

fn_create_resource_config_from_user_input() {
    # First parameter is the resource tag
    # Should be one of the following: "image", "repo", "ssm_parameter", "secret", "service", "task_definition"
    resource_tag=$1

    # Validate resource_tag
    if [ -z "$resource_tag" ]; then
        fn_error "resource_tag must be provided"
        fn_fatal
    fi

    # Get user input for name of resource
    fn_request_mandatory_text_input "Enter $resource_tag name for initializtion: " resource_name

    # Get config template filename
    local config_templates_file=$root_directory/templates/config_templates.json

    # Validate config template file
    if [ ! -f $config_templates_file ]; then
        fn_error "Config template file not found"
        fn_fatal
    fi
    fn_validate_json_in_file $config_templates_file

    # Gather config templates from config template file
    local resource_config
    resource_config=$(jq -e -r ".${resource_tag}" "$config_templates_file") || fn_fatal
    local common_config
    common_config=$(jq -e -r '.common' "$config_templates_file") || fn_fatal

    # Get active config filename
    local config_file=configurations/default.config.json

    # Create default config file if it doesn't exist or is empty
    if [ ! -f $config_file ] || [ -z "$(cat $config_file)" ]; then
        jq '{}' -n >$config_file

        # Add common config to the default config file if it doesn't exist
        local tmp
        tmp=$(jq ".config += $common_config" $config_file) || fn_fatal
        echo "$tmp" >$config_file
        fn_info "Default config file created in $config_file"
    fi

    # Validate default config file
    fn_validate_json_in_file $config_file

    # Check whether resource already exists in config file
    local existing_resource
    existing_resource=$(jq -r ".${resource_tag}[] | select(.name == \"$resource_name\")" $config_file 2>/dev/null)
    if [ -n "$existing_resource" ]; then
        fn_error "Resource $resource_name already exists in $config_file"
        fn_fatal
    fi

    # Add template resource configurations to config file
    local config_to_add
    config_to_add="[{\"name\": \"$resource_name\", \"config\": $resource_config}]"
    tmp=$(jq ".${resource_tag} += ${config_to_add}" $config_file) || fn_fatal
    echo "$tmp" >$config_file

    fn_info "Config added in $config_file"
}

fn_choose_from_menu "Select resource to initialize:" selected_resource "${!resource_tag_to_directory_map[@]}"

case $selected_resource in
"repo")
    # fn_fatal "$selected_resource initialization not available yet"
    fn_request_mandatory_text_input "Enter Git repository URL for initializtion: " git_url

    fn_populate_and_validate_resource_directory_from_resource_tag

    resource_tag=$selected_resource
    fn_populate_and_validate_resource_directory_from_resource_tag
    git -C $resource_directory clone $git_url || fn_fatal
    ;;
"image")
    fn_create_resource_config_from_user_input $selected_resource
    ;;
"ssm_parameter")
    fn_create_resource_config_from_user_input $selected_resource
    ;;
"secret")
    fn_fatal "$selected_resource initialization not available yet"
    ;;
"service")
    fn_create_resource_config_from_user_input $selected_resource
    ;;
"task_definition")
    fn_create_resource_config_from_user_input $selected_resource

    fn_populate_and_validate_resource_directory_from_resource_tag

    # Copy task definition template
    if [ -f "$resource_directory/definitions/$resource_name.pushable.json" ]; then
        fn_error "Task definition file for $resource_name already exists. Not overwriting."
    else
        cp templates/task-definition.template.json $resource_directory/definitions/$resource_name.pushable.json || fn_fatal
    fi
    ;;
*)
    fn_fatal "invalid selection"
    ;;
esac

fn_success "Resource Initialized"
