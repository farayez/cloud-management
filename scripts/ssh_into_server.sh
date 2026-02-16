#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables host username key_path

# Set permissions for the SSH key to be read-only by the user
chmod 400 $root_directory/$key_path

# Use the SSH key to connect to the server
# If starting_directory is set, cd to it after connection
if [ -n "$starting_directory" ]; then
  ssh -t $username@$host -i $root_directory/$key_path "cd $starting_directory && exec \$SHELL -l"
else
  ssh $username@$host -i $root_directory/$key_path
fi
