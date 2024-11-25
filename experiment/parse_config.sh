#!/bin/bash

. ./utils/initialize_execution.sh

function fn_populate_config_variables() {
    local pair
    for pair in $@; do
        export $pair
    done
}

function fn_get_variable_export_strings_from_config() {
    # Get .config object > get keys value pairs > filter out null values > prepare for export
    echo $@ | jq -r '.config | to_entries | .[] | select(.value != null and .value != {}) | "conf_" + .key + "=" + "\"" + (.value | tostring) + "\"" '
}

function fn_populate_config_variables_from_json() {
    local config_json=$1
    local config_keys_value_pairs=$(fn_get_variable_export_strings_from_config "$config_json")
    fn_populate_config_variables "$config_keys_value_pairs"
}

# Populate execution variables
resource_tag="service"
resource_config_path=${resource_tag_to_directory_map[$resource_tag]}
resource_name="service-2"

# Fetch json config for provided stack
config_file_content=$(echo "$(<$root_directory/experiment/example.config.json)")

# Populate stack level config variables
fn_populate_config_variables_from_json "$config_file_content"

# Populate resource level config variables
resource_content=$(echo $config_file_content | jq -r --arg path "$resource_config_path" --arg name "$resource_name" '.[$path][] | select(.name == $name)')
fn_populate_config_variables_from_json "$resource_content"

unset config_file_content
fn_print_variables
