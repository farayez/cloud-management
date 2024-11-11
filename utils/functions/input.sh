#!/bin/bash

# Ask for user input
fn_input_text() {
    echo -n -e "$CONSOLE_COLOR_CYAN$1$CONSOLE_COLOR_GREEN"
    read $2
    echo -e "$CONSOLE_COLOR_DEFAULT"
}

# Ask for user selection
function fn_choose_from_menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
    printf "$prompt\n"
    while true; do
        # list all options (option list is zero-based)
        index=0
        for o in "${options[@]}"; do
            if [ "$index" == "$cur" ]; then
                echo -e "\u25BA \e[7m$o\e[0m" # mark & highlight the current option
            else
                echo -e "  $o"
            fi
            index=$(($index + 1))
        done
        read -s -n3 key                # wait for user to key in arrows or ENTER
        if [[ $key == $'\e[A' ]]; then # up arrow
            cur=$(($cur - 1))
            [ "$cur" -lt 0 ] && cur=0
        elif [[ $key == $'\e[B' ]]; then # down arrow
            cur=$(($cur + 1))
            [ "$cur" -ge $count ] && cur=$(($count - 1))
        elif [[ $key == "" ]]; then # nothing, i.e the read delimiter - ENTER
            break
        fi
        echo -en "\e[${count}A" # go up to the beginning to re-render
    done
    # export the selection to the requested output variable
    printf -v $outvar "${options[$cur]}"
    echo ""
}
