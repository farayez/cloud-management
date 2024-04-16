#!/bin/bash

# argument defaults
desired_count=1

. ./utils/initialize.sh

aws ecs update-service \
    --cluster $ecs_cluster \
    --service $ecs_service  \
    --region $aws_region \
    --enable-execute-command \
    --force-new-deployment \
    --desired-count $desired_count \
    > history/ecs_update_$timestamp.json