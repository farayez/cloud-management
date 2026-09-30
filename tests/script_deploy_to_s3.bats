#!/usr/bin/env bats

setup() {
    load test_helper
    setup_script_sandbox

    repo_directory="$root_directory/repos/site-repo"
    mkdir -p "$repo_directory"

    write_config <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" },
  "s3_application": [
    {
      "name": "website",
      "config": {
        "repo": "site-repo",
        "branch": "main",
        "s3_bucket": "site-bucket",
        "build_command": "touch built.txt",
        "dist_directory": "dist"
      }
    },
    {
      "name": "with-env",
      "config": {
        "repo": "site-repo",
        "branch": "main",
        "s3_bucket": "site-bucket",
        "build_command": "cp .env.production dist-env",
        "dist_directory": "dist",
        "env_file": ".env.production",
        "env": { "API_URL": "https://api.example.com", "MODE": "production" }
      }
    },
    {
      "name": "with-default-env-file",
      "config": {
        "repo": "site-repo",
        "branch": "main",
        "s3_bucket": "site-bucket",
        "build_command": "true",
        "dist_directory": "dist",
        "env": { "MODE": "staging" }
      }
    },
    {
      "name": "no-branch",
      "config": {
        "repo": "site-repo",
        "s3_bucket": "site-bucket",
        "build_command": "true",
        "dist_directory": "dist"
      }
    },
    {
      "name": "failing-build",
      "config": {
        "repo": "site-repo",
        "branch": "main",
        "s3_bucket": "site-bucket",
        "build_command": "exit 3",
        "dist_directory": "dist"
      }
    },
    { "name": "invalid", "config": { "repo": "site-repo", "s3_bucket": "site-bucket" } }
  ]
}
EOF
}

@test "deploy_to_s3 updates the repo, builds in the repo directory and syncs the dist directory" {
    run_repo_script deploy_to_s3 config=test.config.json resource=website
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: APPLICATION UPLOADED TO S3 SUCCESSFULLY"* ]]
    [ -f "$repo_directory/built.txt" ]

    local expected
    expected="git -C $repo_directory fetch -a
git -C $repo_directory checkout main
git -C $repo_directory pull
aws s3 sync --region us-east-1 $repo_directory/dist s3://site-bucket/"
    [ "$(mock_calls)" = "$expected" ]
}

@test "deploy_to_s3 writes env to env_file before building" {
    run_repo_script deploy_to_s3 config=test.config.json resource=with-env
    [ "$status" -eq 0 ]
    [ "$(<"$repo_directory/.env.production")" = $'API_URL=https://api.example.com\nMODE=production' ]
    cmp "$repo_directory/.env.production" "$repo_directory/dist-env"
}

@test "deploy_to_s3 writes env to .env by default" {
    run_repo_script deploy_to_s3 config=test.config.json resource=with-default-env-file
    [ "$status" -eq 0 ]
    [ "$(<"$repo_directory/.env")" = "MODE=staging" ]
}

@test "deploy_to_s3 does not write an env file when env is not configured" {
    run_repo_script deploy_to_s3 config=test.config.json resource=website
    [ "$status" -eq 0 ]
    [ ! -e "$repo_directory/.env" ]
}

@test "deploy_to_s3 asks for the branch when it is not configured" {
    run_repo_script deploy_to_s3 config=test.config.json resource=no-branch <<<"develop"
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Enter branch: "* ]]
    [[ "$(mock_calls)" == *"git -C $repo_directory checkout develop"* ]]
}

@test "deploy_to_s3 fails when the entered branch is empty" {
    run_repo_script deploy_to_s3 config=test.config.json resource=no-branch <<<""
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: branch must be set"* ]]
    [ -z "$(mock_calls)" ]
}

@test "deploy_to_s3 stops when the repo update fails" {
    mock_response git 1
    run_repo_script deploy_to_s3 config=test.config.json resource=website
    [ "$status" -eq 1 ]
    [ ! -e "$repo_directory/built.txt" ]
    [[ "$(mock_calls)" != *"aws s3 sync"* ]]
}

@test "deploy_to_s3 does not sync when the build fails" {
    run_repo_script deploy_to_s3 config=test.config.json resource=failing-build
    [ "$status" -eq 1 ]
    [[ "$(mock_calls)" != *"aws s3 sync"* ]]
}

@test "deploy_to_s3 fails when the sync fails" {
    mock_response "aws s3 sync" 1
    run_repo_script deploy_to_s3 config=test.config.json resource=website
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" != *"SUCCESS"* ]]
}

@test "deploy_to_s3 fails when required config is missing" {
    run_repo_script deploy_to_s3 config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: build_command must be set"* ]]
    [[ "$(plain_output)" == *"ERROR: dist_directory must be set"* ]]
    [ -z "$(mock_calls)" ]
}
