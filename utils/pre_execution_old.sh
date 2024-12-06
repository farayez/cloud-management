#!/bin/bash

. ./utils/initialize_execution.sh

# Populate execution variables
fn_populate_and_validate_resource_tag_from_current_script_name
fn_populate_and_validate_resource_directory_from_resource_tag
fn_populate_and_validate_resource_name $1
fn_populate_and_validate_resource_config_file

# Parse resource configuration and command arguments
. $resource_config_file || fn_fatal
fn_parse_arguments "$@" || fn_fatal

# Set AWS Configuration Env Variables
export AWS_SHARED_CREDENTIALS_FILE=$root_directory/.aws/credentials
export AWS_CONFIG_FILE=$root_directory/.aws/config
export AWS_PROFILE=$aws_profile

# CD into execution directory
cd $resource_directory || exit 1
