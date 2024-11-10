#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables ecs_cluster ecs_service aws_region timestamp root_directory primary_container_name

# Fetch running tasks
running_tasks=($(fn_run ecs-list-tasks \
    --region $aws_region \
    --cluster $ecs_cluster \
    --output text \
    --query 'taskArns' \
    --service $ecs_service)) || fn_fatal

if [ -z "$running_tasks" ]; then
    fn_fatal "There's no running task"
fi

# Let user select the task to exec into
fn_choose_from_menu "\nSelect running task:" selected_task "${running_tasks[@]}"
fn_info "Selected task: $selected_task"

# Exec into container
# aws ecs execute-command \
fn_run ecs-exec-command \
    --region $aws_region \
    --cluster $ecs_cluster \
    --task $selected_task \
    --container $primary_container_name \
    --interactive \
    --command "/bin/bash" || fn_fatal

fn_success "Execution completed inside container"
