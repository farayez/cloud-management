#!/usr/bin/env bats

setup() {
    load test_helper
    setup_runtime_globals
    source_common_functions
}

@test "fn_print_variables prints the given variables with their values" {
    alpha=one
    beta=two
    run fn_print_variables alpha beta
    [ "$status" -eq 0 ]
    [ "$(plain_output)" = $'alpha = one\nbeta = two' ]
}

@test "fn_print_variables without arguments prints all declared variables" {
    my_print_test_variable=hello
    run fn_print_variables
    [[ "$(plain_output)" == "total variables "* ]]
    [[ "$(plain_output)" == *"my_print_test_variable = hello"* ]]
}

@test "fn_demo_colors prints every console color" {
    run fn_demo_colors
    [ "$status" -eq 0 ]
    [ "$(plain_output | wc -l)" -eq "$(compgen -A variable | grep -c '^CONSOLE_COLOR_')" ]
    [[ "$(plain_output)" == *"CONSOLE_COLOR_RED"* ]]
    [[ "$(plain_output)" == *"CONSOLE_COLOR_DEFAULT"* ]]
}
