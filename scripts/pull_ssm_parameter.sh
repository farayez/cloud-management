#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region ssm_param_name

parameter_file=$root_directory/parameters/$resource_name.sync

result=$(fn_run ssm-get-parameter \
    --region $aws_region \
    --name $ssm_param_name \
    --with-decryption \
    --output text \
    --query 'Parameter.Value') || fn_fatal

mkdir -p $root_directory/parameters || fn_fatal
echo "$result" >$root_directory/parameters/$resource_name.sync

fn_success "Parameter pulled from SSM Parameter Store"
