#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables host username key_path local_directory_path remote_directory

# Set permissions for the SSH key to be read-only by the user
chmod 400 $root_directory/$key_path

fn_section_start "Preparing remote directory"
fn_info "$username@$host:$remote_directory"
fn_run ssh -i "$root_directory/$key_path" "$username@$host" "mkdir -p $remote_directory" ||
    fn_fatal "Failed to create remote directory"

if [ -f "$root_directory/$local_directory_path" ]; then
    fn_section_start "Copying file"
    fn_info "$root_directory/$local_directory_path -> $username@$host:$remote_directory/"
    fn_run scp -i "$root_directory/$key_path" \
        "$root_directory/$local_directory_path" \
        "$username@$host:$remote_directory/" || fn_fatal "Failed to copy files to server"
else
    fn_section_start "Copying directory contents"
    fn_info "$root_directory/$local_directory_path/* -> $username@$host:$remote_directory/"
    fn_run scp -i "$root_directory/$key_path" \
        -r "$root_directory/$local_directory_path"/* \
        "$username@$host:$remote_directory/" || fn_fatal "Failed to copy files to server"
fi

fn_success "Files copied to server successfully"
