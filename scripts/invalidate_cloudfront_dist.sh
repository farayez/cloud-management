#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region distribution_id paths

# paths is a JSON array (or a single path string)
mapfile -t invalidation_paths < <(jq -Rr 'fromjson? // . | if type == "array" then .[] else . end' <<<"$paths")

fn_run invalidate-cloudfront \
    --distribution-id $distribution_id \
    --paths "${invalidation_paths[@]}" || fn_fatal

fn_success "Invalidation request sent to CloudFront"
