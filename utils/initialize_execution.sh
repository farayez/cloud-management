#!/bin/bash

# Generate context identifiers
current_execution_id=$(date +%Y_%m_%d_%H%M%S)
current_script_name=$(basename "$0" .sh)
timestamp=$(date +%Y_%m_%d_%H%M%S)

# Set root directory
root_directory=$(pwd)

# Define constants
. ./utils/define_constants.sh

# Declare output functions
. ./utils/functions/output.sh

# Declare input functions
. ./utils/functions/input.sh

# Declare functions required for script execution
. ./utils/functions/execution.sh

# Declare functions required for remote command execution
. ./utils/functions/run_command.sh

# Declare functions required for parsing config files
. ./utils/functions/parse_config.sh

# Declare auxiliary functions
. ./utils/declare_functions.sh

fn_draw_separator
