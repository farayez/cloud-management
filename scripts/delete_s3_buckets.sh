#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region s3_buckets_to_delete

# s3_buckets_to_delete and excluded_s3_buckets are JSON arrays (or a single bucket name)
fn_read_bucket_list() {
    jq -Rr 'fromjson? // . | if type == "array" then .[] else . end' <<<"$1" | awk 'NF'
}

mapfile -t requested_buckets < <(fn_read_bucket_list "$s3_buckets_to_delete")
mapfile -t excluded_buckets < <(fn_read_bucket_list "${excluded_s3_buckets:-[]}")

buckets=()
for bucket in "${requested_buckets[@]}"; do
    if printf '%s\n' "${excluded_buckets[@]}" | grep -qxF -- "$bucket"; then
        fn_warning "Skipping $bucket, it is listed in excluded_s3_buckets"
        continue
    fi
    buckets+=("$bucket")
done

if [ ${#buckets[@]} -eq 0 ]; then
    fn_halt "No S3 buckets to delete"
fi

fn_section_start "Deleting ${#buckets[@]} S3 buckets from $aws_profile"
printf '  %s\n' "${buckets[@]}"

# Deleting a bucket permanently destroys every object, version and delete marker in it
if [ "$confirm" != "yes" ]; then
    fn_input_text "Type 'delete' to permanently delete the buckets above and all of their contents: " confirmation
    [ "$confirmation" = "delete" ] || fn_halt "Deletion cancelled"
fi

# Removes every object version and delete marker, in batches of 1000 (the delete-objects limit)
fn_empty_bucket() {
    local bucket=$1 versions batch delete_file result
    delete_file=$(mktemp) || return 1

    while true; do
        versions=$(fn_run s3-list-object-versions --bucket "$bucket" --max-items 1000 --output json --region "$aws_region") || {
            rm -f "$delete_file"
            return 1
        }

        # An empty bucket returns no versions
        [ -z "$versions" ] && break

        batch=$(jq -c '{Objects: ([(.Versions // [])[], (.DeleteMarkers // [])[]] | map({Key, VersionId}) | .[:1000]), Quiet: true}' <<<"$versions") || {
            rm -f "$delete_file"
            return 1
        }
        [ "$(jq '.Objects | length' <<<"$batch")" -gt 0 ] || break

        echo "$batch" >"$delete_file"
        result=$(fn_run s3-delete-objects --bucket "$bucket" --delete "file://$delete_file" --region "$aws_region") || {
            rm -f "$delete_file"
            return 1
        }
        # Quiet mode only reports the objects that could not be deleted
        if [ -n "$result" ] && [ "$(jq '(.Errors // []) | length' <<<"$result")" -gt 0 ]; then
            rm -f "$delete_file"
            return 1
        fi
    done

    rm -f "$delete_file"
}

failed_buckets=()

for bucket in "${buckets[@]}"; do
    fn_status "$bucket"

    if ! fn_run s3-head-bucket --bucket "$bucket" --region "$aws_region"; then
        fn_error "Bucket $bucket does not exist or is not accessible"
        failed_buckets+=("$bucket")
        continue
    fi

    if ! fn_empty_bucket "$bucket"; then
        fn_error "Could not empty bucket $bucket"
        failed_buckets+=("$bucket")
        continue
    fi

    if ! fn_run s3-remove-bucket "s3://$bucket" --region "$aws_region"; then
        fn_error "Could not delete bucket $bucket"
        failed_buckets+=("$bucket")
    fi
done

if [ ${#failed_buckets[@]} -gt 0 ]; then
    fn_error "Failed buckets: ${failed_buckets[*]}"
    fn_fatal "Deleted $((${#buckets[@]} - ${#failed_buckets[@]})) of ${#buckets[@]} S3 buckets"
fi

fn_success "Deleted ${#buckets[@]} S3 buckets"
