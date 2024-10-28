#!/bin/bash

. ./utils/initialize.sh

fn_validate_variables ecs_cluster ecs_service aws_region timestamp root_directory primary_container_name

# Fetch running tasks
running_tasks=($(aws ecs list-tasks \
    --region $aws_region \
    --cluster $ecs_cluster \
    --output text \
    --query 'taskArns' \
    --service $ecs_service))

if [ -z "$running_tasks" ]; then
    fn_fatal "There's no running task"
fi

# Let user select the task to exec into
. $root_directory/utils/selection_menu.sh
fn_choose_from_menu "Select running task:" selected_task "${running_tasks[@]}"
fn_info "Selected task: $selected_task"

# Exec into container
aws ecs execute-command \
    --region $aws_region \
    --cluster $ecs_cluster \
    --task $selected_task \
    --container $primary_container_name \
    --interactive \
    --command "/bin/bash" || fn_fatal
