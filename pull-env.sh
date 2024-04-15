#!/bin/bash

. ./utils/initialize.sh

aws ssm get-parameter \
    --region $aws_region \
    --name $ssm_param_name \
    --with-decryption \
    --output text \
    --query 'Parameter.Value' > ./tmp/.env.masked-from-ssm || exit 1

# Unmusk
sed 's/|EOL|/\n/g' ./tmp/.env.masked-from-ssm > .env

# Record history
cp .env history/pull_env_$timestamp.env
