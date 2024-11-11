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

fn_demo_colors() {
    declared_colors=($(compgen -A variable | grep '^CONSOLE_COLOR_*'))

    for variable in ${declared_colors[@]}; do
        echo -e ${!variable}$variable$CONSOLE_COLOR_DEFAULT
    done

    unset declared_colors
}

# Function to run a command and handle success/error outputs
fn_run() {
    # Initialize variables provided as arguments
    local echo_response=false
    local disable_response_log=false

    local key="$1" # First parameter is the command key
    shift          # Shift to access remaining parameters as command arguments

    # Check if the key exists in the command map
    if [[ -z "${command_map[$key]}" ]]; then
        fn_error "Error: Command key '$key' not found in the map."
        return 1
    fi

    local timestamp=$(date +"%Y-%m-%d_%H:%M:%S") # Current timestamp

    # Split the command string into command and arguments
    IFS=',' read -r -a arguments <<<"${command_map[$key]}"

    # Access the runtime arguments for the command
    for value in "${arguments[@]:1}"; do
        # Create local variables for each argument

        # Remove the leading '--' and replace '-' with '_'
        local variable_name="${value#--}"
        variable_name="${variable_name//-/_}"

        # Create the local variable and set it to true
        local "$variable_name"=true
    done

    # Prepare the command to run
    local cmd="${arguments[0]}"

    # Ensure the command history directory exists
    local history_directory="history/$resource_name"
    mkdir -p "$history_directory" || {
        fn_error "Could not create directory $history_directory"
        return 1
    }

    local history_file="$history_directory/${current_execution_id}.${current_script_name}.history"
    touch "$history_file"
    echo -e "---------- START\nTIMESTAMP: ${timestamp}" >>"$history_file"
    echo -e "---------- COMMAND\n$cmd" "$@" >>"$history_file"

    # Run the command without capturing output or error
    if $disable_response_log; then
        # output=$({ $cmd "$@"; } 2>&1 | tee /dev/tty)
        output=$($cmd "$@" 2>&1)
        if $echo_response; then
            # Print the output. Can be captured in the parent script
            echo "$output"
        fi
        echo "---------- SUCCESS" >>"$history_file"
        return 0
    fi

    # Run the command and capture output or error
    if output=$($cmd "$@" 2>&1); then
        # Command succeeded
        # echo "Success: $output"

        # Save the result to a history file
        echo "---------- SUCCESS" >>"$history_file"
        echo "$output" >>"$history_file"

        if $echo_response; then
            # Print the output. Can be captured in the parent script
            echo "$output"
        fi
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

function fn_populate_and_validate_resource_tag_from_current_script_name() {
    resource_tag=${script_name_to_resource_tag_map[$current_script_name]}

    if [ -z "$resource_tag" ]; then
        fn_error "resource_tag must be provided"
        fn_fatal
    fi
}

# Populate the resource_directory variable from the resource_tag using the
#     resource_tag_to_directory_map associative array.
function fn_populate_and_validate_resource_directory_from_resource_tag() {
    resource_directory=${resource_tag_to_directory_map[$resource_tag]}

    if [ -z "$resource_directory" ]; then
        fn_error "Unsupported resource tag: $resource_tag"
        fn_fatal
    fi

    # Prepend root directory
    resource_directory="$root_directory/$resource_directory"

    # Create resource directory if it doesn't exist
    if [ ! -d $resource_directory ]; then
        mkdir -p $resource_directory || fn_fatal
        cp templates/resource.gitignore.template $resource_directory/.gitignore || fn_fatal
    fi
}

function fn_populate_and_validate_resource_name() {
    resource_name=$1

    # Validate resource_name argument
    if [ -z $resource_name ]; then
        fn_error "1st argument must be the name of the $resource_tag"
        fn_fatal
    fi

    # Check for resource config
    if [ ! -f "$resource_directory/$resource_name.config.sh" ]; then
        fn_error "No $resource_tag found with name $resource_name"
        fn_fatal
    fi
}

function fn_populate_and_validate_resource_config_file() {
    resource_config_file="$resource_directory/$resource_name.config.sh"
}

function fn_parse_arguments() {
    local argument
    for argument in "$@"; do
        local key=$(echo $argument | cut -f1 -d=)

        local key_length=${#key}
        local value="${argument:$key_length+1}"

        if [ ! -z $value ]; then
            export "$key"="$value"
        fi
    done
}

function fn_get_all_resource_names_in_directory() {
    local resource_directory=$1
    local files=($(ls -1 $resource_directory/*.config.sh 2>/dev/null))

    if [ -z "$files" ]; then
        return
    fi

    local resource_names=($(basename -a ${files[@]} | sed -e 's/.config.sh$//' | sort -u))
    echo "${resource_names[@]}"
}
