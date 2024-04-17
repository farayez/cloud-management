#!/bin/bash

. ./utils/initialize.sh

# Fetch running tasks
running_tasks=($(aws ecs list-tasks \
    --region $aws_region \
    --cluster $ecs_cluster \
    --output text \
    --query 'taskArns' \
    --service $ecs_service))

if [ -z "$running_tasks" ]; then
    echo "There's no running task"
    exit 0
fi

# Let user select the task to exec into
. $home_directory/utils/selection_menu.sh
choose_from_menu "Select running task:" selected_task "${running_tasks[@]}"
echo "Selected task: $selected_task"

# Exec into container
aws ecs execute-command \
    --region $aws_region \
    --cluster $ecs_cluster \
    --task $selected_task \
    --container $container_name \
    --interactive \
    --command "/bin/bash"