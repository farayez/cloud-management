#!/bin/bash

# Set up autocomplete for commands
. ./utils/setup_auto_complete.sh

# Declare functions
. ./utils/declare_functions.sh

define_console_colors

# Validate service directory and set service_name
if [ -z $1 ] || [ ! -d ./services/$1 ]; then
    echo ERROR: 1st argument must point to the directory associated with a service
    exit 1
fi
service_name=$1;

# Set timestamp for history
timestamp=$(date +%Y_%m_%d_%H%M%S)
# Set home directory
home_directory=$(pwd)

# Parse variables and command arguments
. ./services/$service_name/set_variables.sh || exit 1
. ./utils/parse_arguments.sh || exit 1

# Set AWS Configuration Env Variables
export AWS_SHARED_CREDENTIALS_FILE=$home_directory/.aws/credentials
export AWS_CONFIG_FILE=$home_directory/.aws/config
export AWS_PROFILE=$aws_profile

# CD into services directory
cd ./services/$service_name || exit 1

# Generate temporary directories if not present
mkdir -p tmp
mkdir -p history
