#!/bin/bash

. ./utils/initialize.sh

if [ -z $task_definition ]; then
    echo ERROR: task_definition must be specified in configuration
    exit 1
fi

if [ -z $task_definition_revision ]; then
    export task_definition_param="--task-definition $task_definition"
else
    export task_definition_param="--task-definition $task_definition:$task_definition_revision"
fi

aws ecs update-service \
    --cluster $ecs_cluster \
    --service $ecs_service  \
    --region $aws_region \
    $task_definition_param \
    --enable-execute-command \
    --force-new-deployment \
    > history/ecs_update_$timestamp.json