#!/bin/bash

. ./utils/initialize.sh

# Mask
sed '{:q;N;s/\n/|EOL|/g;t q}' .env > ./tmp/.env.masked-to-ssm

aws ssm put-parameter \
    --region $aws_region \
    --name $ssm_param_name \
    --type SecureString \
    --overwrite \
    --value file://tmp/.env.masked-to-ssm

# Record history
cp .env history/push_env_$timestamp.env
