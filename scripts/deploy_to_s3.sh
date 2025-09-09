#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables root_directory repo aws_region s3_bucket build_command dist_directory

fn_section_start "Deploying Application $repo"

# Prepare branch name when not provided in config
if [ ! -v branch ]; then
    if [ -v branch_options ]; then
        fn_choose_from_menu "Select branch: " branch $branch_options
    else
        fn_input_text "Enter branch: " branch
    fi
fi

fn_validate_variables branch

repo_directory=$root_directory/repos/$repo

# Update codebase
fn_section_start "Repo update"
fn_run git -C $repo_directory fetch -a || fn_fatal
fn_run git -C $repo_directory checkout $branch || fn_fatal
fn_run git -C $repo_directory pull || fn_fatal

echo $repo_directory

# Build Application
fn_section_start "Build Application"
cd $root_directory/repos/$repo || fn_fatal
fn_run bash "$build_command" || fn_fatal

fn_section_start "Sync with S3"
fn_run s3-sync \
    --region "$aws_region" \
    "$repo_directory/$dist_directory" \
    "s3://$s3_bucket/" || fn_fatal

fn_success "Application Uploaded to S3 Successfully"
