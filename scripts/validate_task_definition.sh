#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables resource_name root_directory aws_region

# Prepare task definition file if empty
if [ -z "$task_definition_file" ]; then
    task_definition_file=$root_directory/task_definitions/definitions/$resource_name.pushable.json
fi

# Ensure task definition file exists
if [ ! -f "$task_definition_file" ]; then
    fn_error "Task Definition file $task_definition_file does not exist"
    fn_fatal
fi

fn_info "Using task definition file: $task_definition_file"

fn_run register-task-definition \
    --region $aws_region \
    --cli-input-json file://$task_definition_file \
    --generate-cli-skeleton \
    output || fn_fatal "Validation Failed"

fn_success "Task Definition validated"
