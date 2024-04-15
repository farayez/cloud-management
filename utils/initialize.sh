#!/bin/bash

# Set up autocomplete for commands
. ./utils/setup_auto_complete.sh

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

# CD into services directory
cd ./services/$service_name || exit 1

# Generate temporary directories if not present
mkdir -p tmp
mkdir -p history
