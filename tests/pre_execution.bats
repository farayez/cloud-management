#!/usr/bin/env bats

# End-to-end tests of utils/pre_execution.sh as sourced by every scripts/*.sh

setup() {
    load test_helper
    setup_runtime_globals
    write_test_config

    ln -s "$REPO_ROOT/utils" "$root_directory/utils"
    mkdir -p "$root_directory/scripts"

    local name
    for name in ssh_into_server run_command_in_server unknown_script; do
        cat >"$root_directory/scripts/$name.sh" <<'EOF'
#!/bin/bash
. ./utils/pre_execution.sh
echo "resource_tag=$resource_tag"
echo "resource_name=$resource_name"
echo "host=$host"
echo "command1=$command1"
echo "AWS_PROFILE=$AWS_PROFILE"
echo "AWS_CONFIG_FILE=$AWS_CONFIG_FILE"
echo "AWS_SHARED_CREDENTIALS_FILE=$AWS_SHARED_CREDENTIALS_FILE"
EOF
    done
}

run_script() {
    local name=$1
    shift
    cd "$root_directory"
    run bash "scripts/$name.sh" "$@"
}

@test "pre_execution populates resource and config variables" {
    run_script ssh_into_server config=test.config.json resource=web
    [ "$status" -eq 0 ]
    [[ "$output" == *"resource_tag=server"* ]]
    [[ "$output" == *"resource_name=web"* ]]
    [[ "$output" == *"host=10.0.0.1"* ]]
}

@test "pre_execution configures the AWS environment" {
    run_script ssh_into_server config=test.config.json resource=web
    [[ "$output" == *"AWS_PROFILE=test-profile"* ]]
    [[ "$output" == *"AWS_CONFIG_FILE=$root_directory/.aws/config"* ]]
    [[ "$output" == *"AWS_SHARED_CREDENTIALS_FILE=$root_directory/.aws/credentials"* ]]
}

@test "pre_execution loads the selected item" {
    run_script run_command_in_server config=test.config.json resource=web item=deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *'command1="echo hi"'* ]]
}

@test "pre_execution fails when the resource argument is missing" {
    run_script ssh_into_server config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"resource argument must be populated"* ]]
}

@test "pre_execution fails when a required item is missing" {
    run_script run_command_in_server config=test.config.json resource=web
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"item argument must be populated (one of the commands entries)"* ]]
}

@test "pre_execution fails when the item does not exist" {
    run_script run_command_in_server config=test.config.json resource=web item=missing
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"NO COMMANDS ENTRY FOUND WITH NAME MISSING"* ]]
}

@test "pre_execution fails for scripts without a resource tag mapping" {
    run_script unknown_script config=test.config.json resource=web
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"resource_tag must be provided"* ]]
}

@test "pre_execution only calls functions that are defined" {
    run_script ssh_into_server config=test.config.json resource=web
    [[ "$output" != *"command not found"* ]]
}
