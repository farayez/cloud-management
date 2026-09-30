# cloud-management

Bash scripts to deploy, configure, and manage AWS resources from a single JSON configuration.

> Under development. AWS only. Tested with Bash only.

## Requirements

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), `jq`, `git`, Docker (for images)
- VS Code extensions (optional, for tasks): [Command Variable](https://marketplace.visualstudio.com/items?itemName=rioj7.command-variable), [Action Buttons](https://marketplace.visualstudio.com/items?itemName=seunlanlege.action-buttons)

## Setup

1. Copy `.aws/config.example` and `.aws/credentials.example` to `.aws/config` and `.aws/credentials`, then fill them in ([format](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-short-term.html)).
2. Run `npm run resource:init` and follow the prompts to:
   - clone a repo into `repos/`, or
   - add a resource to a configuration file (an existing one or a new one).
3. Fill in the generated values in `configurations/<config>.config.json`.

## Configuration

Each file in `configurations/` holds shared settings under `config` and lists of named resources per type:

```json
{
  "config": {
    "aws_profile": "my-profile",
    "aws_region": "us-east-1",
    "config_name": "my-config",
    "task_definitions_directory": "resources/my-config/task_definitions",
    "ssm_parameters_directory": "resources/my-config/ssm_parameters",
    "cf_parameter_file_directory": "resources/my-config/cloudformation_parameters"
  },
  "service": [
    { "name": "my-api", "config": { "ecs_cluster": "...", "ecs_service": "..." } }
  ]
}
```

Resource-level `config` overrides the shared `config`. See [templates/config_templates.json](templates/config_templates.json) for all resource types and fields (`{}` marks an optional field).

## Usage

```bash
npm run <command> config=<config-file> resource=<resource-name> [item=<item-name>] [key=value ...]
```

- `config` defaults to `default.config.json`.
- Any config variable can be overridden with `key=value`.
- All commands are also available as VS Code tasks with pickers.

| Command | Resource | Description |
| --- | --- | --- |
| `image:push` | `image` | Pull repo branch, build Docker image, push to ECR |
| `ecs:start_service` | `service` | Set desired count to 1 |
| `ecs:stop_service` | `service` | Set desired count to 0 (requires `stop_allowed: true`) |
| `ecs:redeploy_service` | `service` | Force new deployment (via CodeDeploy if configured) |
| `ecs:exec_container` | `service` | Exec into the running container |
| `task_definition:validate` | `task_definition` | Validate the task definition file |
| `task_definition:register` | `task_definition` | Register the task definition file |
| `ssm_parameter:pull` | `ssm_parameter` | Download parameter to `<ssm_parameters_directory>/<resource>.sync` |
| `ssm_parameter:push` | `ssm_parameter` | Upload `<resource>.sync` as a SecureString |
| `s3:deploy` | `s3_application` | Pull repo, write `env` to `.env`, build, sync dist to S3 |
| `s3:sync` | `s3_data` | Sync a local directory to S3 |
| `cloudfront:invalidate` | `cloudfront` | Invalidate distribution paths |
| `cloudformation:create_stack` | `cloudformation` | Create stack from `cloudformation/templates/` |
| `cloudformation:update_stack` | `cloudformation` | Update stack |
| `server:ssh` | `server` | SSH into server |
| `server:copy` | `server` | Copy a `resources` item to the server (`item=` required) |
| `server:run_command` | `server` | Run a `commands` item on the server (`item=` required) |
| `resource:clear_history` | - | Delete recorded history |

### Notes

- **Images** are tagged `<last-branch-segment>.latest` (e.g. `feature/login` → `login.latest`) unless `image_tag` is set.
- **CloudFormation** parameters are read from `<cf_parameter_file_directory>/<resource>.json` or `parameter_filename`, if present.
- **Server** items are defined inside the server resource:
  ```json
  "resources": [{ "name": "app", "local_directory_path": "path/to/files", "remote_directory": "~/app" }],
  "commands": [{ "name": "redeploy", "command1": "docker compose pull", "command2": "docker compose up -d" }]
  ```

## History

Commands and their output are logged to `history/<resource-type>/<resource-name>/`. This directory is safe to delete.

## Tests

```bash
npm run test
```
