#!/usr/bin/env bats

# register_task_definition and validate_task_definition

setup() {
    load test_helper
    setup_script_sandbox

    task_definition_file="$root_directory/resources/test/task_definitions/api.json"
    mkdir -p "$(dirname "$task_definition_file")" "$root_directory/custom"
    echo '{"family": "api"}' >"$task_definition_file"
    echo '{"family": "custom"}' >"$root_directory/custom/td.json"

    write_config <<'EOF'
{
  "config": {
    "aws_profile": "test-profile",
    "aws_region": "us-east-1",
    "task_definitions_directory": "resources/test/task_definitions"
  },
  "task_definition": [
    { "name": "api" },
    { "name": "custom", "config": { "task_definition_file": "custom/td.json" } },
    { "name": "missing" }
  ]
}
EOF
}

# register_task_definition

@test "register_task_definition registers the task definition file" {
    run_repo_script register_task_definition config=test.config.json resource=api
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Using task definition file: $task_definition_file"* ]]
    [[ "$(plain_output)" == *"SUCCESS: TASK DEFINITION REGISTERED"* ]]
    [ "$(mock_calls)" = "aws ecs register-task-definition --region us-east-1 --cli-input-json file://$task_definition_file" ]
}

@test "register_task_definition logs the command to the resource history" {
    run_repo_script register_task_definition config=test.config.json resource=api
    local history_files=("$root_directory"/history/task_definition/api/*.register_task_definition.history)
    [ -f "${history_files[0]}" ]
    grep -q "aws ecs register-task-definition" "${history_files[0]}"
    grep -q -- "---------- EXIT STATUS: 0" "${history_files[0]}"
}

@test "register_task_definition uses task_definition_file from config" {
    run_repo_script register_task_definition config=test.config.json resource=custom
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--cli-input-json file://custom/td.json" ]]
}

@test "register_task_definition fails when the task definition file does not exist" {
    run_repo_script register_task_definition config=test.config.json resource=missing
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: Task Definition file $root_directory/resources/test/task_definitions/missing.json does not exist"* ]]
    [ -z "$(mock_calls)" ]
}

@test "register_task_definition fails when the registration fails" {
    mock_response "aws ecs register-task-definition" 254
    run_repo_script register_task_definition config=test.config.json resource=api
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"REGISTRATION FAILED"* ]]
}

# validate_task_definition

@test "validate_task_definition validates the task definition file" {
    run_repo_script validate_task_definition config=test.config.json resource=api
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: TASK DEFINITION VALIDATED"* ]]
    [ "$(mock_calls)" = "aws ecs register-task-definition --region us-east-1 --cli-input-json file://$task_definition_file --generate-cli-skeleton output" ]
}

@test "validate_task_definition uses task_definition_file from config" {
    run_repo_script validate_task_definition config=test.config.json resource=custom
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--cli-input-json file://custom/td.json --generate-cli-skeleton output" ]]
}

@test "validate_task_definition fails when the task definition file does not exist" {
    run_repo_script validate_task_definition config=test.config.json resource=missing
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"does not exist"* ]]
    [ -z "$(mock_calls)" ]
}

@test "validate_task_definition fails when validation fails" {
    mock_response "aws ecs register-task-definition" 252
    run_repo_script validate_task_definition config=test.config.json resource=api
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"VALIDATION FAILED. PLEASE CHECK HISTORY FOR MORE DETAILS."* ]]
}
