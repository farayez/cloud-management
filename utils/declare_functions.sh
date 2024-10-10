#!/bin/bash

# Function to validate variables
validate_variables() {
    info "\nVariable Validation"

    local variable
    local validated=1
    for variable in $@
    do
        if [ ! -v ${variable} ]; then
            error "$variable must be set"
            validated=0
        fi
    done

    if [ $validated -eq 0 ]; then
        exit 2
    fi

    echo -e "Successful"
}

# Echo all variables
print_variables() {
    local variable

    if [ "$#" -lt 1 ]; then
        list_declared_variables

        echo -e "total variables $CONSOLE_COLOR_YELLOW${#declared_variables[@]}$CONSOLE_NO_COLOR"

        for variable in ${declared_variables[@]}
        do
            echo -e $CONSOLE_COLOR_WHITE$variable$CONSOLE_NO_COLOR = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_NO_COLOR
        done
    else
        for variable in $@
        do
            echo -e $CONSOLE_COLOR_WHITE$variable$CONSOLE_NO_COLOR = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_NO_COLOR
        done
    fi

}

# List all variables in declared_variables
list_declared_variables() {
    unset declared_variables
    declared_variables=($(compgen -A variable | grep '^[a-z].*' | grep -v '^npm_*'))
}

# Setup Console Colors
define_console_colors() {
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
    CONSOLE_NO_COLOR='\033[0m'
}

# Echo alternatives
info() {
    echo -e "$CONSOLE_COLOR_BLUE$@$CONSOLE_NO_COLOR"
}
error() {
    echo -e "$CONSOLE_COLOR_RED$@$CONSOLE_NO_COLOR"
}
debug() {
    echo -e "$CONSOLE_COLOR_BLACK$@$CONSOLE_NO_COLOR"
}
warning() {
    echo -e "$CONSOLE_COLOR_YELLOW$@$CONSOLE_NO_COLOR"
}
section() {
    echo -e "$CONSOLE_COLOR_PURPLE$@$CONSOLE_NO_COLOR"
}