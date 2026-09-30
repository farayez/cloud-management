#!/bin/bash

function fn_populate_config_variables() {
    # Fetch json config for provided stack
    local config_file="${config:-default.config.json}"
    local config_file_content=$(echo "$(<$root_directory/configurations/$config_file)")

    # Populate stack level config variables
    fn_populate_config_variables_from_json "$config_file_content"

    # Populate resource level config variables
    local resource_content=$(echo $config_file_content | jq -r --arg path "$resource_tag" --arg name "$resource_name" '.[$path][] | select(.name == $name)')
    fn_populate_config_variables_from_json "$resource_content"

    # Populate sub-resource level config variables for the selected item
    local sub_array_key="${script_name_to_sub_resource_array_map[$current_script_name]}"
    if [ -n "$sub_array_key" ] && [ -n "$item" ]; then
        local item_content=$(echo "$resource_content" | jq -c --arg key "$sub_array_key" --arg item "$item" \
            '(.[$key] // [])[] | select(.name == $item) | {config: del(.name)}')
        [ -z "$item_content" ] && fn_fatal "No $sub_array_key entry found with name $item"
        fn_populate_config_variables_from_json "$item_content"
    fi
}

function fn_populate_config_variables_from_json() {
    local config_json=$1
    local config_keys_value_pairs=$(fn_get_variable_export_strings_from_json "$config_json")

    # Process each line separately to handle quoted values properly
    while IFS= read -r pair; do
        if [[ -n "$pair" ]]; then
            export "$pair"
        fi
    done <<< "$config_keys_value_pairs"
}

function fn_get_variable_export_strings_from_json() {
    # Get .config object > get keys value pairs > filter out null values > prepare for export
    # This function returns strings in the format: key="value" or key=value
    # The values are quoted if they contain spaces
    echo $@ | jq -r '.config | to_entries | .[] | select(.value != null and .value != {}) | 
        if (.value | tostring | test(" ")) then
            .key + "=" + "\"" + (.value | tostring) + "\""
        else
            .key + "=" + (.value | tostring)
        end'
}
