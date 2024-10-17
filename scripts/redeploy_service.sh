#!/bin/bash

. ./utils/initialize.sh

fn_validate_variables ecs_cluster ecs_service aws_region timestamp

if [[ -n "$codedeploy_application_name" ]]; then
    fn_info "Forcing deployment using CodeDeploy"
    fn_validate_variables task_definition container_name container_port codedeploy_application_name codedeploy_group_name

    fn_run update-service \
        --cluster $ecs_cluster \
        --service $ecs_service \
        --region $aws_region \
        --enable-execute-command

    task_definition_latest_arn=$(aws ecs describe-task-definition \
        --region $aws_region \
        --task-definition $task_definition \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)

    revision_json=$(fn_get_codedeploy_revision_json "$task_definition_latest_arn" "$container_name" "$container_port")
    if [[ $? -ne 0 ]]; then
        fn_fatal "Failed to generate codedeploy revision JSON"
    fi

    fn_run codedeploy-deploy \
        --application-name $codedeploy_application_name \
        --deployment-group-name $codedeploy_group_name \
        --region $aws_region \
        --revision "$revision_json" || fn_fatal
else
    fn_info "Forcing deployment using ECS"

    fn_run update-service \
        --cluster $ecs_cluster \
        --service $ecs_service \
        --region $aws_region \
        --enable-execute-command \
        --force-new-deployment || fn_fatal
fi

fn_success "ECS Service deployment initiated"
