#!/bin/bash

_command_complete(){
      COMPREPLY=($(compgen -d "services/$2"))
      COMPREPLY=("${COMPREPLY[@]##*/}")
}

complete -F _command_complete ./exec-container.sh
complete -F _command_complete ./pull-env.sh
complete -F _command_complete ./push-env.sh
complete -F _command_complete ./push-image.sh
complete -F _command_complete ./start-service.sh
complete -F _command_complete ./stop-service.sh
complete -F _command_complete ./view-variables.sh
complete -F _command_complete ./test.sh