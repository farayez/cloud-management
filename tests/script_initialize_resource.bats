#!/usr/bin/env bats

setup() {
    load test_helper
    setup_script_sandbox

    cp "$REPO_ROOT/templates/config_templates.json" "$REPO_ROOT/templates/task-definition.template.json" \
        "$root_directory/templates/"
    templates_file="$root_directory/templates/config_templates.json"
    config_file="$root_directory/configurations/test.config.json"

    write_config <<'EOF'
{
  "config": {
    "aws_region": "us-east-1",
    "task_definitions_directory": "resources/test/task_definitions"
  }
}
EOF
}

# Keystrokes selecting the given resource tag in the resource menu
select_resource_tag() {
    local index
    index=$(jq --arg tag "$1" '(del(.common) | keys_unsorted + ["repo"]) | index($tag)' "$templates_file")
    menu_select "$index"
}

@test "initialize_resource adds the resource template to the config file" {
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag image; echo "api")
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: RESOURCE INITIALIZED"* ]]
    jq -e --slurpfile templates "$templates_file" \
        '.image == [{name: "api"} + $templates[0].image]' "$config_file"
    jq -e '.config.aws_region == "us-east-1"' "$config_file"
}

@test "initialize_resource appends to existing resources of the same type" {
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag service; echo "first")
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag service; echo "second")
    [ "$status" -eq 0 ]
    jq -e '[.service[].name] == ["first", "second"]' "$config_file"
}

@test "initialize_resource refuses to add a duplicate resource" {
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag image; echo "api")
    local before
    before=$(<"$config_file")

    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag image; echo "api")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"IMAGE API ALREADY EXISTS IN TEST.CONFIG.JSON"* ]]
    [ "$(<"$config_file")" = "$before" ]
}

@test "initialize_resource rejects unsafe resource names" {
    local before
    before=$(<"$config_file")
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag image; echo "../api")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"INVALID NAME '../API'"* ]]
    [ "$(<"$config_file")" = "$before" ]
}

@test "initialize_resource fails on an empty resource name" {
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag image; echo "")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: Input must be provided to continue execution"* ]]
}

@test "initialize_resource creates a task definition file for task definitions" {
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag task_definition; echo "api")
    [ "$status" -eq 0 ]
    local task_definition_file="$root_directory/resources/test/task_definitions/api.json"
    [[ "$(plain_output)" == *"Task definition file created in $task_definition_file"* ]]
    jq -e '.family == "api"' "$task_definition_file"
    jq -e '.task_definition[0].name == "api"' "$config_file"
}

@test "initialize_resource does not overwrite an existing task definition file" {
    local task_definition_file="$root_directory/resources/test/task_definitions/api.json"
    mkdir -p "$(dirname "$task_definition_file")"
    echo '{"family": "existing"}' >"$task_definition_file"

    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag task_definition; echo "api")
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"already exists. Not overwriting."* ]]
    jq -e '.family == "existing"' "$task_definition_file"
}

@test "initialize_resource selects an existing config file from the menu" {
    run_repo_script initialize_resource < <(select_resource_tag image; menu_select 0; echo "api")
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Select configuration file:"* ]]
    jq -e '.image[0].name == "api"' "$config_file"
}

@test "initialize_resource creates a new config file from the common template" {
    run_repo_script initialize_resource < <(select_resource_tag image; menu_select 1; echo "staging"; echo "api")
    [ "$status" -eq 0 ]

    local new_config_file="$root_directory/configurations/staging.config.json"
    [[ "$(plain_output)" == *"Configuration file created in $new_config_file"* ]]
    jq -e '.config.config_name == "staging"' "$new_config_file"
    jq -e '.config.aws_region == "us-east-1"' "$new_config_file"
    jq -e '.config.task_definitions_directory == "resources/staging/task_definitions"' "$new_config_file"
    jq -e '.config.ssm_parameters_directory == "resources/staging/ssm_parameters"' "$new_config_file"
    jq -e '.config.cf_parameter_file_directory == "resources/staging/cloudformation_parameters"' "$new_config_file"
    jq -e '.image[0].name == "api"' "$new_config_file"
}

@test "initialize_resource refuses to overwrite an existing config file" {
    run_repo_script initialize_resource < <(select_resource_tag image; menu_select 1; echo "test"; echo "api")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ALREADY EXISTS"* ]]
    jq -e 'has("image") | not' "$config_file"
}

@test "initialize_resource fails when the config file does not exist" {
    run_repo_script initialize_resource config=missing.config.json < <(select_resource_tag image; echo "api")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"MISSING.CONFIG.JSON NOT FOUND"* ]]
}

@test "initialize_resource rejects config paths outside the configurations directory" {
    run_repo_script initialize_resource config=../templates/config_templates.json < <(select_resource_tag image; echo "api")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"INVALID NAME"* ]]
}

@test "initialize_resource fails when the config file is not valid JSON" {
    echo "{ invalid" >"$config_file"
    run_repo_script initialize_resource config=test.config.json < <(select_resource_tag image; echo "api")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"INVALID JSON IN"* ]]
}

@test "initialize_resource fails when the config templates file is missing" {
    rm "$templates_file"
    run_repo_script initialize_resource config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"NOT FOUND"* ]]
}

@test "initialize_resource clones repos into the repos directory" {
    run_repo_script initialize_resource < <(select_resource_tag repo; echo "https://example.com/org/app.git")
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: REPO INITIALIZED"* ]]
    [ "$(mock_calls)" = "git -C $root_directory/repos clone -- https://example.com/org/app.git" ]
}

@test "initialize_resource fails when the clone fails" {
    mock_response git 128
    run_repo_script initialize_resource < <(select_resource_tag repo; echo "https://example.com/org/app.git")
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" != *"SUCCESS"* ]]
}
