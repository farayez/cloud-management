#!/bin/bash

# Declare functions
. ./utils/declare_functions.sh

fn_define_console_colors

declare -A resource_tag_directory_map=(
    ["image"]="images"
    ["repo"]="repos"
    ["ssm-parameter"]="ssm_parameters"
    ["secret"]="secrets"
    ["service"]="services"
)

fn_request_mandatory_input() {
    local input_name=${1:-parameter}
    local input_variable_name=${2:-user_input}
    fn_input_text "Enter $input_name for initializtion: " $input_variable_name

    if [ -z "${!input_variable_name}" ]; then
        fn_error "$input_name must be provided for initializtion"
        fn_fatal
    fi
}

fn_create_resource_directory_from_user_input() {
    # First parameter is the resource tag
    # Should be one of the following: "image", "repo", "ssm-parameter", "secret", "service"
    local resource_tag=$1
    if [ -z "$resource_tag" ]; then
        fn_error "resource_tag must be provided"
        fn_fatal
    fi
    directory=${resource_tag_directory_map[$resource_tag]}
    if [ -z "$directory" ]; then
        fn_error "Unsupported resource tag: $resource_tag"
        fn_fatal
    fi

    # Get user input for name of resource
    fn_request_mandatory_input "$resource_tag name" resource_name

    # Create resource directory
    if [ -d "$directory/$resource_name" ]; then
        fn_error "$resource_name $resource_tag already exists"
        fn_fatal
    fi
    mkdir -p $directory/$resource_name || fn_fatal

    fn_info "$directory/$resource_name directory created"
}

fn_copy_config_template() {
    cp templates/$selected_resource.config.sh $directory/$resource_name/config.sh || fn_fatal
    fn_info "Config template generated"
}

fn_choose_from_menu "Select resource to initialize:" selected_resource "${!resource_tag_directory_map[@]}"

case $selected_resource in
"repo")
    fn_fatal "$selected_resource initialization not available yet"
    ;;
"image")
    fn_create_resource_directory_from_user_input $selected_resource
    fn_copy_config_template
    ;;
"ssm-parameter")
    fn_fatal "$selected_resource initialization not available yet"
    ;;
"secret")
    fn_fatal "$selected_resource initialization not available yet"
    ;;
"service")
    fn_create_resource_directory_from_user_input $selected_resource
    fn_copy_config_template
    ;;
*)
    fn_fatal "invalid selection"
    ;;
esac

fn_success "Resource Initialized"
