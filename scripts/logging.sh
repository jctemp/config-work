#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
declare -g VERBOSE=0

cli_log() {
  script_name="${BASH_SOURCE[0]}"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo -e "$2[$script_name $timestamp] $1\e[0m"
}

cli_error() {
  cli_log "${1}" "\e[31m"
}

cli_warn() {
  cli_log "${1}" "\e[33m"   
}

cli_success() {
  cli_log "${1}" "\e[32m"   
}

cli_debug() {
  if [ "$VERBOSE" -ne 0 ]
  then
    cli_log "${1}" "\e[34m" 
  fi
}

cli_info() {
  cli_log "${1}" "\e[0m" 
}
