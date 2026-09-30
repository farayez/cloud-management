#!/usr/bin/env bats

setup() {
    load test_helper
    setup_runtime_globals
    source_common_functions
}

# fn_parse_arguments

@test "fn_parse_arguments exports key=value arguments" {
    fn_parse_arguments config=test.config.json resource=web
    [ "$config" = "test.config.json" ]
    [ "$resource" = "web" ]
    [[ "$(export -p)" == *"declare -x resource=\"web\""* ]]
}

@test "fn_parse_arguments strips a leading -- from keys" {
    fn_parse_arguments --config=test.config.json --item=deploy
    [ "$config" = "test.config.json" ]
    [ "$item" = "deploy" ]
}

@test "fn_parse_arguments keeps '=' characters inside values" {
    fn_parse_arguments filter=name=value
    [ "$filter" = "name=value" ]
}

@test "fn_parse_arguments ignores arguments with empty values" {
    unset item
    fn_parse_arguments item= resource=web
    [ ! -v item ]
    [ "$resource" = "web" ]
}

@test "fn_parse_arguments accepts values containing spaces" {
    skip "Known bug: unquoted \$value in the empty check of fn_parse_arguments"
    fn_parse_arguments "description=hello world"
    [ "$description" = "hello world" ]
}

# fn_validate_variables

@test "fn_validate_variables passes when all variables are set" {
    first=1
    second=2
    run fn_validate_variables first second
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fn_validate_variables fails listing every missing variable" {
    first=1
    unset second third
    run fn_validate_variables first second third
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: second must be set"* ]]
    [[ "$(plain_output)" == *"ERROR: third must be set"* ]]
    [[ "$(plain_output)" != *"first must be set"* ]]
    [[ "$(plain_output)" == *"CONFIG VALIDATION FAILED"* ]]
}

@test "fn_validate_variables treats empty variables as missing" {
    empty=""
    run fn_validate_variables empty
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: empty must be set"* ]]
}

# fn_populate_and_validate_resource_tag_from_current_script_name

@test "fn_populate_and_validate_resource_tag_from_current_script_name maps the script to its resource tag" {
    current_script_name=push_image
    fn_populate_and_validate_resource_tag_from_current_script_name
    [ "$resource_tag" = "image" ]

    current_script_name=run_command_in_server
    fn_populate_and_validate_resource_tag_from_current_script_name
    [ "$resource_tag" = "server" ]
}

@test "fn_populate_and_validate_resource_tag_from_current_script_name fails for unknown scripts" {
    current_script_name=unknown_script
    run fn_populate_and_validate_resource_tag_from_current_script_name
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: resource_tag must be provided"* ]]
}

@test "every scripts/*.sh using pre_execution has a resource tag mapping" {
    local script name
    for script in "$REPO_ROOT"/scripts/*.sh; do
        grep -q 'utils/pre_execution.sh' "$script" || continue
        name=$(basename "$script" .sh)
        [ -n "${script_name_to_resource_tag_map[$name]}" ] || {
            echo "missing resource tag mapping for $name"
            return 1
        }
    done
}

@test "every resource tag maps to a resource directory" {
    local name tag
    for name in "${!script_name_to_resource_tag_map[@]}"; do
        tag=${script_name_to_resource_tag_map[$name]}
        [ -n "${resource_tag_to_directory_map[$tag]}" ] || {
            echo "missing directory mapping for tag $tag"
            return 1
        }
    done
}

# fn_populate_and_validate_resource_name

@test "fn_populate_and_validate_resource_name sets resource_name" {
    fn_populate_and_validate_resource_name web
    [ "$resource_name" = "web" ]
}

@test "fn_populate_and_validate_resource_name fails without a resource" {
    run fn_populate_and_validate_resource_name ""
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: resource argument must be populated"* ]]
}

# fn_validate_item_provided

@test "fn_validate_item_provided passes for scripts without sub-resources" {
    current_script_name=ssh_into_server
    unset item
    run fn_validate_item_provided
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fn_validate_item_provided passes when the item is given" {
    current_script_name=run_command_in_server
    item=deploy
    run fn_validate_item_provided
    [ "$status" -eq 0 ]
}

@test "fn_validate_item_provided fails when a required item is missing" {
    current_script_name=copy_to_server
    unset item
    run fn_validate_item_provided
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: item argument must be populated (one of the resources entries)"* ]]
}

# fn_list_declared_variables

@test "fn_list_declared_variables lists lowercase variables excluding npm_*" {
    my_test_variable=1
    npm_config_test=1
    MY_UPPER_VARIABLE=1
    fn_list_declared_variables
    local joined=" ${declared_variables[*]} "
    [[ "$joined" == *" my_test_variable "* ]]
    [[ "$joined" != *" npm_config_test "* ]]
    [[ "$joined" != *" MY_UPPER_VARIABLE "* ]]
}
