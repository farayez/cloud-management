#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables root_directory repo branch aws_region ecr_url image_name

# Prepare image url
if [ ! -v image_url ]; then
    image_url=$(echo "$ecr_url/$image_name")
fi

# Prepare tag for image
if [ ! -v image_tag ]; then
    branch_suffix=${branch##*/}
    image_tag=$(echo "${branch_suffix:+$branch_suffix.}latest")
fi

fn_validate_variables image_url image_tag

# Update codebase
fn_section_start "Repo update"
cd $root_directory/repos/$repo || exit 1
git fetch -a || exit 1
git checkout $branch || exit 1
git pull || exit 1

# Build, tag and push image
fn_section_start "Build and push image"
docker build -t $image_name . || exit 1
aws ecr get-login-password --region $aws_region | docker login --username AWS --password-stdin $ecr_url || exit 1
docker tag $image_name:latest $image_url:$image_tag || exit 1
docker push $image_url:$image_tag

fn_success "Image Pushed to ECR"
