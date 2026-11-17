#!/usr/bin/env bats

setup() {
    load test_helper
    setup_script_sandbox

    write_config <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" }
}
EOF

    mock_response "aws s3 ls" 0 $'2024-01-01 10:00:00 bucket-a\n2024-01-02 11:00:00 bucket-b'
    mock_response "aws s3 ls s3://bucket-a" 0 $'Total Objects: 3\n   Total Size: 1.5 KiB'
    mock_response "aws s3 ls s3://bucket-b" 0 $'Total Objects: 0\n   Total Size: 0 Bytes'
}

@test "list_s3_buckets lists every bucket with its object count and size" {
    run_repo_script list_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    plain_output | grep -Eq '^bucket-a +3 +1\.5 KiB$'
    plain_output | grep -Eq '^bucket-b +0 +0 Bytes$'
    [[ "$(plain_output)" == *"SUCCESS: LISTED 2 S3 BUCKETS"* ]]
    [ "$(mock_calls | head -n 1)" = "aws s3 ls --region us-east-1" ]
}

@test "list_s3_buckets skips the buckets listed in excluded_s3_buckets" {
    run_repo_script list_s3_buckets config=test.config.json 'excluded_s3_buckets=["bucket-a"]'
    [ "$status" -eq 0 ]
    plain_output | grep -Eq '^bucket-b +0 +0 Bytes$'
    [[ "$(plain_output)" == *"SUCCESS: LISTED 1 S3 BUCKETS"* ]]
    [[ "$(mock_calls)" != *"s3://bucket-a"* ]]
}

@test "list_s3_buckets accepts a single excluded bucket name" {
    run_repo_script list_s3_buckets config=test.config.json excluded_s3_buckets=bucket-b
    [ "$status" -eq 0 ]
    plain_output | grep -Eq '^bucket-a +3 +1\.5 KiB$'
    [[ "$(mock_calls)" != *"s3://bucket-b"* ]]
}

@test "list_s3_buckets halts when every bucket is excluded" {
    run_repo_script list_s3_buckets config=test.config.json 'excluded_s3_buckets=["bucket-a","bucket-b"]'
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"NO S3 BUCKETS FOUND"* ]]
}

@test "list_s3_buckets marks a bucket that cannot be read" {
    mock_response "aws s3 ls s3://bucket-b" 1 "AccessDenied"
    run_repo_script list_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    plain_output | grep -Eq '^bucket-a +3 +1\.5 KiB$'
    plain_output | grep -Eq '^bucket-b +- +unavailable$'
}

@test "list_s3_buckets halts when there are no buckets" {
    mock_response "aws s3 ls" 0 ""
    run_repo_script list_s3_buckets config=test.config.json
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"NO S3 BUCKETS FOUND"* ]]
    [ "$(mock_calls | wc -l)" -eq 1 ]
}

@test "list_s3_buckets fails when listing buckets fails" {
    mock_response "aws s3 ls" 255
    run_repo_script list_s3_buckets config=test.config.json
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"EXECUTION FAILED"* ]]
}
