#!/bin/bash

. ./utils/prepare_runtime.sh

# Get user input for resource type
options=("${!resource_tag_to_directory_map[@]}" "\u2606 ALL \u2606")
fn_choose_from_menu "Delete history for resource type:" resource_tag "${options[@]}"

if [ "$resource_tag" = $'\u2606 ALL \u2606' ]; then
    for resource_tag in "${!resource_tag_to_directory_map[@]}"; do
        # Remove history for all resources of resource_tag
        fn_populate_and_validate_resource_directory_from_resource_tag
        if [ ! -d $resource_directory/history ]; then
            fn_error "No history found for $resource_tag"
        else
            rm -r $resource_directory/history || fn_fatal
            fn_info "All histories removed from $resource_tag"
        fi
    done

    fn_success "History cleanup complete"
fi

fn_populate_and_validate_resource_directory_from_resource_tag

# Get user input for name of resource
options=($(fn_get_all_resource_names_in_directory "$resource_directory") "\u2606 ALL \u2606")

if [ ${#options[@]} -lt 2 ]; then
    fn_error "No $resource_tag found"
    fn_halt "No Action Taken"
fi

fn_choose_from_menu "Select resource:" resource_name "${options[@]}"

if [ "$resource_name" = $'\u2606 ALL \u2606' ]; then
    # Remove history for all resources of resource_tag
    if [ ! -d $resource_directory/history ]; then
        fn_error "No history found for $resource_tag"
        fn_halt "No Action Taken"
    fi
    rm -r $resource_directory/history || fn_fatal

    fn_info "\nAll histories removed from $resource_tag"
    fn_success "History cleanup complete"
fi

# Remove history for resource
if [ ! -d $resource_directory/history/$resource_name ]; then
    fn_error "No history found for $resource_tag $resource_name"
    fn_halt "No Action Taken"
fi
rm -r $resource_directory/history/$resource_name || fn_fatal

fn_info "\nAll histories removed for $resource_tag $resource_name"
fn_success "History cleanup complete"
