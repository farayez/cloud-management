#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region

fn_section_start "Listing S3 buckets"

buckets_output=$(fn_run list-buckets --region "$aws_region") || fn_fatal

# excluded_s3_buckets is a JSON array (or a single bucket name)
mapfile -t excluded_buckets < <(jq -Rr 'fromjson? // . | if type == "array" then .[] else . end' <<<"${excluded_s3_buckets:-[]}")

mapfile -t buckets < <(awk 'NF {print $3}' <<<"$buckets_output" | grep -vxF -f <(printf '%s\n' "${excluded_buckets[@]}"))

if [ ${#buckets[@]} -eq 0 ]; then
    fn_halt "No S3 buckets found"
fi

row_format="%-50s %-12s %s\n"
printf "\n$row_format" "BUCKET NAME" "OBJECTS" "TOTAL SIZE"

for bucket in "${buckets[@]}"; do
    # Lists every object in the bucket, so large buckets take a while
    if ! summary=$(fn_run list-objects-summary "s3://$bucket" --recursive --human-readable --summarize --region "$aws_region"); then
        printf "$row_format" "$bucket" "-" "unavailable"
        continue
    fi

    objects=$(awk -F': ' '/Total Objects:/ {print $2}' <<<"$summary")
    size=$(awk -F': ' '/Total Size:/ {print $2}' <<<"$summary")
    printf "$row_format" "$bucket" "$objects" "$size"
done

fn_success "Listed ${#buckets[@]} S3 buckets"
