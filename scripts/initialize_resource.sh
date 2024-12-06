#!/bin/bash

# Initialize execution
. ./utils/prepare_runtime.sh

fn_request_mandatory_input() {
    local input_name=${1:-parameter}
    local input_variable_name=${2:-user_input}
    fn_input_text "Enter $input_name for initializtion: " $input_variable_name

    if [ -z "${!input_variable_name}" ]; then
        fn_error "$input_name must be provided for initializtion"
        fn_fatal
    fi
}

fn_create_resource_config_from_user_input() {
    # First parameter is the resource tag
    # Should be one of the following: "image", "repo", "ssm-parameter", "secret", "service"
    resource_tag=$1

    # Validate resource_tag
    if [ -z "$resource_tag" ]; then
        fn_error "resource_tag must be provided"
        fn_fatal
    fi

    fn_populate_and_validate_resource_directory_from_resource_tag

    # Get user input for name of resource
    fn_request_mandatory_input "$resource_tag name" resource_name

    # Create resource config
    if [ -f "$resource_directory/$resource_name.config.sh" ]; then
        fn_error "$resource_name $resource_tag already exists"
        fn_fatal
    fi
    cp templates/$resource_tag.config.sh $resource_directory/$resource_name.config.sh || fn_fatal

    fn_info "Config generated in $resource_directory/$resource_name.config.sh"
}

fn_choose_from_menu "Select resource to initialize:" selected_resource "${!resource_tag_to_directory_map[@]}"

case $selected_resource in
"repo")
    # fn_fatal "$selected_resource initialization not available yet"
    fn_request_mandatory_input "Git repository URL" git_url

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
