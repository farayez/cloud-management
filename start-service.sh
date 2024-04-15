#!/bin/bash

. ./utils/initialize.sh

aws ecs update-service \
    --cluster $ecs_cluster \
    --service $ecs_service  \
    --region $aws_region \
    --enable-execute-command \
    --force-new-deployment \
    --desired-count 1 \
    > history/ecs_update_$timestamp.json