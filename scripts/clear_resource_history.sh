#!/bin/bash

. ./utils/initialize_execution.sh

# Get user input for resource type
options=("${!resource_tag_to_directory_map[@]}" "\u2606 ALL \u2606")
fn_choose_from_menu "Delete history for resource type:" resource_tag "${options[@]}"

echo -e ""

if [ "$resource_tag" = $'\u2606 ALL \u2606' ]; then
    for resource_tag in "${!resource_tag_to_directory_map[@]}"; do
        echo -e "$CONSOLE_COLOR_PURPLE${resource_tag^^}$CONSOLE_COLOR_DEFAULT"
        # Remove history for all resources of resource_tag
        # resource_directory="${resource_tag_to_directory_map[$resource_tag]}"
    done

    fn_success "All histories removed"
    exit 0
fi

fn_populate_and_validate_resource_directory_from_resource_tag

# Get user input for name of resource
options=($(fn_get_all_resource_names_in_directory "$resource_directory") "\u2606 ALL \u2606")
fn_choose_from_menu "Select resource:" resource_name "${options[@]}"

if [ "$resource_name" = $'\u2606 ALL \u2606' ]; then
    # Remove history for all resources of resource_tag
    fn_info "\nAll histories removed from $resource_tag"
    fn_success "History cleanup complete"
    exit 0
fi

# Remove history for resource
# rm -r $resource_directory/history/$resource_name/* || fn_fatal

fn_info "\nAll histories removed for $resource_tag $resource_name"
fn_success "History cleanup complete"
