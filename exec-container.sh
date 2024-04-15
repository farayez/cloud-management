#!/bin/bash

. ./utils/initialize.sh

# Validate task argument
if [ -z $arg_task ]; then
    echo ERROR: ECS task id must be specified \(./exec-container.sh $1 task=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\)
    exit 1
fi

aws ecs execute-command \
    --cluster $ecs_cluster \
    --task $arg_task \
    --container $container_name \
    --interactive \
    --command "/bin/bash"
