#!/bin/bash

# General AWS Settings
aws_region="me-central-1"
aws_profile="default"

# SSM Parameter Store
ssm_param_name="/test-application/staging/env"

# ECR
ecr_aws_region="me-central-1"
ecr_url="000000000000.dkr.ecr.me-central-1.amazonaws.com"
image_url="000000000000.dkr.ecr.me-central-1.amazonaws.com/test-application"
image_name="test-application"
branch="main"

# ECS
ecs_cluster=staging-serverless
ecs_service=test-application-staging-01
container_name=$image_name
task_definition=test-task-definition

# Codebase
codebase_directory="test-application-repo"
