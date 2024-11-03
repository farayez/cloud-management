#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region ssm_param_name

result=$(fn_run ssm-get-parameter \
    --region $aws_region \
    --name $ssm_param_name \
    --with-decryption \
    --output text \
    --query 'Parameter.Value') || fn_fatal

mkdir -p parameters || fn_fatal
echo "$result" >parameters/$resource_name.pulled

fn_success "Parameter pulled from SSM Parameter Store"
