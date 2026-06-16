#!/bin/bash

. ./utils/pre_execution.sh

fn_validate_variables resource_name root_directory aws_region stack_name template_filename

# Prepare cloudformation template file
template_file=$root_directory/cloudformation/templates/$template_filename

# Ensure cloudformation template file exists
if [ ! -f "$template_file" ]; then
    fn_error "CloudFormation template file $template_file does not exist"
    fn_fatal
fi

fn_info "Using cloudformation template file: $template_file"

# Prepare parameter file directory
if [ -z "$cf_parameter_file_directory" ]; then
    parameter_file_full_directory=$root_directory/cloudformation/parameters
else
    parameter_file_full_directory=$root_directory/$cf_parameter_file_directory
fi

# Prepare parameter file
if [ -z "$parameter_filename" ]; then
    parameter_file=$parameter_file_full_directory/$resource_name.json
else
    parameter_file=$parameter_file_full_directory/$parameter_filename
fi

# Check if parameter file exists and prepare parameters option
parameters_option=""
if [ -f "$parameter_file" ]; then
    fn_info "Using parameter file: $parameter_file"
    parameters_option="--parameters file://$parameter_file"
else
    fn_info "No parameter file found, proceeding without parameters"
fi

fn_run update-cf-stack \
    --stack-name $stack_name \
    --region $aws_region \
    $parameters_option \
    --template-body file://$template_file || fn_fatal "Stack update failed"

fn_success "CloudFormation Stack Updated"
