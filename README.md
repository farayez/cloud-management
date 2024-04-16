# cloud-management
A compilation of scripts to deploy, configure, and manage services on the cloud.

# Requirements
- [Install the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)


# Disclaimers
- Project under development
- Only works with AWS
- The scripts are tested only using Bash shell

# Usage

## Setup
- Make a copy of `services/example` directory and name it accordingly.
    - Example: `myApp-backend-staging`
- Populate variables inside `services/myApp-backend-staging/set_variables.sh` based on your needs.
- Make a copy of `.aws/config.example` and `.aws/credentials.example`. Name the new files `config` and `credentials` respectively.
- Populate newly created `.aws/config` and `.aws/credentials` files with configurations from AWS. Follow the format from [Authenticate with short-term credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-short-term.html)

## Build and push application image
- Clone application repository into `repos/`
    - Example: `repos/myApp`
- Docker must be running
- Command to build docker image and push to AWS ECR
    ```bash
    ./push-image.sh myApp-backend-staging
    ```

#### Required variables
- aws_region
- codebase_directory
- branch
- image_name
- image_url
- ecr_url

## Start / Stop (or redeploy) ECS Service
- Command to start / redeploy:
    ```bash
    ./start-service.sh myApp-backend-staging
    ```
- Command to stop service:
    ```bash
    ./stop-service.sh myApp-backend-staging
    ```

#### Required variables
- aws_region
- ecs_cluster
- ecs_service

## Exec into a running container on ECS
- Command to exec into a container:
    ```bash
    ./exec-container.sh myApp-backend-staging
    ```

#### Required variables
- aws_region
- ecs_cluster
- container_name

## Environment variable management
Environment variables can be passed in bulk to the application using `AWS SSM Parameter Store`. Since Parameter Store does not support new line character, the full content of the .env file cannot be passed in directly. Instead, a masking and unmasking phase is applied to push and pull the .env file. 
> Note: **To let the application utilize it, .env file needs to be unmasked inside the docker entrypoint as well.**

> Note: **.env file cannot contain the string *|EOL|* anywhere inside its content**

- Populate required variables
- Copy the .env file inside services folder (`services/myApp-backend-staging/.env`)
- Command to push local .env file to Parameter Store
    ```bash
    ./push-env.sh myApp-backend-staging
    ```
- Command to pull .env file from Parameter Store
    ```bash
    ./pull-env.sh myApp-backend-staging
    ```

#### Required variables
    - aws_region
    - ssm_param_name

## History
Significant responses and file changes are recorded in `services/myApp-backend-staging/history` directory.

- Response from `aws ecs update-service` command
- .env file history during push and pull

## Tmp
The `services/myApp-backend-staging/history` can be removed at any point.
