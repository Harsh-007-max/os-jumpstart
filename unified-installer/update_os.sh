#!/bin/bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"
source "$SCRIPT_DIR/idempotancy_store/os-config/detected_os"
source "$SCRIPT_DIR/idempotancy_store/distro_config.sh"

update_os(){
    print_title "Updating $BASE_DISTRO OS"
    update_system
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update_os
fi
