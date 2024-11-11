#!/bin/bash

# Echo alternatives
fn_info() {
    echo -e "$CONSOLE_COLOR_BLUE  $@$CONSOLE_COLOR_DEFAULT"
}
fn_error() {
    echo -e "$CONSOLE_COLOR_RED  ERROR: $@$CONSOLE_COLOR_DEFAULT" >&2
}
fn_debug() {
    echo -e "$CONSOLE_COLOR_BLACK$@$CONSOLE_COLOR_DEFAULT"
}
fn_warning() {
    echo -e "$CONSOLE_COLOR_YELLOW$@$CONSOLE_COLOR_DEFAULT"
}
fn_section_start() {
    echo -e "\n$CONSOLE_COLOR_PURPLE${@^^}$CONSOLE_COLOR_DEFAULT"
}
fn_section_end() {
    echo -e "$CONSOLE_COLOR_PURPLE${@^^}$CONSOLE_COLOR_DEFAULT\n"
}
fn_status() {
    echo -e "$CONSOLE_COLOR_PURPLE${@^^}$CONSOLE_COLOR_DEFAULT"
}

# Execution ended successfully
fn_success() {
    fn_draw_separator
    echo -e "\n${CONSOLE_COLOR_LIGHT_GREEN}SUCCESS: $CONSOLE_COLOR_GREEN${@^^}$CONSOLE_COLOR_DEFAULT\n"
    exit 0
}

# Execution ended with critical Error
fn_fatal() {
    fn_draw_separator
    if [ "$#" -lt 1 ]; then
        echo -e "\n${CONSOLE_COLOR_RED}EXECUTION FAILED$CONSOLE_COLOR_DEFAULT\n"
    else
        echo -e "\n$CONSOLE_COLOR_RED${1^^}$CONSOLE_COLOR_DEFAULT\n"
    fi

    exit 1
}

# Execution ended early
fn_halt() {
    fn_draw_separator
    if [ "$#" -lt 1 ]; then
        echo -e "\n${CONSOLE_COLOR_YELLOW}EXECUTION HALTED$CONSOLE_COLOR_DEFAULT\n"
    else
        echo -e "\n$CONSOLE_COLOR_YELLOW${@^^}$CONSOLE_COLOR_DEFAULT\n"
    fi

    exit 0
}

# Draw separator to visually isolate sections or stages
fn_draw_separator() {
    echo -e -n "${CONSOLE_COLOR_PURPLE}"
    half_terminal_width=$(($(tput cols) * 2 / 3))
    dashes_to_print=$((70 < half_terminal_width ? 80 : half_terminal_width))
    printf '%*s\n' "$dashes_to_print" | tr ' ' '-'
    echo -e -n "${CONSOLE_COLOR_DEFAULT}"
}
