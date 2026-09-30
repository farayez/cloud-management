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

# Sandboxed root for running scripts/*.sh with external commands replaced by mocks
setup_script_sandbox() {
    setup_runtime_globals
    ln -s "$REPO_ROOT/utils" "$root_directory/utils"

    export MOCK_DIRECTORY="$BATS_TEST_TMPDIR/mocks"
    mock_log="$MOCK_DIRECTORY/calls.log"
    mkdir -p "$MOCK_DIRECTORY/bin" "$MOCK_DIRECTORY/responses"
    : >"$mock_log"

    local command
    for command in aws docker git scp ssh; do
        cat >"$MOCK_DIRECTORY/bin/$command" <<'EOF'
#!/bin/bash
name=$(basename "$0")
echo "$name $*" >>"$MOCK_DIRECTORY/calls.log"

# Most specific response wins, e.g. "aws ecs list-tasks" before "aws"
for key in "$name $1 $2" "$name $1" "$name"; do
    response="$MOCK_DIRECTORY/responses/${key// /_}"
    [ -f "$response.exit" ] || continue
    [ -f "$response.out" ] && cat "$response.out"
    exit "$(<"$response.exit")"
done
EOF
        chmod +x "$MOCK_DIRECTORY/bin/$command"
    done

    export PATH="$MOCK_DIRECTORY/bin:$PATH"
}

# Usage: mock_response "<command> [sub-command...]" <exit_code> [output]
mock_response() {
    local file="$MOCK_DIRECTORY/responses/${1// /_}"
    echo "$2" >"$file.exit"
    if [ $# -ge 3 ]; then
        printf '%s\n' "$3" >"$file.out"
    fi
}

mock_calls() {
    cat "$mock_log"
}

# Runs scripts/<name>.sh from the sandbox root, the same way npm does from the repo root
run_repo_script() {
    local name=$1
    shift
    cd "$root_directory"
    if [ -t 0 ]; then
        run bash "$REPO_ROOT/scripts/$name.sh" "$@" </dev/null
    else
        run bash "$REPO_ROOT/scripts/$name.sh" "$@"
    fi
}

# Writes stdin to configurations/<name> (default test.config.json)
write_config() {
    cat >"$root_directory/configurations/${1:-test.config.json}"
}

# Keystrokes selecting the option at the given zero-based index in fn_choose_from_menu
menu_select() {
    local i
    for ((i = 0; i < $1; i++)); do
        printf '\e[B'
    done
    printf '\n'
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
