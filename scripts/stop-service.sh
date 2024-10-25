#!/bin/bash

. ./utils/initialize.sh

if [ "$stop_allowed" != "true" ]; then
    fn_fatal "Stop is not allowed"
fi

fn_section_start "Stopping ECS service: $ecs_service"

fn_run update-service \
    --cluster $ecs_cluster \
    --service $ecs_service \
    --region $aws_region \
    --force-new-deployment \
    --desired-count 0

fn_success "ECS Service STOP initiated"
