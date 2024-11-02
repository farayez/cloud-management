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
