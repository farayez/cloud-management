#!/bin/bash

. ./utils/initialize.sh

fn_validate_variables ecs_cluster ecs_service aws_region timestamp

fn_run update-service \
    --cluster $ecs_cluster \
    --service $ecs_service  \
    --region $aws_region \
    --enable-execute-command \
    --force-new-deployment || fn_fatal

fn_success "ECS Service deployment initiated"
