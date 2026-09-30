#!/usr/bin/env bats

# pull_ssm_parameter and push_ssm_parameter

setup() {
    load test_helper
    setup_script_sandbox

    parameter_file="$root_directory/resources/test/ssm_parameters/api-env.sync"

    write_config <<'EOF'
{
  "config": {
    "aws_profile": "test-profile",
    "aws_region": "us-east-1",
    "ssm_parameters_directory": "resources/test/ssm_parameters"
  },
  "ssm_parameter": [
    { "name": "api-env", "config": { "ssm_param_name": "/prod/api/env" } },
    { "name": "invalid", "config": {} }
  ]
}
EOF

    write_config default_directory.config.json <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" },
  "ssm_parameter": [
    { "name": "api-env", "config": { "ssm_param_name": "/prod/api/env" } }
  ]
}
EOF
}

# pull_ssm_parameter

@test "pull_ssm_parameter writes the decrypted value to the parameter file" {
    mock_response "aws ssm get-parameter" 0 $'KEY=value\nOTHER=2'
    run_repo_script pull_ssm_parameter config=test.config.json resource=api-env
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: PARAMETER PULLED FROM SSM PARAMETER STORE"* ]]
    [ "$(mock_calls)" = "aws ssm get-parameter --region us-east-1 --name /prod/api/env --with-decryption --output text --query Parameter.Value" ]
    [ "$(<"$parameter_file")" = $'KEY=value\nOTHER=2' ]
}

@test "pull_ssm_parameter overwrites an existing parameter file" {
    mkdir -p "$(dirname "$parameter_file")"
    echo "OLD=1" >"$parameter_file"
    mock_response "aws ssm get-parameter" 0 "NEW=1"
    run_repo_script pull_ssm_parameter config=test.config.json resource=api-env
    [ "$status" -eq 0 ]
    [ "$(<"$parameter_file")" = "NEW=1" ]
}

@test "pull_ssm_parameter defaults to the parameters directory" {
    mock_response "aws ssm get-parameter" 0 "KEY=value"
    run_repo_script pull_ssm_parameter config=default_directory.config.json resource=api-env
    [ "$status" -eq 0 ]
    [ "$(<"$root_directory/parameters/api-env.sync")" = "KEY=value" ]
}

@test "pull_ssm_parameter does not write the parameter file when the request fails" {
    mock_response "aws ssm get-parameter" 254 "ParameterNotFound"
    run_repo_script pull_ssm_parameter config=test.config.json resource=api-env
    [ "$status" -eq 1 ]
    [ ! -e "$parameter_file" ]
}

@test "pull_ssm_parameter fails when ssm_param_name is missing" {
    run_repo_script pull_ssm_parameter config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: ssm_param_name must be set"* ]]
    [ -z "$(mock_calls)" ]
}

# push_ssm_parameter

@test "push_ssm_parameter uploads the parameter file as a SecureString" {
    mkdir -p "$(dirname "$parameter_file")"
    echo "KEY=value" >"$parameter_file"
    run_repo_script push_ssm_parameter config=test.config.json resource=api-env
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: PARAMETER PUSHED TO SSM PARAMETER STORE"* ]]
    [ "$(mock_calls)" = "aws ssm put-parameter --region us-east-1 --name /prod/api/env --type SecureString --overwrite --value file://$parameter_file" ]
}

@test "push_ssm_parameter defaults to the parameters directory" {
    mkdir -p "$root_directory/parameters"
    echo "KEY=value" >"$root_directory/parameters/api-env.sync"
    run_repo_script push_ssm_parameter config=default_directory.config.json resource=api-env
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--value file://$root_directory/parameters/api-env.sync" ]]
}

@test "push_ssm_parameter fails when the parameter file does not exist" {
    run_repo_script push_ssm_parameter config=test.config.json resource=api-env
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: Parameter file $parameter_file does not exist"* ]]
    [ -z "$(mock_calls)" ]
}

@test "push_ssm_parameter fails when the request fails" {
    mkdir -p "$(dirname "$parameter_file")"
    echo "KEY=value" >"$parameter_file"
    mock_response "aws ssm put-parameter" 254
    run_repo_script push_ssm_parameter config=test.config.json resource=api-env
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" != *"SUCCESS"* ]]
}

@test "push_ssm_parameter fails when ssm_param_name is missing" {
    run_repo_script push_ssm_parameter config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: ssm_param_name must be set"* ]]
}
