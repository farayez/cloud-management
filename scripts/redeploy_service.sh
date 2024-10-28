#!/bin/bash

. ./utils/initialize.sh

if [[ -n "$codedeploy_application_name" ]]; then
    fn_info "Forcing deployment using CodeDeploy"
    fn_validate_variables ecs_cluster ecs_service aws_region timestamp task_definition primary_container_name primary_container_port codedeploy_application_name codedeploy_group_name

    fn_section_start "Updating Service"
    fn_run update-service \
        --cluster $ecs_cluster \
        --service $ecs_service \
        --region $aws_region \
        --enable-execute-command
    # --desired-count 6 \

    fn_section_start "Retrieving task definition ARN"
    task_definition_latest_arn=$(aws ecs describe-task-definition \
        --region $aws_region \
        --task-definition $task_definition \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    fn_info "Latest task ARN: $task_definition_latest_arn"

    revision_json=$(fn_get_codedeploy_revision_json "$task_definition_latest_arn" "$primary_container_name" "$primary_container_port")
    if [[ $? -ne 0 ]]; then
        fn_fatal "Failed to generate codedeploy revision JSON"
    fi

    fn_section_start "Forcing deployment using CodeDeploy"
    fn_run codedeploy-deploy \
        --application-name $codedeploy_application_name \
        --deployment-group-name $codedeploy_group_name \
        --region $aws_region \
        --revision "$revision_json" || fn_fatal
else
    fn_info "Forcing deployment using ECS"
    fn_validate_variables ecs_cluster ecs_service aws_region timestamp

    fn_run update-service \
        --cluster $ecs_cluster \
        --service $ecs_service \
        --region $aws_region \
        --enable-execute-command \
        --force-new-deployment || fn_fatal
fi

fn_success "ECS Service deployment initiated"
