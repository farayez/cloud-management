#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables aws_region ssm_param_name

parameter_file=parameters/$resource_name.sync

if [ ! -f "$parameter_file" ]; then
    fn_error "Parameter file $parameter_file does not exist"
    fn_fatal
fi

fn_run ssm-put-parameter \
    --region $aws_region \
    --name $ssm_param_name \
    --type SecureString \
    --overwrite \
    --value file://$parameter_file || fn_fatal

fn_success "Parameter pushed to SSM Parameter Store"
