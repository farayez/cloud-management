#!/usr/bin/env bats

# redeploy_service, start_service, stop_service and exec_container

setup() {
    load test_helper
    setup_script_sandbox

    write_config <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" },
  "service": [
    {
      "name": "api",
      "config": {
        "ecs_cluster": "main-cluster",
        "ecs_service": "api-service",
        "task_definition": "api-td",
        "primary_container_name": "app",
        "stop_allowed": true
      }
    },
    {
      "name": "codedeploy-api",
      "config": {
        "ecs_cluster": "main-cluster",
        "ecs_service": "api-service",
        "task_definition": "api-td",
        "primary_container_name": "app",
        "primary_container_port": 8080,
        "codedeploy_application_name": "api-app",
        "codedeploy_group_name": "api-group"
      }
    },
    {
      "name": "codedeploy-invalid",
      "config": {
        "ecs_cluster": "main-cluster",
        "ecs_service": "api-service",
        "codedeploy_application_name": "api-app"
      }
    },
    {
      "name": "locked",
      "config": { "ecs_cluster": "main-cluster", "ecs_service": "locked-service" }
    },
    { "name": "invalid", "config": { "ecs_cluster": "main-cluster" } }
  ]
}
EOF
}

# redeploy_service

@test "redeploy_service forces a new ECS deployment" {
    run_repo_script redeploy_service config=test.config.json resource=api
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Forcing deployment using ECS"* ]]
    [[ "$(plain_output)" == *"SUCCESS: ECS SERVICE DEPLOYMENT INITIATED"* ]]
    [ "$(mock_calls)" = "aws ecs update-service --cluster main-cluster --service api-service --region us-east-1 --enable-execute-command --task-definition api-td --force-new-deployment" ]
}

@test "redeploy_service fails when the ECS update fails" {
    mock_response "aws ecs update-service" 254
    run_repo_script redeploy_service config=test.config.json resource=api
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"EXECUTION FAILED"* ]]
}

@test "redeploy_service fails when required ECS config is missing" {
    run_repo_script redeploy_service config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: ecs_service must be set"* ]]
    [ -z "$(mock_calls)" ]
}

@test "redeploy_service deploys the latest task definition through CodeDeploy" {
    local arn="arn:aws:ecs:us-east-1:123456789012:task-definition/api-td:7"
    mock_response "aws ecs describe-task-definition" 0 "$arn"

    run_repo_script redeploy_service config=test.config.json resource=codedeploy-api
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Forcing deployment using CodeDeploy"* ]]
    [[ "$(plain_output)" == *"Latest task ARN: $arn"* ]]
    [[ "$(mock_calls)" != *"update-service"* ]]

    local calls
    mapfile -t calls < <(mock_calls)
    [ "${#calls[@]}" -eq 2 ]
    [ "${calls[0]}" = "aws ecs describe-task-definition --region us-east-1 --task-definition api-td --query taskDefinition.taskDefinitionArn --output text" ]
    [[ "${calls[1]}" == "aws deploy create-deployment --application-name api-app --deployment-group-name api-group --region us-east-1 --revision "* ]]

    local content
    content=$(echo "${calls[1]#*--revision }" | jq -r '.appSpecContent.content')
    [ "$(echo "$content" | jq -r '.Resources[0].TargetService.Properties.TaskDefinition')" = "$arn" ]
    [ "$(echo "$content" | jq -r '.Resources[0].TargetService.Properties.LoadBalancerInfo.ContainerName')" = "app" ]
    [ "$(echo "$content" | jq '.Resources[0].TargetService.Properties.LoadBalancerInfo.ContainerPort')" = "8080" ]
}

@test "redeploy_service fails when the CodeDeploy deployment fails" {
    mock_response "aws ecs describe-task-definition" 0 "arn:aws:ecs:task-definition/api-td:7"
    mock_response "aws deploy create-deployment" 1
    run_repo_script redeploy_service config=test.config.json resource=codedeploy-api
    [ "$status" -eq 1 ]
}

