#!/bin/bash

. ./utils/initialize.sh

echo "home_directory: $home_directory"
echo "timestamp: $timestamp"
echo "aws_region: $aws_region"
echo "ssm_param_name: $ssm_param_name"
echo "ecr_url: $ecr_url"
echo "image_url: $image_url"
echo "image_name: $image_name"
echo "branch: $branch"
echo "ecs_cluster: $ecs_cluster"
echo "ecs_service: $ecs_service"
echo "container_name: $container_name"
echo "codebase_directory: $codebase_directory"