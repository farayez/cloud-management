#!/bin/bash

. ./utils/prepare_runtime.sh

# History layout: history/<config_name>/<resource_tag>/<resource_name>/
history_directory="$root_directory/history"
all_option=$'\u2606 ALL \u2606'

# Delete the selected directory, or every subdirectory of $target_directory when ALL is chosen
fn_clear_history() {
    local description="$1"
    if [ "$selection" = "$all_option" ]; then
        find "$target_directory" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} + || fn_fatal
    else
        rm -r "$target_directory/$selection" || fn_fatal
        description="$description/$selection"
    fi

    # Drop parent directories left empty by the deletion
    find "$history_directory" -mindepth 1 -type d -empty -delete

    fn_info "\nAll histories removed for ${description:-all configurations}"
    fn_success "History cleanup complete"
}

target_directory="$history_directory"
description=""
for level in "configuration" "resource type" "resource"; do
    mapfile -t subdirectories < <(find "$target_directory" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)

    if [ ${#subdirectories[@]} -eq 0 ]; then
        fn_error "No history found${description:+ for ${description#/}}"
        fn_halt "No Action Taken"
    fi

    fn_choose_from_menu "Delete history for $level:" selection "${subdirectories[@]}" "$all_option"

    if [ "$selection" = "$all_option" ] || [ "$level" = "resource" ]; then
        fn_clear_history "${description#/}"
    fi

    target_directory="$target_directory/$selection"
    description="$description/$selection"
done
