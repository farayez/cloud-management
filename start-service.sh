#!/bin/bash

# argument defaults
arg_desired_count=1

. ./utils/initialize.sh

aws ecs update-service \
    --cluster $ecs_cluster \
    --service $ecs_service  \
    --region $aws_region \
    --enable-execute-command \
    --force-new-deployment \
    --desired-count $arg_desired_count \
    > history/ecs_update_$timestamp.json