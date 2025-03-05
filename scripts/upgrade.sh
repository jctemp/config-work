#!/usr/bin/env bash

set -o errexit  # Exit on error
set -o nounset  # Exit on unset variables
set -o pipefail # Exit on pipe failures

# shellcheck disable=2086
dir=$(dirname "$(readlink -f $0)");

# shellcheck source=/dev/null
source "$dir/argument_parser.sh"
# shellcheck source=/dev/null
source "$dir/logging.sh"

### CLI

## OPTIONS
configuration_path="." # Optional
configuration_name="" # Required

ssh_address="" # Optional
ssh_port="22" # Optional

print_usage() {
    cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [options]

Options:
    -p, --path PATH         Configuration path (default: ".")
    -n, --name NAME         Configuration name (required)
    -a, --address ADDRESS   SSH address (empty)
    --port PORT             SSH port (default: "22")
    -v, --verbose           Print verbose output (debug logs)
    -h, --help              Print this help message

Example:
    $(basename "${BASH_SOURCE[0]}") --name kent --address example.com
EOF
}

cli_debug "Starting argument parsing"
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            parse_argument "configuration_path" "$2"
            cli_debug "Set configuration path: $configuration_path"
            shift 2
            ;;
        -n|--name)
            parse_argument "configuration_name" "$2"
            cli_debug "Set configuration name: $configuration_name"
            shift 2
            ;;
        -a|--address)
            parse_argument "ssh_address" "$2"
            cli_debug "Set SSH address: $ssh_address"
            shift 2
            ;;
        --port)
            parse_argument "ssh_port" "$2"
            cli_debug "Set SSH port: $ssh_port"
            shift 2
            ;;
        -v|--verbose)
            # variable is used in cli_debug function
            # shellcheck disable=2034
            VERBOSE=1
            shift 1
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            cli_error "Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
done

cli_debug "Starting parameter validation"
validation_errors=()

if [ -z "$configuration_name" ]; then
    validation_errors+=("Configuration name is required (use -n or --name)")
fi

if [ ! -d "$configuration_path" ]; then
    validation_errors+=("Configuration path '$configuration_path' does not exist")
fi

if [ ${#validation_errors[@]} -ne 0 ]; then
    cli_error "Incorrect or missing arguments"
    for error in "${validation_errors[@]}"; do
        cli_error "  $error"
    done
    echo
    print_usage
    exit 1
fi

cli_info "Arguments validated successfully"
cli_debug "Final arguments:"
cli_debug "| CONFIGURATION"
cli_debug "  | Path:    $configuration_path"
cli_debug "  | Name:    $configuration_name"
cli_debug "| SSH"
cli_debug "  | Address: $ssh_address"
cli_debug "  | Port:    $ssh_port"

if [ -z "$ssh_address" ]
then
    nixos-rebuild switch \
      --no-write-lock-file \
      --verbose \
      --flake "${configuration_path}#${configuration_name}"
else 
    nixos-rebuild switch \
      --no-write-lock-file \
      --verbose \
      --flake "${configuration_path}#${configuration_name}" \
      --target-host "root@$ssh_address:$ssh_port"
fi


