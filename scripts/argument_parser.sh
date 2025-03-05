#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

parse_argument() {
  local var_name=$1
  local value=$2

  if [ -n "${value}" ] 
  then
    declare -g "${var_name}"="$(echo "${value}" | tr '[:upper:]' '[:lower:]')"
  else
    cli_error "Value for ${var_name} cannot be empty" >&2
    return 2
  fi
}
