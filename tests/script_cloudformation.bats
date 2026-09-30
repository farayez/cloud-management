#!/usr/bin/env bats

# create_cloudformation_stack and update_cloudformation_stack

setup() {
    load test_helper
    setup_script_sandbox

    template_file="$root_directory/cloudformation/templates/network.yaml"
    default_parameter_file="$root_directory/cloudformation/parameters/network.json"
    mkdir -p "$root_directory/cloudformation/templates" "$root_directory/cloudformation/parameters"
    echo "Resources: {}" >"$template_file"

    write_config <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" },
  "cloudformation": [
    { "name": "network", "config": { "stack_name": "network-stack", "template_filename": "network.yaml" } },
    {
      "name": "shared-parameters",
      "config": {
        "stack_name": "shared-stack",
        "template_filename": "network.yaml",
        "parameter_filename": "shared.json"
      }
    },
    { "name": "missing-template", "config": { "stack_name": "missing-stack", "template_filename": "missing.yaml" } },
    { "name": "invalid", "config": { "stack_name": "invalid-stack" } }
  ]
}
EOF

    write_config parameter_directory.config.json <<'EOF'
{
  "config": {
    "aws_profile": "test-profile",
    "aws_region": "us-east-1",
    "cf_parameter_file_directory": "resources/test/cloudformation_parameters"
  },
  "cloudformation": [
    { "name": "network", "config": { "stack_name": "network-stack", "template_filename": "network.yaml" } }
  ]
}
EOF
}

# create_cloudformation_stack

@test "create_cloudformation_stack creates the stack with the default parameter file" {
    echo "[]" >"$default_parameter_file"
    run_repo_script create_cloudformation_stack config=test.config.json resource=network
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"Using parameter file: $default_parameter_file"* ]]
    [[ "$(plain_output)" == *"SUCCESS: CLOUDFORMATION STACK CREATED"* ]]
    [ "$(mock_calls)" = "aws cloudformation create-stack --stack-name network-stack --region us-east-1 --parameters file://$default_parameter_file --capabilities CAPABILITY_NAMED_IAM --template-body file://$template_file" ]
}

@test "create_cloudformation_stack creates the stack without parameters when no parameter file exists" {
    run_repo_script create_cloudformation_stack config=test.config.json resource=network
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"No parameter file found, proceeding without parameters"* ]]
    [ "$(mock_calls)" = "aws cloudformation create-stack --stack-name network-stack --region us-east-1 --capabilities CAPABILITY_NAMED_IAM --template-body file://$template_file" ]
}

@test "create_cloudformation_stack uses parameter_filename from config" {
    echo "[]" >"$root_directory/cloudformation/parameters/shared.json"
    run_repo_script create_cloudformation_stack config=test.config.json resource=shared-parameters
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--parameters file://$root_directory/cloudformation/parameters/shared.json "* ]]
}

@test "create_cloudformation_stack uses cf_parameter_file_directory from config" {
    local parameter_file="$root_directory/resources/test/cloudformation_parameters/network.json"
    mkdir -p "$(dirname "$parameter_file")"
    echo "[]" >"$parameter_file"
    run_repo_script create_cloudformation_stack config=parameter_directory.config.json resource=network
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--parameters file://$parameter_file "* ]]
}

@test "create_cloudformation_stack fails when the template does not exist" {
    run_repo_script create_cloudformation_stack config=test.config.json resource=missing-template
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: CloudFormation template file $root_directory/cloudformation/templates/missing.yaml does not exist"* ]]
    [ -z "$(mock_calls)" ]
}

@test "create_cloudformation_stack fails when template_filename is missing" {
    run_repo_script create_cloudformation_stack config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: template_filename must be set"* ]]
    [ -z "$(mock_calls)" ]
}

@test "create_cloudformation_stack fails when the stack creation fails" {
    mock_response "aws cloudformation create-stack" 254
    run_repo_script create_cloudformation_stack config=test.config.json resource=network
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"STACK CREATION FAILED"* ]]
}

# update_cloudformation_stack

@test "update_cloudformation_stack updates the stack with the default parameter file" {
    echo "[]" >"$default_parameter_file"
    run_repo_script update_cloudformation_stack config=test.config.json resource=network
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: CLOUDFORMATION STACK UPDATED"* ]]
    [ "$(mock_calls)" = "aws cloudformation update-stack --stack-name network-stack --region us-east-1 --parameters file://$default_parameter_file --template-body file://$template_file" ]
}

@test "update_cloudformation_stack updates the stack without parameters when no parameter file exists" {
    run_repo_script update_cloudformation_stack config=test.config.json resource=network
    [ "$status" -eq 0 ]
    [ "$(mock_calls)" = "aws cloudformation update-stack --stack-name network-stack --region us-east-1 --template-body file://$template_file" ]
}

@test "update_cloudformation_stack uses parameter_filename from config" {
    echo "[]" >"$root_directory/cloudformation/parameters/shared.json"
    run_repo_script update_cloudformation_stack config=test.config.json resource=shared-parameters
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--parameters file://$root_directory/cloudformation/parameters/shared.json "* ]]
}

@test "update_cloudformation_stack uses cf_parameter_file_directory from config" {
    local parameter_file="$root_directory/resources/test/cloudformation_parameters/network.json"
    mkdir -p "$(dirname "$parameter_file")"
    echo "[]" >"$parameter_file"
    run_repo_script update_cloudformation_stack config=parameter_directory.config.json resource=network
    [ "$status" -eq 0 ]
    [[ "$(mock_calls)" == *"--parameters file://$parameter_file "* ]]
}

@test "update_cloudformation_stack fails when the template does not exist" {
    run_repo_script update_cloudformation_stack config=test.config.json resource=missing-template
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"does not exist"* ]]
    [ -z "$(mock_calls)" ]
}

@test "update_cloudformation_stack fails when template_filename is missing" {
    run_repo_script update_cloudformation_stack config=test.config.json resource=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: template_filename must be set"* ]]
}

@test "update_cloudformation_stack fails when the stack update fails" {
    mock_response "aws cloudformation update-stack" 254
    run_repo_script update_cloudformation_stack config=test.config.json resource=network
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"STACK UPDATE FAILED"* ]]
}
