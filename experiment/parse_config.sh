#!/bin/bash

. ./utils/initialize_execution.sh

function fn_populate_config_variables() {
    local pair
    for pair in $@; do
        echo $pair
        export $pair
    done
}

config_file_content=$(echo "$(<$root_directory/experiment/example.config.json)" | jq)

config_keys_value_pairs=$(echo $config_file_content | jq -r '.config | to_entries | .[] | .key + "=" + "\"" + .value + "\"" ')

fn_populate_config_variables $config_keys_value_pairs

fn_print_variables
