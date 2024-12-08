#!/bin/bash

# Initialize execution
. ./utils/prepare_runtime.sh

fn_create_resource_config_from_user_input() {
    # First parameter is the resource tag
    # Should be one of the following: "image", "repo", "ssm-parameter", "secret", "service", "task-definition"
    resource_tag=$1

    # Validate resource_tag
    if [ -z "$resource_tag" ]; then
        fn_error "resource_tag must be provided"
        fn_fatal
    fi

    # Get config template filename
    local config_templates_file=$root_directory/templates/config_templates.json

    # Validate config template file
    if [ ! -f $config_templates_file ]; then
        fn_error "Config template file not found"
        fn_fatal
    fi

    # Get active config filename
    local config_file=configurations/default.config.json

    # Create default config file if it doesn't exist
    if [ ! -f $config_file ]; then
        # Create default config file
        jq '{}' -n >$config_file

        # Add common config to the default config file
        local common_config
        common_config=$(jq -e -r '.common' "$config_templates_file") || fn_fatal
        jq --argjson common_config "$common_config" '.config += $common_config' $config_file -n >$config_file
    fi

    # Get user input for name of resource
    fn_request_mandatory_text_input "Enter $resource_tag name for initializtion: " resource_name

    # Create resource already exists in config file

    # Add template resource configurations to config file

    fn_info "Config added in $config_file"
}

# fn_choose_from_menu "Select resource to initialize:" selected_resource "${!resource_tag_to_directory_map[@]}"
selected_resource="image"

case $selected_resource in
"repo")
    # fn_fatal "$selected_resource initialization not available yet"
    fn_request_mandatory_text_input "Enter Git repository URL for initializtion: " git_url

    resource_tag=$selected_resource
    fn_populate_and_validate_resource_directory_from_resource_tag
    git -C $resource_directory clone $git_url || fn_fatal
    ;;
"image")
    fn_create_resource_config_from_user_input $selected_resource
    ;;
"ssm-parameter")
    fn_create_resource_config_from_user_input $selected_resource
    ;;
"secret")
    fn_fatal "$selected_resource initialization not available yet"
    ;;
"service")
    fn_create_resource_config_from_user_input $selected_resource
    ;;
"task-definition")
    fn_create_resource_config_from_user_input $selected_resource

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
