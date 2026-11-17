#!/bin/bash

. ./utils/pre_execution.sh

# s3_migration is a JSON object in the shared config
migration_config="${s3_migration:-"{}"}"
fn_read_migration_setting() {
    jq -r --arg key "$1" '.[$key] // empty | if type == "array" then tojson else . end' <<<"$migration_config"
}

destination_aws_profile=$(fn_read_migration_setting destination_aws_profile)
destination_aws_region=$(fn_read_migration_setting destination_aws_region)
s3_buckets_to_copy=$(fn_read_migration_setting s3_buckets_to_copy)
destination_bucket_prefix=$(fn_read_migration_setting destination_bucket_prefix)
destination_bucket_postfix=$(fn_read_migration_setting destination_bucket_postfix)

fn_validate_variables aws_region destination_aws_profile s3_buckets_to_copy

# Bucket names are global, so the copies need a prefix and/or postfix to be told apart from the sources
if [ -z "$destination_bucket_prefix" ] && [ -z "$destination_bucket_postfix" ]; then
    fn_error "destination_bucket_prefix or destination_bucket_postfix must be set"
    fn_fatal "Config validation failed"
fi

destination_aws_region="${destination_aws_region:-$aws_region}"

# s3_buckets_to_copy is a JSON array (or a single bucket name)
mapfile -t source_buckets < <(jq -Rr 'fromjson? // . | if type == "array" then .[] else . end' <<<"$s3_buckets_to_copy" | awk 'NF')

if [ ${#source_buckets[@]} -eq 0 ]; then
    fn_halt "No S3 buckets to copy"
fi

fn_section_start "Copying ${#source_buckets[@]} S3 buckets from $aws_profile to $destination_aws_profile"

failed_buckets=()

for source_bucket in "${source_buckets[@]}"; do
    destination_bucket="${destination_bucket_prefix}${source_bucket}${destination_bucket_postfix}"

    fn_status "$source_bucket -> $destination_bucket"

    if [ ${#destination_bucket} -lt 3 ] || [ ${#destination_bucket} -gt 63 ]; then
        fn_error "Bucket name $destination_bucket must be 3 to 63 characters long"
        failed_buckets+=("$source_bucket")
        continue
    fi

    if ! fn_run s3-head-bucket --bucket "$destination_bucket" --profile "$destination_aws_profile" --region "$destination_aws_region"; then
        if ! fn_run s3-make-bucket "s3://$destination_bucket" --profile "$destination_aws_profile" --region "$destination_aws_region"; then
            fn_error "Could not create bucket $destination_bucket"
            failed_buckets+=("$source_bucket")
            continue
        fi
    fi

    # A single sync runs with the destination account credentials,
    # so the source bucket policy must allow that account to read the objects
    if ! fn_run s3-sync \
        --profile "$destination_aws_profile" \
        --source-region "$aws_region" \
        --region "$destination_aws_region" \
        "s3://$source_bucket" \
        "s3://$destination_bucket"; then
        fn_error "Could not sync $source_bucket to $destination_bucket"
        failed_buckets+=("$source_bucket")
    fi
done

if [ ${#failed_buckets[@]} -gt 0 ]; then
    fn_error "Failed buckets: ${failed_buckets[*]}"
    fn_fatal "Copied $((${#source_buckets[@]} - ${#failed_buckets[@]})) of ${#source_buckets[@]} S3 buckets"
fi

fn_success "Copied ${#source_buckets[@]} S3 buckets"
