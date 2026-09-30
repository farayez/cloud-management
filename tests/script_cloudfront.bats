#!/usr/bin/env bats

setup() {
    load test_helper
    setup_script_sandbox

    write_config <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" },
  "cloudfront": [
    { "name": "website", "config": { "distribution_id": "E123", "paths": ["/*"] } },
    { "name": "multiple", "config": { "distribution_id": "E456", "paths": ["/index.html", "/assets/*"] } },
    { "name": "invalid", "config": { "distribution_id": "E789" } }
  ]
}
EOF
}

@test "invalidate_cloudfront_dist invalidates the configured path" {
    run_repo_script invalidate_cloudfront_dist config=test.config.json resource=website
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: INVALIDATION REQUEST SENT TO CLOUDFRONT"* ]]
    [ "$(mock_calls)" = "aws cloudfront create-invalidation --distribution-id E123 --paths /*" ]
}

@test "invalidate_cloudfront_dist passes every configured path" {
    run_repo_script invalidate_cloudfront_dist config=test.config.json resource=multiple
    [ "$status" -eq 0 ]
    [ "$(mock_calls)" = "aws cloudfront create-invalidation --distribution-id E456 --paths /index.html /assets/*" ]
}

@test "invalidate_cloudfront_dist fails when the invalidation fails" {
    mock_response "aws cloudfront create-invalidation" 254
    run_repo_script invalidate_cloudfront_dist config=test.config.json resource=website
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"EXECUTION FAILED"* ]]
}

@test "invalidate_cloudfront_dist fails when paths are missing" {
    run_repo_script invalidate_cloudfront_dist config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: paths must be set"* ]]
    [ -z "$(mock_calls)" ]
}
