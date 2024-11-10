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
fn_run git -C $root_directory/repos/$repo fetch -a || fn_fatal
fn_run git -C $root_directory/repos/$repo checkout $branch || fn_fatal
fn_run git -C $root_directory/repos/$repo pull || fn_fatal

# Build, tag and push image
fn_section_start "Build and push image"
fn_run docker-build -t $image_name $root_directory/repos/$repo || fn_fatal
aws ecr get-login-password --region $aws_region | docker login --username AWS --password-stdin $ecr_url || fn_fatal
fn_run docker-tag $image_name:latest $image_url:$image_tag || fn_fatal
fn_run docker-push $image_url:$image_tag

fn_success "Image Pushed to ECR"
