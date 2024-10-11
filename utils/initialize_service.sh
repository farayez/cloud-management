#!/bin/bash

# Declare functions
. ./utils/declare_functions.sh

define_console_colors

unset service_Name
input_text "Enter service name: " service_name

if [ -z "${service_name}" ]; then
    error "Service name must be provided for initializtion"
    fatal
fi

if [ -d "services/$service_name" ]; then
    error "Service already initiated"
    fatal
fi

mkdir services/$service_name || fatal
section_end "Service directory created"

cp utils/config_template.sh services/$service_name/set_variables.sh || fatal
section_end "Config template generated"

success "Service Initialized"