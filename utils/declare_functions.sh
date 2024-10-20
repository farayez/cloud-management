#!/bin/bash

# Function to validate variables
fn_validate_variables() {
    local variable
    local validated=1
    for variable in $@; do
        if [ -z "${!variable}" ]; then
            fn_error "$variable must be set"
            validated=0
        fi
    done

    if [ $validated -eq 0 ]; then
        fn_fatal "Config validation failed"
    fi

    fn_info "\nCONFIG VALIDATION SUCCESSFUL"
}

# Echo all variables
fn_print_variables() {
    local variable

    if [ "$#" -lt 1 ]; then
        fn_list_declared_variables

        echo -e "total variables $CONSOLE_COLOR_YELLOW${#declared_variables[@]}$CONSOLE_COLOR_DEFAULT"

        for variable in ${declared_variables[@]}; do
            echo -e $CONSOLE_COLOR_LIGHT_GRAY$variable$CONSOLE_COLOR_DEFAULT = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_COLOR_DEFAULT
        done
    else
        for variable in $@; do
            echo -e $CONSOLE_COLOR_LIGHT_GRAY$variable$CONSOLE_COLOR_DEFAULT = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_COLOR_DEFAULT
        done
    fi

}

# List all variables in declared_variables
fn_list_declared_variables() {
    unset declared_variables
    declared_variables=($(compgen -A variable | grep '^[a-z].*' | grep -v '^npm_*'))
}

# Setup Console Colors
fn_define_console_colors() {
    CONSOLE_COLOR_BLACK='\033[0;30m'
    CONSOLE_COLOR_RED='\033[0;31m'
    CONSOLE_COLOR_GREEN='\033[0;32m'
    CONSOLE_COLOR_BROWN='\033[0;33m'
    CONSOLE_COLOR_BLUE='\033[0;34m'
    CONSOLE_COLOR_PURPLE='\033[0;35m'
    CONSOLE_COLOR_CYAN='\033[0;36m'
    CONSOLE_COLOR_LIGHT_GRAY='\033[0;37m'
    CONSOLE_COLOR_DARK_GRAY='\033[1;30m'
    CONSOLE_COLOR_LIGHT_RED='\033[1;31m'
    CONSOLE_COLOR_LIGHT_GREEN='\033[1;32m'
    CONSOLE_COLOR_YELLOW='\033[1;33m'
    CONSOLE_COLOR_LIGHT_BLUE='\033[1;34m'
    CONSOLE_COLOR_LIGHT_PURPLE='\033[1;35m'
    CONSOLE_COLOR_LIGHT_CYAN='\033[1;36m'
    CONSOLE_COLOR_WHITE='\033[1;37m'
    CONSOLE_COLOR_DEFAULT='\033[0m'
}
fn_demo_colors() {
    declared_colors=($(compgen -A variable | grep '^CONSOLE_COLOR_*'))

    for variable in ${declared_colors[@]}; do
        echo -e ${!variable}$variable$CONSOLE_COLOR_DEFAULT
    done

    unset declared_colors
}

# Echo alternatives
fn_info() {
    echo -e "$CONSOLE_COLOR_BLUE$@$CONSOLE_COLOR_DEFAULT"
}
fn_error() {
    echo -e "$CONSOLE_COLOR_RED  ERROR: $@$CONSOLE_COLOR_DEFAULT" >&2
}
fn_debug() {
    echo -e "$CONSOLE_COLOR_BLACK$@$CONSOLE_COLOR_DEFAULT"
}
fn_warning() {
    echo -e "$CONSOLE_COLOR_YELLOW$@$CONSOLE_COLOR_DEFAULT"
}
fn_section_start() {
    echo -e "\n$CONSOLE_COLOR_PURPLE${@^^}$CONSOLE_COLOR_DEFAULT"
}
fn_section_end() {
    echo -e "$CONSOLE_COLOR_PURPLE${@^^}$CONSOLE_COLOR_DEFAULT\n"
}
fn_status() {
    echo -e "$CONSOLE_COLOR_PURPLE${@^^}$CONSOLE_COLOR_DEFAULT"
}
fn_success() {
    echo -e "\n${CONSOLE_COLOR_LIGHT_GREEN}SUCCESS: $CONSOLE_COLOR_GREEN${@^^}$CONSOLE_COLOR_DEFAULT\n"
}

