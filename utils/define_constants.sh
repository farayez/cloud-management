#!/bin/bash

declare -A resource_tag_to_directory_map=(
    ["image"]="images"
    ["repo"]="repos"
    ["ssm-parameter"]="ssm_parameters"
    ["secret"]="secrets"
    ["service"]="services"
)

declare -A script_name_to_resource_tag_map=(
    ["push_image"]="image"
    ["redeploy_service"]="service"
    ["exec_container"]="service"
    ["pull_ssm_parameter"]="ssm-parameter"
    ["push_ssm_parameter"]="ssm-parameter"
)

declare -A script_name_to_parameter_map=(
    ["push_image"]=""
)

# Declare an associative array to map command keys to command strings
# Used in `fn_run` where history is logged/echoed while command runs
declare -A command_map=(
    ["update-service"]="aws ecs update-service"
    ["list-buckets"]="aws s3 ls"
    ["codedeploy-deploy"]="aws deploy create-deployment,--echo-response"
    ["ecs-list-tasks"]="aws ecs list-tasks,--echo-response"
    ["ecs-exec-command"]="aws ecs execute-command,--disable-response-log"
    ["ssm-get-parameter"]="aws ssm get-parameter"
    ["ssm-put-parameter"]="aws ssm put-parameter"
    ["docker-build"]="docker build"
    ["docker-tag"]="docker tag"
    ["docker-push"]="docker push,--disable-response-log,--echo-response"
    ["git"]="git"
)

# Define Console Color constants
CONSOLE_COLOR_BLACK='\033[0;30m'
CONSOLE_COLOR_RED='\033[0;31m'
CONSOLE_COLOR_GREEN='\033[0;32m'
CONSOLE_COLOR_BROWN='\033[0;33m'
CONSOLE_COLOR_BLUE='\033[0;34m'
CONSOLE_COLOR_PURPLE='\033[0;35m'
CONSOLE_COLOR_CYAN='\033[0;36m'
CONSOLE_COLOR_LIGHT_GRAY='\033[0;37m'
CONSOLE_COLOR_DARK_GRAY='\033[1;30m'
CONSOLE_COLOR_LIGHT_RED='\033[1;31m'
CONSOLE_COLOR_LIGHT_GREEN='\033[1;32m'
CONSOLE_COLOR_YELLOW='\033[1;33m'
CONSOLE_COLOR_LIGHT_BLUE='\033[1;34m'
CONSOLE_COLOR_LIGHT_PURPLE='\033[1;35m'
CONSOLE_COLOR_LIGHT_CYAN='\033[1;36m'
CONSOLE_COLOR_WHITE='\033[1;37m'
CONSOLE_COLOR_DEFAULT='\033[0m'
