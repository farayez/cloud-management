#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region ssm_param_name

parameter_directory=$root_directory/${ssm_parameters_directory:-parameters}
parameter_file=$parameter_directory/$resource_name.sync

result=$(fn_run ssm-get-parameter \
    --region $aws_region \
    --name $ssm_param_name \
    --with-decryption \
    --output text \
    --query 'Parameter.Value') || fn_fatal

mkdir -p "$parameter_directory" || fn_fatal
echo "$result" >"$parameter_file"

fn_success "Parameter pulled from SSM Parameter Store"