# Ask for user input
fn_input_text() {
    echo -n -e "$CONSOLE_COLOR_CYAN$1$CONSOLE_COLOR_GREEN"
    read $2
    echo -e "$CONSOLE_COLOR_DEFAULT"
}

# Fatal Error
fn_fatal() {
    if [ "$#" -lt 1 ]; then
        echo -e "\n${CONSOLE_COLOR_RED}EXECUTION FAILED$CONSOLE_COLOR_DEFAULT\n"
    else
        echo -e "\n$CONSOLE_COLOR_RED${1^^}$CONSOLE_COLOR_DEFAULT\n"
    fi

    exit 1
}

# Declare an associative array to map keys to commands
declare -A command_map=(
    ["update-service"]="aws ecs update-service"
    ["list-buckets"]="aws s3 ls"
    ["codedeploy-deploy"]="aws deploy create-deployment"
)

# Function to run a command and handle success/error outputs
fn_run() {
    local key="$1" # First parameter is the command key
    shift          # Shift to access remaining parameters as command arguments

    # Check if the key exists in the command map
    if [[ -z "${command_map[$key]}" ]]; then
        echo "Error: Command key '$key' not found in the map."
        return 1
    fi

    local cmd="${command_map[$key]}"             # Get the command from the map
    local timestamp=$(date +"%Y-%m-%d_%H:%M:%S") # Current

    # Ensure the command history directory exists
    local history_directory="history/$current_script_name"
    mkdir -p "$history_directory" || {
        fn_error "Could not create directory $history_directory"
        return 1
    }

    local history_file="$history_directory/${current_execution_id}.history"
    touch "$history_file"
    echo -e "---------- START\nTIMESTAMP: ${timestamp}" >>"$history_file"
    echo -e "---------- COMMAND\n$cmd" "$@" >>"$history_file"

    # Run the mapped command with its arguments and capture output or error
    if output=$($cmd "$@" 2>&1); then
        # Command succeeded
        # echo "Success: $output"

        # Save the result to a history file
        echo "---------- SUCCESS" >>"$history_file"
        echo "$output" >>"$history_file"
        return 0
    else
        # Command failed
        fn_error "$output"

        # Save the error to a history file
        echo "---------- ERROR" >>"$history_file"
        echo "$output" >>"$history_file"
        return 1
    fi
}

# Get CodeDeploy revision config
fn_get_codedeploy_revision_json() {
    local task_definition_arn="$1"
    local container_name="$2"
    local container_port="$3"

    # Parameter checking
    if [[ -z "$task_definition_arn" || -z "$container_name" || -z "$container_port" ]]; then
        echo "Error: Missing required parameters."
        return 1
    fi

    # Create the content JSON and encode it as a string
    local content_json
    content_json=$(jq -n --arg taskDef "$task_definition_arn" \
        --arg contName "$container_name" \
        --argjson contPort "$container_port" \
        '{
      version: 1,
      Resources: [
        {
          TargetService: {
            Type: "AWS::ECS::Service",
            Properties: {
              TaskDefinition: $taskDef,
              LoadBalancerInfo: {
                ContainerName: $contName,
                ContainerPort: $contPort
              }
            }
          }
        }
      ]
    }' | jq -c '.') # Compact the JSON into a single line

    # Create the revision JSON, ensuring the content is string-encoded
    local revision_json
    revision_json=$(jq -n --arg content "$content_json" \
        '{
      revisionType: "AppSpecContent",
      appSpecContent: {
        content: $content
      }
    }')

    # Print the final single-line JSON
    echo "$revision_json" | jq -c '.'
}
