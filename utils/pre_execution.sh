#!/bin/bash

. ./utils/prepare_runtime.sh

# Populate execution variables
fn_populate_and_validate_resource_tag_from_current_script_name

# Parse command arguments
fn_parse_arguments "$@" || fn_fatal
if [ -n "${account_level_scripts[$current_script_name]}" ]; then
    fn_populate_config_variables
    # Keeps the history layout: history/<config_name>/<resource_tag>/<resource_name>/
    resource_name="all"
else
    fn_populate_and_validate_resource_name "$resource"
    fn_validate_item_provided
    fn_populate_config_variables
fi

# Set AWS Configuration Env Variables
export AWS_SHARED_CREDENTIALS_FILE=$root_directory/.aws/credentials
export AWS_CONFIG_FILE=$root_directory/.aws/config
export AWS_PROFILE=$aws_profile
