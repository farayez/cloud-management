#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    load test_helper
    setup_runtime_globals
    source_common_functions
}

@test "fn_info prints the message in blue" {
    run fn_info "hello"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\033[0;34m'*"hello"* ]]
}

@test "fn_error writes an ERROR-prefixed message to stderr only" {
    run --separate-stderr fn_error "boom"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [[ "$(printf '%s' "$stderr" | strip_colors)" == "  ERROR: boom" ]]
}

@test "fn_debug and fn_warning print the message" {
    run fn_debug "debug message"
    [ "$(plain_output)" = "debug message" ]

    run fn_warning "warning message"
    [ "$(plain_output)" = "warning message" ]
}

@test "fn_section_start, fn_section_end and fn_status uppercase the message" {
    run fn_section_start "repo update"
    [[ "$(plain_output)" == *"REPO UPDATE"* ]]

    run fn_section_end "repo update"
    [[ "$(plain_output)" == *"REPO UPDATE"* ]]

    run fn_status "in progress"
    [ "$(plain_output)" = "IN PROGRESS" ]
}

@test "fn_success exits 0 with an uppercased success message" {
    run fn_success "image pushed"
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: IMAGE PUSHED"* ]]
}

@test "fn_fatal exits 1 with a default message" {
    run fn_fatal
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"EXECUTION FAILED"* ]]
}

@test "fn_fatal exits 1 with an uppercased custom message" {
    run fn_fatal "config validation failed"
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"CONFIG VALIDATION FAILED"* ]]
    [[ "$(plain_output)" != *"EXECUTION FAILED"* ]]
}

@test "fn_fatal stops execution of the calling shell" {
    run bash -c "source '$REPO_ROOT/utils/functions/output.sh'; fn_fatal; echo unreachable"
    [ "$status" -eq 1 ]
    [[ "$output" != *"unreachable"* ]]
}

@test "fn_halt exits 0 with a default message" {
    run fn_halt
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"EXECUTION HALTED"* ]]
}

@test "fn_halt exits 0 with an uppercased custom message" {
    run fn_halt "nothing to do"
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"NOTHING TO DO"* ]]
}

@test "fn_draw_separator prints 80 dashes on wide terminals" {
    COLUMNS=200 run fn_draw_separator
    [ "$(plain_output)" = "$(printf '%*s' 80 | tr ' ' '-')" ]
}

@test "fn_draw_separator prints two thirds of the width on narrow terminals" {
    COLUMNS=60 run fn_draw_separator
    [ "$(plain_output)" = "$(printf '%*s' 40 | tr ' ' '-')" ]
}
