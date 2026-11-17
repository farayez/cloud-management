#!/usr/bin/env bats

# Writes the base configuration after applying a jq filter, e.g. '.config.excluded_s3_buckets = ["bucket-a"]'
write_delete_config() {
    jq "${1:-.}" <<'EOF' | write_config
{
  "config": {
    "aws_profile": "test-profile",
    "aws_region": "us-east-1",
    "s3_buckets_to_delete": ["bucket-a", "bucket-b"]
  }
}
EOF
}

setup() {
    load test_helper
    setup_script_sandbox
    write_delete_config

    mock_response "aws s3api head-bucket" 0
    mock_response "aws s3api list-object-versions" 0
    mock_response "aws s3api delete-objects" 0
    mock_response "aws s3 rb" 0
}

@test "delete_s3_buckets deletes every bucket after confirmation" {
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: DELETED 2 S3 BUCKETS"* ]]
    mock_calls | grep -Fxq "aws s3 rb s3://bucket-a --region us-east-1"
    mock_calls | grep -Fxq "aws s3 rb s3://bucket-b --region us-east-1"
}

@test "delete_s3_buckets deletes without removing objects from an empty bucket" {
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" != *"aws s3api delete-objects"* ]]
}

@test "delete_s3_buckets deletes nothing unless 'delete' is typed" {
    run bash -c "cd '$root_directory' && echo no | bash '$REPO_ROOT/scripts/delete_s3_buckets.sh' config=test.config.json"
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"DELETION CANCELLED"* ]]
    [[ "$(mock_calls)" != *"aws s3 rb"* ]]
}

@test "delete_s3_buckets deletes the buckets when 'delete' is typed" {
    run bash -c "cd '$root_directory' && echo delete | bash '$REPO_ROOT/scripts/delete_s3_buckets.sh' config=test.config.json"
    [ "$status" -eq 0 ]
    [ "$(mock_calls | grep -c "aws s3 rb")" -eq 2 ]
}

@test "delete_s3_buckets never deletes excluded buckets and accepts a single bucket name" {
    write_delete_config '.config.s3_buckets_to_delete = "bucket-a" | .config.excluded_s3_buckets = ["bucket-a"]'
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"NO S3 BUCKETS TO DELETE"* ]]
    [ ! -s "$mock_log" ]
}

@test "delete_s3_buckets requires the bucket list" {
    write_delete_config 'del(.config.s3_buckets_to_delete)'
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"s3_buckets_to_delete must be set"* ]]
}

@test "delete_s3_buckets halts when the bucket list is empty" {
    write_delete_config '.config.s3_buckets_to_delete = []'
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"NO S3 BUCKETS TO DELETE"* ]]
    [ ! -s "$mock_log" ]
}

@test "delete_s3_buckets skips a missing bucket, keeps going and fails at the end" {
    mock_response "aws s3api head-bucket" 254
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"Failed buckets: bucket-a bucket-b"* ]]
    [[ "$(plain_output)" == *"DELETED 0 OF 2 S3 BUCKETS"* ]]
    [[ "$(mock_calls)" != *"aws s3 rb"* ]]
}

@test "delete_s3_buckets does not delete a bucket that could not be emptied" {
    mock_response "aws s3api list-object-versions" 0 '{"Versions":[{"Key":"a.txt","VersionId":"v1"}]}'
    mock_response "aws s3api delete-objects" 0 '{"Errors":[{"Key":"a.txt","Code":"AccessDenied"}]}'
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 1 ]
    mock_calls | grep -Eq "^aws s3api delete-objects --bucket bucket-a --delete file://.+ --region us-east-1$"
    [[ "$(plain_output)" == *"Could not empty bucket bucket-a"* ]]
    [[ "$(mock_calls)" != *"aws s3 rb"* ]]
}

@test "delete_s3_buckets fails at the end when a bucket cannot be deleted" {
    mock_response "aws s3 rb" 1
    run_repo_script delete_s3_buckets config=test.config.json confirm=yes
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"Could not delete bucket bucket-a"* ]]
    [ "$(mock_calls | grep -c "aws s3 rb")" -eq 2 ]
}
