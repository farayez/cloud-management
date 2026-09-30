#!/usr/bin/env bats

setup() {
    load test_helper
    setup_runtime_globals
    source_common_functions

    resource_tag=image
    resource_name=my-image
    config_name=my-config
    history_file="$root_directory/history/my-config/image/my-image/test_execution.test_script.history"

    command_map["test-echo"]="echo"
    command_map["test-fail"]="false"
    command_map["test-silent"]="echo,--no-echo"
    command_map["test-unbuffered"]="echo,--unbuffered-echo"
}

# fn_run

@test "fn_run fails for unknown command keys" {
    run fn_run does-not-exist
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"Command key 'does-not-exist' not found in the map."* ]]
    [ ! -e "$root_directory/history" ]
}

@test "fn_run runs the mapped command and echoes its output" {
    run fn_run test-echo hello
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "fn_run preserves arguments containing spaces" {
    run fn_run test-echo "hello   world"
    [ "$output" = "hello   world" ]
}

@test "fn_run logs the command, output and exit status to the history file" {
    run fn_run test-echo hello
    [ -f "$history_file" ]

    local history
    history=$(<"$history_file")
    [[ "$history" == *"========== START"* ]]
    [[ "$history" == *"UNBUFFERED ECHO: false"* ]]
    [[ "$history" == *$'---------- COMMAND\necho hello'* ]]
    [[ "$history" == *$'---------- OUTPUT\nhello'* ]]
    [[ "$history" == *"---------- EXIT STATUS: 0"* ]]
}

@test "fn_run appends consecutive runs to the same history file" {
    run fn_run test-echo first
    run fn_run test-echo second
    [ "$(grep -c '========== START' "$history_file")" -eq 2 ]
}

@test "fn_run copies the history .gitignore template" {
    run fn_run test-echo hello
    cmp "$root_directory/history/.gitignore" "$REPO_ROOT/templates/history.gitignore.template"
}

@test "fn_run fails when the history .gitignore template is missing" {
    rm "$root_directory/templates/history.gitignore.template"
    run fn_run test-echo hello
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"Could not copy .gitignore template"* ]]
}

@test "fn_run returns the exit code of the command" {
    run fn_run test-fail
    [ "$status" -eq 1 ]
    [[ "$(<"$history_file")" == *"---------- EXIT STATUS: 1"* ]]
}

@test "fn_run --no-echo logs output without printing it" {
    run fn_run test-silent quiet
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [[ "$(<"$history_file")" == *$'---------- OUTPUT\nquiet'* ]]
}

@test "fn_run --unbuffered-echo prints and logs output" {
    run fn_run test-unbuffered loud
    [ "$status" -eq 0 ]
    [[ "$output" == *"loud"* ]]
    [[ "$(<"$history_file")" == *"UNBUFFERED ECHO: true"* ]]
    [[ "$(<"$history_file")" == *"loud"* ]]
}

@test "fn_run --unbuffered-echo returns the exit code of the command" {
    command_map["test-unbuffered-fail"]="false,--unbuffered-echo"
    run fn_run test-unbuffered-fail
    [ "$status" -eq 1 ]
    [[ "$(<"$history_file")" == *"---------- EXIT STATUS: 1"* ]]
}

@test "every command_map entry only uses supported options" {
    local key option
    local -a parts
    for key in "${!command_map[@]}"; do
        IFS=',' read -r -a parts <<<"${command_map[$key]}"
        for option in "${parts[@]:1}"; do
            case "$option" in
            --buffered-echo | --unbuffered-echo | --no-echo) ;;
            *)
                echo "unsupported option '$option' for command '$key'"
                return 1
                ;;
            esac
        done
    done
}

# fn_get_codedeploy_revision_json

@test "fn_get_codedeploy_revision_json fails when parameters are missing" {
    run fn_get_codedeploy_revision_json "arn:task" "app"
    [ "$status" -eq 1 ]
    [ "$output" = "Error: Missing required parameters." ]
}

@test "fn_get_codedeploy_revision_json builds a compact AppSpec revision" {
    run fn_get_codedeploy_revision_json "arn:aws:ecs:task/app:1" "application" 8080
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | wc -l)" -eq 1 ]
    [ "$(echo "$output" | jq -r '.revisionType')" = "AppSpecContent" ]

    local content
    content=$(echo "$output" | jq -r '.appSpecContent.content')
    [ "$(echo "$content" | jq -r '.version')" = "1" ]
    [ "$(echo "$content" | jq -r '.Resources[0].TargetService.Type')" = "AWS::ECS::Service" ]
    [ "$(echo "$content" | jq -r '.Resources[0].TargetService.Properties.TaskDefinition')" = "arn:aws:ecs:task/app:1" ]
    [ "$(echo "$content" | jq -r '.Resources[0].TargetService.Properties.LoadBalancerInfo.ContainerName')" = "application" ]
    [ "$(echo "$content" | jq '.Resources[0].TargetService.Properties.LoadBalancerInfo.ContainerPort')" = "8080" ]
}
