#!/bin/bash

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

export TERM="${TERM:-dumb}"
export COLUMNS=120

# Globals normally set by utils/prepare_runtime.sh
setup_runtime_globals() {
    root_directory="$BATS_TEST_TMPDIR/root"
    current_execution_id="test_execution"
    current_script_name="test_script"

    mkdir -p "$root_directory/configurations" "$root_directory/templates"
    cp "$REPO_ROOT/templates/history.gitignore.template" "$root_directory/templates/"
}

# bats sources files inside functions, so `declare -A` would create locals; force globals instead
source_common_functions() {
    source <(sed -E 's/^declare -A /declare -gA /' "$REPO_ROOT/utils/define_constants.sh")
    source "$REPO_ROOT/utils/functions/output.sh"
    source "$REPO_ROOT/utils/functions/input.sh"
    source "$REPO_ROOT/utils/functions/execution.sh"
    source "$REPO_ROOT/utils/functions/run_command.sh"
    source "$REPO_ROOT/utils/functions/parse_config.sh"
    source "$REPO_ROOT/utils/declare_functions.sh"
}

strip_colors() {
    sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g'
}

# Plain-text version of the last `run` output
plain_output() {
    printf '%s\n' "$output" | strip_colors
}

write_test_config() {
    cat >"$root_directory/configurations/${1:-test.config.json}" <<'EOF'
{
  "config": {
    "aws_profile": "test-profile",
    "aws_region": "us-east-1",
    "shared": "stack"
  },
  "server": [
    {
      "name": "web",
      "config": {
        "host": "10.0.0.1",
        "username": "ubuntu",
        "shared": "resource",
        "description": "main web server",
        "port": 22,
        "enabled": true,
        "paths": ["/*"],
        "unused": null,
        "nested": {}
      },
      "commands": [
        { "name": "deploy", "command1": "echo hi", "command2": "ls" },
        { "name": "other", "command1": "pwd" }
      ]
    },
    {
      "name": "db",
      "config": { "host": "10.0.0.2" }
    }
  ]
}
EOF
}
