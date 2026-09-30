#!/usr/bin/env bats

setup() {
    load test_helper
    setup_runtime_globals
    source_common_functions
    write_test_config
}

# fn_get_variable_export_strings_from_json

@test "fn_get_variable_export_strings_from_json prints key=value lines from .config" {
    run fn_get_variable_export_strings_from_json '{"config":{"a":"1","b":"two"}}'
    [ "$status" -eq 0 ]
    [ "$output" = $'a=1\nb=two' ]
}

@test "fn_get_variable_export_strings_from_json wraps values containing spaces in quotes" {
    run fn_get_variable_export_strings_from_json '{"config":{"cmd":"echo hi"}}'
    [ "$output" = 'cmd="echo hi"' ]
}

@test "fn_get_variable_export_strings_from_json skips null and empty object values" {
    run fn_get_variable_export_strings_from_json '{"config":{"a":null,"b":{},"c":"x"}}'
    [ "$output" = "c=x" ]
}

@test "fn_get_variable_export_strings_from_json stringifies numbers, booleans and arrays" {
    run fn_get_variable_export_strings_from_json '{"config":{"n":22,"b":true,"arr":["/*"]}}'
    [ "$output" = $'n=22\nb=true\narr=["/*"]' ]
}

# fn_populate_config_variables_from_json

@test "fn_populate_config_variables_from_json exports every config value" {
    fn_populate_config_variables_from_json '{"config":{"alpha":"a","beta":"b c"}}'
    [ "$alpha" = "a" ]
    [ "$beta" = '"b c"' ]
    [[ "$(export -p)" == *"declare -x alpha=\"a\""* ]]
}

@test "fn_populate_config_variables_from_json does nothing for empty input" {
    run fn_populate_config_variables_from_json ""
    [ "$status" -eq 0 ]
}

# fn_populate_config_variables

@test "fn_populate_config_variables loads stack and resource config" {
    config=test.config.json
    resource_tag=server
    resource_name=web
    current_script_name=ssh_into_server
    unset item

    fn_populate_config_variables

    [ "$aws_profile" = "test-profile" ]
    [ "$aws_region" = "us-east-1" ]
    [ "$host" = "10.0.0.1" ]
    [ "$username" = "ubuntu" ]
    [ "$description" = '"main web server"' ]
    [ "$port" = "22" ]
    [ "$enabled" = "true" ]
    [ "$paths" = '["/*"]' ]
    [ ! -v unused ]
    [ ! -v nested ]
    [ ! -v command1 ]
}

@test "fn_populate_config_variables lets resource config override stack config" {
    config=test.config.json
    resource_tag=server
    resource_name=web
    current_script_name=ssh_into_server

    fn_populate_config_variables

    [ "$shared" = "resource" ]
}

@test "fn_populate_config_variables selects the matching resource by name" {
    config=test.config.json
    resource_tag=server
    resource_name=db
    current_script_name=ssh_into_server

    fn_populate_config_variables

    [ "$host" = "10.0.0.2" ]
    [ "$shared" = "stack" ]
    [ ! -v username ]
}

@test "fn_populate_config_variables only loads stack config for unknown resources" {
    config=test.config.json
    resource_tag=server
    resource_name=missing
    current_script_name=ssh_into_server

    fn_populate_config_variables

    [ "$aws_profile" = "test-profile" ]
    [ ! -v host ]
}

@test "fn_populate_config_variables loads the selected sub-resource item" {
    config=test.config.json
    resource_tag=server
    resource_name=web
    current_script_name=run_command_in_server
    item=deploy

    fn_populate_config_variables

    [ "$host" = "10.0.0.1" ]
    [ "$command1" = '"echo hi"' ]
    [ "$command2" = "ls" ]
    [ ! -v name ]
}

@test "fn_populate_config_variables ignores item for scripts without sub-resources" {
    config=test.config.json
    resource_tag=server
    resource_name=web
    current_script_name=ssh_into_server
    item=deploy

    fn_populate_config_variables

    [ ! -v command1 ]
}

@test "fn_populate_config_variables fails when the item does not exist" {
    config=test.config.json
    resource_tag=server
    resource_name=web
    current_script_name=run_command_in_server
    item=missing

    run fn_populate_config_variables
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"NO COMMANDS ENTRY FOUND WITH NAME MISSING"* ]]
}

@test "fn_populate_config_variables falls back to default.config.json" {
    write_test_config default.config.json
    unset config
    resource_tag=server
    resource_name=web
    current_script_name=ssh_into_server

    fn_populate_config_variables

    [ "$aws_profile" = "test-profile" ]
    [ "$host" = "10.0.0.1" ]
}
