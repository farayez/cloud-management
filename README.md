# cloud-management

A compilation of scripts to deploy, configure, and manage services on the cloud.

# Requirements

- [Install the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- https://marketplace.visualstudio.com/items?itemName=rioj7.command-variable
- https://marketplace.visualstudio.com/items?itemName=seunlanlege.action-buttons

# Disclaimers

- Project currently under development.
- Supports AWS exclusively.
- Scripts have been tested exclusively using the Bash shell.

# Usage

## Setup

- Initialize a resource by running command `npm run resource:init`
  1. Select the resource to initialize.
  2. Input the resource name. Rest of the document will refer to this name using `<resource-name>`
- A config file will be generated inside the resource directory. Populate the config file with appropriate values.
- Make a copy of `.aws/config.example` and `.aws/credentials.example`. Name the new files `config` and `credentials` respectively.
- Populate newly created `.aws/config` and `.aws/credentials` files with configurations from AWS. Follow the format from [Authenticate with short-term credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-short-term.html)
- The AWS Profile configured in `.aws/config` and `.aws/credentials` files can be used in 2 ways:
  - By passing argument `aws_profile=<custom-profile>` with the command.
  - By adding `aws_profile="<custom-profile>"` in resource specific configuration file.

## Build and push application image

> ### Required resource: _image_

- Clone application repository into `repos/`
  - Example: `repos/myApp`
- Docker must be running
- Command to build docker image and push to AWS ECR
  ```bash
  npm run image:push <resource-name>
  ```
- Remote repository URL is `<image_url>:<image_tag>`. here `<image_tag>` is formed in following steps

  1. All `/`s in branch name are replaced by `.`
  2. `.latest` is appended to the end

  Example: tag for branch `feature/some-functionality` will be `feature.some-functionality.latest`

## Start / Stop / Redeploy ECS Service

> ### Required resource: _service_

- Command to start with a desired task count of 1:
  ```bash
  npm run ecs:start_service <resource-name>
  ```
- Command to stop service:
  ```bash
  npm run ecs:stop_service <resource-name>
  ```
- Command to redeploy service:
  ```bash
  npm run ecs:redeploy_service <resource-name>
  ```

## Exec into a running container on ECS

> ### Required resource: _service_

- Command to exec into a container:
  ```bash
  npm run ecs:exec_container <resource-name>
  ```

## Environment variable management

> ### Required resource: _ssm-parameter_

Environment variables can be passed in bulk to the application using `AWS SSM Parameter Store`.

- Command to pull .env file from Parameter Store

  ```bash
  npm run ssm_parameter:pull <resource-name>
  ```

  This command will get the parameter from SSM Parameter Store and dump its content in `ssm_parameters/parameters/<resource-name>.pulled`.

- To push a parameter to SSM Parameter Store, Follow the steps:

  - Create a file `ssm_parameters/parameters/<resource-name>.pushable`
  - run `npm run ssm_parameter:push <resource-name>`

  When this command is run, all the contents of file `.pushable` will be put into the SSM Parameter.

## Test

`test.sh` can be called to run any custom command specified in its 2nd argument. This can be used to test the AWS integration. Example:

```bash
./test.sh example-resource "aws sts get-caller-identity"
./test.sh example-resource "aws configure list"
```

## History

Significant responses and file changes are recorded in `<resource-directory>/history` directory.

- Response from `aws ecs update-service` command
- .env file history during push and pull

## Tmp Directory

The `services/<service_name>/history` can be removed at any point.

## Command arguments

Any variable defined in `<resource-name>.config.sh` can be overwritten by passing `<variable_name>=<new_value>` as a command argument. Example:

```bash
./view-variables.sh example-resource aws_region=us-east-1 ssm_param_name="/new/parameter"
```

# TODOs

- Monitor service deployment after command is given.
  - https://stackoverflow.com/questions/54131672/aws-ecs-monitoring-the-status-of-a-service-update
- Upload parameters to Secret Manager
