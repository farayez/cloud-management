#!/usr/bin/env bats

# Writes the base configuration after applying a jq filter, e.g. 'del(.config.s3_migration.destination_bucket_prefix)'
write_copy_config() {
    jq "${1:-.}" <<'EOF' | write_config
{
  "config": {
    "aws_profile": "source-profile",
    "aws_region": "us-east-1",
    "s3_migration": {
      "destination_aws_profile": "destination-profile",
      "destination_aws_region": "eu-west-1",
      "s3_buckets_to_copy": ["bucket-a", "bucket-b"],
      "destination_bucket_prefix": "new-",
      "destination_bucket_postfix": "-copy"
    }
  }
}
EOF
}

setup() {
    load test_helper
    setup_script_sandbox
    write_copy_config

    mock_response "aws s3api head-bucket" 0
    mock_response "aws s3 mb" 0
    mock_response "aws s3 sync" 0
}

@test "copy_s3_buckets syncs every bucket to its prefixed and postfixed name" {
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: COPIED 2 S3 BUCKETS"* ]]
    mock_calls | grep -Fxq "aws s3 sync --profile destination-profile --source-region us-east-1 --region eu-west-1 s3://bucket-a s3://new-bucket-a-copy"
    mock_calls | grep -Fxq "aws s3 sync --profile destination-profile --source-region us-east-1 --region eu-west-1 s3://bucket-b s3://new-bucket-b-copy"
}

@test "copy_s3_buckets creates a destination bucket that does not exist" {
    mock_response "aws s3api head-bucket" 254
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    mock_calls | grep -Fxq "aws s3 mb s3://new-bucket-a-copy --profile destination-profile --region eu-west-1"
}

@test "copy_s3_buckets does not create a destination bucket that already exists" {
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" != *"aws s3 mb"* ]]
}

@test "copy_s3_buckets accepts a prefix only, a single bucket name and defaults the destination region" {
    write_copy_config 'del(.config.s3_migration.destination_bucket_postfix, .config.s3_migration.destination_aws_region) | .config.s3_migration.s3_buckets_to_copy = "bucket-a"'
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    mock_calls | grep -Fxq "aws s3 sync --profile destination-profile --source-region us-east-1 --region us-east-1 s3://bucket-a s3://new-bucket-a"
    [[ "$(mock_calls)" != *"bucket-b"* ]]
}

@test "copy_s3_buckets requires a prefix or a postfix" {
    write_copy_config 'del(.config.s3_migration.destination_bucket_prefix, .config.s3_migration.destination_bucket_postfix)'
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"destination_bucket_prefix or destination_bucket_postfix must be set"* ]]
    [ ! -s "$mock_log" ]
}

@test "copy_s3_buckets requires the buckets and the destination profile" {
    write_copy_config 'del(.config.s3_migration.destination_aws_profile, .config.s3_migration.s3_buckets_to_copy)'
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"destination_aws_profile must be set"* ]]
    [[ "$(plain_output)" == *"s3_buckets_to_copy must be set"* ]]
}

@test "copy_s3_buckets halts when the bucket list is empty" {
    write_copy_config '.config.s3_migration.s3_buckets_to_copy = []'
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"NO S3 BUCKETS TO COPY"* ]]
    [ ! -s "$mock_log" ]
}

@test "copy_s3_buckets keeps going and fails at the end when a bucket cannot be synced" {
    mock_response "aws s3 sync" 1
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"Failed buckets: bucket-a bucket-b"* ]]
    [[ "$(plain_output)" == *"COPIED 0 OF 2 S3 BUCKETS"* ]]
    [ "$(mock_calls | grep -c "aws s3 sync")" -eq 2 ]
}

@test "copy_s3_buckets skips a bucket whose destination cannot be created" {
    mock_response "aws s3api head-bucket" 254
    mock_response "aws s3 mb" 1
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(mock_calls)" != *"aws s3 sync"* ]]
}

@test "copy_s3_buckets rejects a destination name that is too long" {
    write_copy_config ".config.s3_migration.destination_bucket_prefix = \"$(printf 'x%.0s' {1..60})\""
    run_repo_script copy_s3_buckets config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"must be 3 to 63 characters long"* ]]
    [[ "$(mock_calls)" != *"aws s3 sync"* ]]
}
