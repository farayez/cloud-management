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
)

declare -A script_name_to_parameter_map=(
    ["push_image"]=""
)
