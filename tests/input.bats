#!/usr/bin/env bats

setup() {
    load test_helper
    setup_runtime_globals
    source_common_functions
}

@test "fn_input_text reads input into the named variable" {
    fn_input_text "Enter branch: " branch <<<"feature/x" >/dev/null
    [ "$branch" = "feature/x" ]
}

@test "fn_input_text prints the prompt" {
    run fn_input_text "Enter branch: " branch <<<"main"
    [[ "$(plain_output)" == "Enter branch: "* ]]
}

@test "fn_request_mandatory_text_input stores input in user_input by default" {
    fn_request_mandatory_text_input "Value: " <<<"abc" >/dev/null
    [ "$user_input" = "abc" ]
}

@test "fn_request_mandatory_text_input stores input in the named variable" {
    fn_request_mandatory_text_input "Value: " my_value <<<"xyz" >/dev/null
    [ "$my_value" = "xyz" ]
}

@test "fn_request_mandatory_text_input fails on empty input" {
    run fn_request_mandatory_text_input "Value: " my_value <<<""
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: Input must be provided to continue execution"* ]]
}

@test "fn_choose_from_menu selects the first option on ENTER" {
    fn_choose_from_menu "Select:" choice one two three < <(printf '\n') >/dev/null
    [ "$choice" = "one" ]
}

@test "fn_choose_from_menu moves down with the down arrow" {
    fn_choose_from_menu "Select:" choice one two three < <(printf '\e[B\e[B\n') >/dev/null
    [ "$choice" = "three" ]
}

@test "fn_choose_from_menu moves up with the up arrow" {
    fn_choose_from_menu "Select:" choice one two three < <(printf '\e[B\e[B\e[A\n') >/dev/null
    [ "$choice" = "two" ]
}

@test "fn_choose_from_menu does not move above the first option" {
    fn_choose_from_menu "Select:" choice one two three < <(printf '\e[A\e[A\n') >/dev/null
    [ "$choice" = "one" ]
}

@test "fn_choose_from_menu does not move below the last option" {
    fn_choose_from_menu "Select:" choice one two < <(printf '\e[B\e[B\e[B\n') >/dev/null
    [ "$choice" = "two" ]
}

@test "fn_choose_from_menu renders the prompt and options" {
    run fn_choose_from_menu "Select branch:" choice main develop < <(printf '\n')
    [[ "$(plain_output)" == *"Select branch:"* ]]
    [[ "$(plain_output)" == *"main"* ]]
    [[ "$(plain_output)" == *"develop"* ]]
}
