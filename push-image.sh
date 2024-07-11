#!/bin/bash

. ./utils/initialize.sh

cd $home_directory/repos/$codebase_directory || exit 1
git checkout $branch || exit 1
git pull || exit 1
docker build -t $image_name . || exit 1
aws ecr get-login-password --region $ecr_aws_region | docker login --username AWS --password-stdin $ecr_url || exit 1
docker tag $image_name:latest $image_url:$branch.latest || exit 1
docker push $image_url:$branch.latest
