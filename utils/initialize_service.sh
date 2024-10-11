#!/bin/bash

# Declare functions
. ./utils/declare_functions.sh

fn_define_console_colors

unset service_Name
fn_input_text "Enter service name: " service_name

if [ -z "${service_name}" ]; then
    fn_error "Service name must be provided for initializtion"
    fn_fatal
fi

if [ -d "services/$service_name" ]; then
    fn_error "Service already initiated"
    fn_fatal
fi

mkdir services/$service_name || fn_fatal
fn_status "Service directory created"

cp utils/config_template.sh services/$service_name/set_variables.sh || fn_fatal
fn_status "Config template generated"

fn_success "Service Initialized"