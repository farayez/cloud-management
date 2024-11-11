#!/bin/bash

# Echo all variables
fn_print_variables() {
    local variable

    if [ "$#" -lt 1 ]; then
        fn_list_declared_variables

        echo -e "total variables $CONSOLE_COLOR_YELLOW${#declared_variables[@]}$CONSOLE_COLOR_DEFAULT"

        for variable in ${declared_variables[@]}; do
            echo -e $CONSOLE_COLOR_LIGHT_GRAY$variable$CONSOLE_COLOR_DEFAULT = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_COLOR_DEFAULT
        done
    else
        for variable in $@; do
            echo -e $CONSOLE_COLOR_LIGHT_GRAY$variable$CONSOLE_COLOR_DEFAULT = $CONSOLE_COLOR_BLACK${!variable}$CONSOLE_COLOR_DEFAULT
        done
    fi

}

fn_demo_colors() {
    declared_colors=($(compgen -A variable | grep '^CONSOLE_COLOR_*'))

    for variable in ${declared_colors[@]}; do
        echo -e ${!variable}$variable$CONSOLE_COLOR_DEFAULT
    done

    unset declared_colors
}
