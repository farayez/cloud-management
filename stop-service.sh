#!/bin/bash

. ./utils/initialize.sh

aws ecs update-service \
    --cluster $ecs_cluster \
    --service $ecs_service \
    --region $aws_region \
    --force-new-deployment \
    --desired-count 0 \
    > history/ecs_update_$timestamp.json