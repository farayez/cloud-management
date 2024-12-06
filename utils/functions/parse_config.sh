#!/bin/bash

function fn_populate_config_variables() {
    # Fetch json config for provided stack
    local config_file_content=$(echo "$(<$root_directory/example.config.json)")

    # Populate stack level config variables
    fn_populate_config_variables_from_json "$config_file_content"

    # Populate resource level config variables
    local resource_content=$(echo $config_file_content | jq -r --arg path "$resource_config_path" --arg name "$resource_name" '.[$path][] | select(.name == $name)')
    fn_populate_config_variables_from_json "$resource_content"
}

function fn_populate_config_variables_from_json() {
    local config_json=$1
    local config_keys_value_pairs=$(fn_get_variable_export_strings_from_json "$config_json")
    fn_export_variables "$config_keys_value_pairs"
}

function fn_get_variable_export_strings_from_json() {
    # Get .config object > get keys value pairs > filter out null values > prepare for export
    echo $@ | jq -r '.config | to_entries | .[] | select(.value != null and .value != {}) | "" + .key + "=" + "" + (.value | tostring) + "" '
}

function fn_export_variables() {
    local pair
    for pair in $@; do
        export $pair
    done
}
