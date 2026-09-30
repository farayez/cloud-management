#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables host username key_path command1

# Set permissions for the SSH key to be read-only by the user
chmod 400 $root_directory/$key_path

# Prefix that marks every line of server output
remote_prefix="${CONSOLE_COLOR_CYAN}[$host]${CONSOLE_COLOR_DEFAULT} "

command_number=1
while true; do
    command_variable="command$command_number"
    command_to_run="${!command_variable}"

    # Commands are numbered consecutively, stop at the first gap
    [ -z "$command_to_run" ] && break

    # Config values containing spaces are exported wrapped in literal quotes
    command_to_run="${command_to_run#\"}"
    command_to_run="${command_to_run%\"}"

    fn_section_start "$command_variable"
    fn_info "$command_to_run"

    # Run in the remote directory when one is configured
    remote_command="$command_to_run"
    [ -n "$remote_directory" ] && remote_command="cd $remote_directory && $command_to_run"

    fn_run ssh -i "$root_directory/$key_path" "$username@$host" "$remote_command" </dev/null |
        while IFS= read -r line; do
            printf '%b%s\n' "$remote_prefix" "$line"
        done
    exit_code=${PIPESTATUS[0]}

    echo -e "${CONSOLE_COLOR_CYAN}----------------------${CONSOLE_COLOR_DEFAULT}"

    if [ $exit_code -ne 0 ]; then
        fn_fatal "$command_variable failed with exit code $exit_code: $command_to_run"
    fi

    command_number=$((command_number + 1))
done

fn_success "All commands executed successfully"
