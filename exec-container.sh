#!/bin/bash

. ./utils/initialize.sh

# Fetch running tasks
running_tasks=($(aws ecs list-tasks \
    --cluster $ecs_cluster \
    --output text \
    --query 'taskArns' \
    --service $ecs_service))

# Let user select the task to exec into
. $home_directory/utils/selection_menu.sh
choose_from_menu "Select running task:" selected_task "${running_tasks[@]}"
echo "Selected task: $selected_task"

# Exec into container
aws ecs execute-command \
    --cluster $ecs_cluster \
    --task $selected_task \
    --container $container_name \
    --interactive \
    --command "/bin/bash"