#!/bin/bash

# Function to run a command and handle success/error outputs
# Logs or echos command history while executing command
# The available command keys are defined in command_map in `utils/define_constants.sh`
fn_run() {
    # Initialize variables provided as arguments
    local unbuffered_echo=false
    local no_echo=false

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
    local history_directory="$root_directory/history/$resource_tag/$resource_name"
    mkdir -p "$history_directory" || {
        fn_error "Could not create directory $history_directory"
        return 1
    }

    # Check if .gitignore file is present, if not copy from template
    if [[ ! -f "$root_directory/history/.gitignore" ]]; then
        cp "$root_directory/templates/history.gitignore.template" "$root_directory/history/.gitignore" || {
            fn_error "Could not copy .gitignore template to $history_directory"
            return 1
        }
    fi

    # Write the command information to the history file
    local history_file="$history_directory/${current_execution_id}.${current_script_name}.history"
    touch "$history_file"
    echo -e "========== START\nTIMESTAMP: ${timestamp}\nUNBUFFERED ECHO: $unbuffered_echo" >>"$history_file"
    echo -e "---------- COMMAND\n$cmd" "$@" >>"$history_file"
    echo -e "---------- OUTPUT" >>"$history_file"

    # Create a temporary file to store the exit code
    local exit_code_file
    exit_code_file=$(mktemp)

    # Run the command
    if $unbuffered_echo; then
        # Unbuffered output. Contains all the original formatting
        # Echo output and log it to the history file
        script -q -c "$cmd $*; echo -n \$? > $exit_code_file" /dev/null | tee -a "$history_file"
    else
        # Use printf to properly escape and quote each parameter
        params=("$@")
        quoted_params=$(printf "'%s' " "${params[@]}")

        # View the command to be run
        # stdbuf -oL -eL echo "$cmd $quoted_params"
        # echo ""

        if $no_echo; then
            # No output. Runs the command silently.
            # Only log output to the history file
            output=$($cmd "$@" 2>&1)
            echo $? >"$exit_code_file"
            echo "$output" >>"$history_file"
        else
            # Buffered output. Strips all the original formatting
            # Echo output and log it to the history file
            {
                stdbuf -oL -eL bash -c "$cmd $quoted_params" 2>&1
                echo $? >"$exit_code_file"
            } | tee -a "$history_file"
        fi
    fi

    # Read the exit code from the temporary file
    local exit_code
    exit_code=$(cat $exit_code_file)
    rm -f $exit_code_file

    # Write the exit code to the history file
    echo -e "---------- EXIT STATUS: $exit_code\n" >>"$history_file"

    return $exit_code
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
