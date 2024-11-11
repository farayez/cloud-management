#!/bin/bash

function fn_parse_arguments() {
    local argument
    for argument in "$@"; do
        local key=$(echo $argument | cut -f1 -d=)

        local key_length=${#key}
        local value="${argument:$key_length+1}"

        if [ ! -z $value ]; then
            export "$key"="$value"
        fi
    done
}

# Function to validate variables
function fn_validate_variables() {
    local variable
    local validated=1
    for variable in $@; do
        if [ -z "${!variable}" ]; then
            fn_error "$variable must be set"
            validated=0
        fi
    done

    if [ $validated -eq 0 ]; then
        fn_fatal "Config validation failed"
    fi

    fn_info "\nCONFIG VALIDATION SUCCESSFUL"
}

function fn_populate_and_validate_resource_tag_from_current_script_name() {
    resource_tag=${script_name_to_resource_tag_map[$current_script_name]}

    if [ -z "$resource_tag" ]; then
        fn_error "resource_tag must be provided"
        fn_fatal
    fi
}

# Populate the resource_directory variable from the resource_tag using the
#     resource_tag_to_directory_map associative array.
function fn_populate_and_validate_resource_directory_from_resource_tag() {
    resource_directory=${resource_tag_to_directory_map[$resource_tag]}

    if [ -z "$resource_directory" ]; then
        fn_error "Unsupported resource tag: $resource_tag"
        fn_fatal
    fi

    # Prepend root directory
    resource_directory="$root_directory/$resource_directory"

    # Create resource directory if it doesn't exist
    if [ ! -d $resource_directory ]; then
        mkdir -p $resource_directory || fn_fatal
        cp templates/resource.gitignore.template $resource_directory/.gitignore || fn_fatal
    fi
}

function fn_populate_and_validate_resource_name() {
    resource_name=$1

    # Validate resource_name argument
    if [ -z $resource_name ]; then
        fn_error "1st argument must be the name of the $resource_tag"
        fn_fatal
    fi

    # Check for resource config
    if [ ! -f "$resource_directory/$resource_name.config.sh" ]; then
        fn_error "No $resource_tag found with name $resource_name"
        fn_fatal
    fi
}

function fn_populate_and_validate_resource_config_file() {
    resource_config_file="$resource_directory/$resource_name.config.sh"
}

# List all variables in declared_variables
function fn_list_declared_variables() {
    unset declared_variables
    declared_variables=($(compgen -A variable | grep '^[a-z].*' | grep -v '^npm_*'))
}

function fn_get_all_resource_names_in_directory() {
    local resource_directory=$1
    local files=($(ls -1 $resource_directory/*.config.sh 2>/dev/null))

    if [ -z "$files" ]; then
        return
    fi

    local resource_names=($(basename -a ${files[@]} | sed -e 's/.config.sh$//' | sort -u))
    echo "${resource_names[@]}"
}
