#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region distribution_id paths

# Remove brackets and format paths as space-separated quoted strings
# First remove the brackets and split by comma
paths_clean=$(echo "$paths" | sed 's/^\[//; s/\]$//; s/","/\n/g; s/"//g')
formatted_paths=""
while IFS= read -r path; do
    if [[ -n "$path" ]]; then
        formatted_paths="$formatted_paths \"$path\""
    fi
done <<< "$paths_clean"
formatted_paths=$(echo $formatted_paths | sed 's/^ *//')

fn_run invalidate-cloudfront \
    --distribution-id $distribution_id \
    --paths $formatted_paths || fn_fatal

fn_success "Invalidation request sent to CloudFront"
