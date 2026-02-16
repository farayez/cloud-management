#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables host username key_path local_directory_path remote_directory

# Set permissions for the SSH key to be read-only by the user
chmod 400 $root_directory/$key_path

scp -i $root_directory/$key_path \
    -r $root_directory/$local_directory_path \
    $username@$host:$remote_directory || fn_fatal "Failed to copy files to server"

fn_success "Files copied to server successfully"
