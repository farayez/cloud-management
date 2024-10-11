#!/bin/bash

# Function to validate variables
fn_validate_variables() {
    local variable
    local validated=1
    for variable in $@
    do
        if [ -z "${!variable}" ]; then
            fn_error "$variable must be set"
            validated=0
        fi
    done

    if [ $validated -eq 0 ]; then
        fn_fatal "Config validation failed"
    fi


    fn_info "\nCONFIG VALIDATION SUCCESSFUL"
}

# Echo all variables
fn_print_variables() {
    local variable

    if [ "$#" -lt 1 ]; then
        fn_list_declared_variables

        echo -e "total variables $CONSOLE_COLOR_YELLOW${#declared_variables[@]}$CONSOLE_COLOR_DEFAULT"

        for variable in ${declared_variables[@]}
        do
            echo -e $CONSOLE_COLOR_LIGHT_GRAY$variable$CONSOLE_COLOR_DEFAULT = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_COLOR_DEFAULT
        done
    else
        for variable in $@
        do
            echo -e $CONSOLE_COLOR_LIGHT_GRAY$variable$CONSOLE_COLOR_DEFAULT = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_COLOR_DEFAULT
        done
    fi

}

# List all variables in declared_variables
fn_list_declared_variables() {
    unset declared_variables
    declared_variables=($(compgen -A variable | grep '^[a-z].*' | grep -v '^npm_*'))
}

# Setup Console Colors
fn_define_console_colors() {
    CONSOLE_COLOR_BLACK='\033[0;30m'
    CONSOLE_COLOR_RED='\033[0;31m'
    CONSOLE_COLOR_GREEN='\033[0;32m'
    CONSOLE_COLOR_BROWN='\033[0;33m'
    CONSOLE_COLOR_BLUE='\033[0;34m'
    CONSOLE_COLOR_PURPLE='\033[0;35m'
    CONSOLE_COLOR_CYAN='\033[0;36m'
    CONSOLE_COLOR_LIGHT_GRAY='\033[0;37m'
    CONSOLE_COLOR_DARK_GRAY='\033[1;30m'
    CONSOLE_COLOR_LIGHT_RED='\033[1;31m'
    CONSOLE_COLOR_LIGHT_GREEN='\033[1;32m'
    CONSOLE_COLOR_YELLOW='\033[1;33m'
    CONSOLE_COLOR_LIGHT_BLUE='\033[1;34m'
    CONSOLE_COLOR_LIGHT_PURPLE='\033[1;35m'
    CONSOLE_COLOR_LIGHT_CYAN='\033[1;36m'
    CONSOLE_COLOR_WHITE='\033[1;37m'
    CONSOLE_COLOR_DEFAULT='\033[0m'
}
fn_demo_colors() {
    declared_colors=($(compgen -A variable | grep '^CONSOLE_COLOR_*'))

    for variable in ${declared_colors[@]}
    do
        echo -e ${!variable}$variable$CONSOLE_COLOR_DEFAULT
    done

    unset declared_colors
}

# Echo alternatives
fn_info() {
    echo -e "$CONSOLE_COLOR_BLUE$@$CONSOLE_COLOR_DEFAULT"
}
fn_error() {
    echo -e "$CONSOLE_COLOR_RED  ERROR: $@$CONSOLE_COLOR_DEFAULT"
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
fn_success() {
    echo -e "\n${CONSOLE_COLOR_LIGHT_GREEN}SUCCESS: $CONSOLE_COLOR_GREEN${@^^}$CONSOLE_COLOR_DEFAULT\n"
}

# Ask for user input
fn_input_text() {
    echo -n -e "$CONSOLE_COLOR_CYAN$1$CONSOLE_COLOR_GREEN"
    read $2
    echo -e "$CONSOLE_COLOR_DEFAULT"
}

# Fatal Error
fn_fatal() {
    if [ "$#" -lt 1 ]; then
        echo -e "\n${CONSOLE_COLOR_RED}EXECUTION FAILED$CONSOLE_COLOR_DEFAULT\n"
    else
        echo -e "\n$CONSOLE_COLOR_RED${1^^}$CONSOLE_COLOR_DEFAULT\n"
    fi

    exit 1
}