@test "redeploy_service fails when required CodeDeploy config is missing" {
    run_repo_script redeploy_service config=test.config.json resource=codedeploy-invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: primary_container_port must be set"* ]]
    [[ "$(plain_output)" == *"ERROR: codedeploy_group_name must be set"* ]]
    [ -z "$(mock_calls)" ]
}

# start_service

@test "start_service scales the service to one task by default" {
    run_repo_script start_service config=test.config.json resource=api
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"STARTING ECS SERVICE: API-SERVICE"* ]]
    [[ "$(plain_output)" == *"SUCCESS: ECS SERVICE START INITIATED"* ]]
    [ "$(mock_calls)" = "aws ecs update-service --cluster main-cluster --service api-service --region us-east-1 --enable-execute-command --force-new-deployment --desired-count 1" ]
}

@test "start_service accepts a desired_count argument" {
    run_repo_script start_service config=test.config.json resource=api desired_count=3
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--desired-count 3" ]]
}

@test "start_service fails when the ECS update fails" {
    mock_response "aws ecs update-service" 1
    run_repo_script start_service config=test.config.json resource=api
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" != *"SUCCESS"* ]]
}

# stop_service

@test "stop_service scales the service to zero when stopping is allowed" {
    run_repo_script stop_service config=test.config.json resource=api
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: ECS SERVICE STOP INITIATED"* ]]
    [ "$(mock_calls)" = "aws ecs update-service --cluster main-cluster --service api-service --region us-east-1 --force-new-deployment --desired-count 0" ]
}

@test "stop_service refuses to stop services without stop_allowed" {
    run_repo_script stop_service config=test.config.json resource=locked
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"STOP IS NOT ALLOWED"* ]]
    [ -z "$(mock_calls)" ]
}

@test "stop_service fails when the ECS update fails" {
    mock_response "aws ecs update-service" 1
    run_repo_script stop_service config=test.config.json resource=api
    [ "$status" -eq 1 ]
}

# exec_container

@test "exec_container opens a shell in the selected running task" {
    mock_response "aws ecs list-tasks" 0 $'arn:aws:ecs:task/first\tarn:aws:ecs:task/second'

    run_repo_script exec_container config=test.config.json resource=api < <(menu_select 1)
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Selected task: arn:aws:ecs:task/second"* ]]
    [[ "$(plain_output)" == *"SUCCESS: EXECUTION COMPLETED INSIDE CONTAINER"* ]]

    local calls
    mapfile -t calls < <(mock_calls)
    [ "${calls[0]}" = "aws ecs list-tasks --region us-east-1 --cluster main-cluster --output text --query taskArns --service api-service" ]
    [ "${calls[1]}" = "aws ecs execute-command --region us-east-1 --cluster main-cluster --task arn:aws:ecs:task/second --container app --interactive --command /bin/bash" ]
}

@test "exec_container fails when there are no running tasks" {
    mock_response "aws ecs list-tasks" 0 ""
    run_repo_script exec_container config=test.config.json resource=api
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"THERE'S NO RUNNING TASK"* ]]
    [[ "$(mock_calls)" != *"execute-command"* ]]
}

@test "exec_container fails when listing tasks fails" {
    mock_response "aws ecs list-tasks" 255
    run_repo_script exec_container config=test.config.json resource=api
    [ "$status" -eq 1 ]
    [[ "$(mock_calls)" != *"execute-command"* ]]
}

@test "exec_container fails when the exec command fails" {
    mock_response "aws ecs list-tasks" 0 "arn:aws:ecs:task/first"
    mock_response "aws ecs execute-command" 1
    run_repo_script exec_container config=test.config.json resource=api < <(menu_select 0)
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" != *"SUCCESS"* ]]
}

@test "exec_container fails when required config is missing" {
    run_repo_script exec_container config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: primary_container_name must be set"* ]]
    [ -z "$(mock_calls)" ]
}
