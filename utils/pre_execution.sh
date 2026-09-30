#!/bin/bash

. ./utils/prepare_runtime.sh

# Populate execution variables
fn_populate_and_validate_resource_tag_from_current_script_name
fn_populate_and_validate_resource_directory_from_resource_tag

# Parse command arguments
fn_parse_arguments "$@" || fn_fatal
fn_populate_and_validate_resource_name "$resource"
fn_run_for_each_sub_resource "$@"
fn_populate_config_variables

# Set AWS Configuration Env Variables
export AWS_SHARED_CREDENTIALS_FILE=$root_directory/.aws/credentials
export AWS_CONFIG_FILE=$root_directory/.aws/config
export AWS_PROFILE=$aws_profile

# CD into execution directory
cd $resource_directory || exit 1
