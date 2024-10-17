#!/bin/bash

. ./utils/initialize.sh

rm -r history/* || fn_fatal

fn_success "All histories removed from $service_name"
