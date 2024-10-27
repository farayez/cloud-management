#!/bin/bash

# Generate context identifiers
current_execution_id=$(date +%Y_%m_%d_%H%M%S)
current_script_name=$(basename "$0" .sh)
timestamp=$(date +%Y_%m_%d_%H%M%S)

# Set root directory
root_directory=$(pwd)

# Define constants
. ./utils/define_constants.sh

# Declare functions
. ./utils/declare_functions.sh

# Configure console
fn_define_console_colors

# Populate execution variables
fn_populate_and_validate_resource_tag_from_current_script_name
fn_populate_and_validate_resource_directory_from_resource_tag
fn_populate_and_validate_resource_name $1
fn_populate_and_validate_execution_directory

# Parse resource configuration and command arguments
. $execution_directory/config.sh || exit 1
fn_parse_arguments "$@" || exit 1

# Set AWS Configuration Env Variables
export AWS_SHARED_CREDENTIALS_FILE=$root_directory/.aws/credentials
export AWS_CONFIG_FILE=$root_directory/.aws/config
export AWS_PROFILE=$aws_profile

# CD into execution directory
cd $execution_directory || exit 1
