#!/bin/bash

# argument defaults
desired_count=1

. ./utils/pre_execution.sh

fn_section_start "Starting ECS service: $ecs_service"

fn_run update-service \
    --cluster $ecs_cluster \
    --service $ecs_service \
    --region $aws_region \
    --enable-execute-command \
    --force-new-deployment \
    --desired-count $desired_count || fn_fatal

fn_success "ECS Service START initiated"
