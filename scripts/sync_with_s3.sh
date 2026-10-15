#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables local_directory s3_bucket remote_directory aws_region

fn_section_start "Syncing with bucket: $s3_bucket"

fn_run s3-sync \
    --region "$aws_region" \
    "$root_directory/${resource_tag_to_directory_map[$resource_tag]}/$local_directory" \
    "s3://$s3_bucket$remote_directory" || fn_fatal

fn_success "Directory Synced with S3 Bucket Successfully"
