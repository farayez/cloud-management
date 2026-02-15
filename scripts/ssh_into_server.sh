#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables host username key_path

# Set permissions for the SSH keyto be read-only by the user
chmod 400 $root_directory/$key_path

# Use the SSH key to connect to the server
ssh $username@$host -i $root_directory/$key_path
