#!/usr/bin/env bats

# ssh_into_server, copy_to_server and run_command_in_server

setup() {
    load test_helper
    setup_script_sandbox

    key_file="$root_directory/keys/web.pem"
    mkdir -p "$root_directory/keys" "$root_directory/files/site"
    echo "key" >"$key_file"
    echo "setting=1" >"$root_directory/files/app.conf"
    echo "<html>" >"$root_directory/files/site/index.html"
    echo "body {}" >"$root_directory/files/site/style.css"

    write_config <<'EOF'
{
  "config": { "aws_profile": "test-profile", "aws_region": "us-east-1" },
  "server": [
    {
      "name": "web",
      "config": { "host": "10.0.0.1", "username": "ubuntu", "key_path": "keys/web.pem" },
      "resources": [
        { "name": "file", "local_directory_path": "files/app.conf", "remote_directory": "/etc/app" },
        { "name": "directory", "local_directory_path": "files/site", "remote_directory": "/var/www" },
        { "name": "invalid", "local_directory_path": "files/app.conf" }
      ],
      "commands": [
        { "name": "deploy", "command1": "git pull", "command2": "docker compose up -d", "command4": "never run" },
        { "name": "in-directory", "command1": "ls", "remote_directory": "/srv/app" },
        { "name": "invalid", "command2": "ls" }
      ]
    },
    {
      "name": "with-directory",
      "config": {
        "host": "10.0.0.2",
        "username": "admin",
        "key_path": "keys/web.pem",
        "starting_directory": "/srv/app"
      }
    },
    { "name": "no-key", "config": { "host": "10.0.0.3", "username": "ubuntu" } }
  ]
}
EOF
}

# ssh_into_server

@test "ssh_into_server connects with the configured key" {
    run_repo_script ssh_into_server config=test.config.json resource=web
    [ "$status" -eq 0 ]
    [ "$(mock_calls)" = "ssh ubuntu@10.0.0.1 -i $key_file" ]
}

@test "ssh_into_server restricts the key permissions" {
    chmod 644 "$key_file"
    run_repo_script ssh_into_server config=test.config.json resource=web
    [ "$(stat -c %a "$key_file")" = "400" ]
}

@test "ssh_into_server starts in starting_directory when configured" {
    run_repo_script ssh_into_server config=test.config.json resource=with-directory
    [ "$status" -eq 0 ]
    [ "$(mock_calls)" = "ssh -t admin@10.0.0.2 -i $key_file cd /srv/app && exec \$SHELL -l" ]
}

@test "ssh_into_server returns the ssh exit status" {
    mock_response ssh 255
    run_repo_script ssh_into_server config=test.config.json resource=web
    [ "$status" -eq 255 ]
}

@test "ssh_into_server fails when required config is missing" {
    run_repo_script ssh_into_server config=test.config.json resource=no-key
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: key_path must be set"* ]]
    [ -z "$(mock_calls)" ]
}

# copy_to_server

@test "copy_to_server copies a file into the remote directory" {
    run_repo_script copy_to_server config=test.config.json resource=web item=file
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: FILES COPIED TO SERVER SUCCESSFULLY"* ]]
    [ "$(stat -c %a "$key_file")" = "400" ]

    local expected
    expected="ssh -i $key_file ubuntu@10.0.0.1 mkdir -p /etc/app
scp -i $key_file $root_directory/files/app.conf ubuntu@10.0.0.1:/etc/app/"
    [ "$(mock_calls)" = "$expected" ]
}

@test "copy_to_server copies the contents of a directory into the remote directory" {
    run_repo_script copy_to_server config=test.config.json resource=web item=directory
    [ "$status" -eq 0 ]

    local expected
    expected="ssh -i $key_file ubuntu@10.0.0.1 mkdir -p /var/www
scp -i $key_file -r $root_directory/files/site/index.html $root_directory/files/site/style.css ubuntu@10.0.0.1:/var/www/"
    [ "$(mock_calls)" = "$expected" ]
}

@test "copy_to_server fails when the remote directory cannot be created" {
    mock_response ssh 1
    run_repo_script copy_to_server config=test.config.json resource=web item=file
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"FAILED TO CREATE REMOTE DIRECTORY"* ]]
    [[ "$(mock_calls)" != *"scp"* ]]
}

@test "copy_to_server fails when the copy fails" {
    mock_response scp 1
    run_repo_script copy_to_server config=test.config.json resource=web item=file
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"FAILED TO COPY FILES TO SERVER"* ]]
}

@test "copy_to_server fails when required item config is missing" {
    run_repo_script copy_to_server config=test.config.json resource=web item=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: remote_directory must be set"* ]]
    [ -z "$(mock_calls)" ]
}

# run_command_in_server

@test "run_command_in_server runs numbered commands in order and stops at the first gap" {
    run_repo_script run_command_in_server config=test.config.json resource=web item=deploy
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"SUCCESS: ALL COMMANDS EXECUTED SUCCESSFULLY"* ]]

    local expected
    expected="ssh -i $key_file ubuntu@10.0.0.1 git pull
ssh -i $key_file ubuntu@10.0.0.1 docker compose up -d"
    [ "$(mock_calls)" = "$expected" ]
}

@test "run_command_in_server prefixes remote output with the host" {
    mock_response ssh 0 $'first line\nsecond line'
    run_repo_script run_command_in_server config=test.config.json resource=web item=in-directory
    [ "$status" -eq 0 ]
    [[ "$(plain_output)" == *"[10.0.0.1] first line"* ]]
    [[ "$(plain_output)" == *"[10.0.0.1] second line"* ]]
}

@test "run_command_in_server runs commands inside remote_directory when configured" {
    run_repo_script run_command_in_server config=test.config.json resource=web item=in-directory
    [ "$status" -eq 0 ]
    [ "$(mock_calls)" = "ssh -i $key_file ubuntu@10.0.0.1 cd /srv/app && ls" ]
}

@test "run_command_in_server stops at the first failing command" {
    mock_response ssh 3
    run_repo_script run_command_in_server config=test.config.json resource=web item=deploy
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"COMMAND1 FAILED WITH EXIT CODE 3: GIT PULL"* ]]
    [ "$(mock_calls)" = "ssh -i $key_file ubuntu@10.0.0.1 git pull" ]
}

@test "run_command_in_server fails when command1 is missing" {
    run_repo_script run_command_in_server config=test.config.json resource=web item=invalid
    [ "$status" -eq 1 ]
    [[ "$(plain_output)" == *"ERROR: command1 must be set"* ]]
    [ -z "$(mock_calls)" ]
}
