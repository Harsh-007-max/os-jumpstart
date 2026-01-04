#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"
source "$SCRIPT_DIR/install_postgresql.sh"
source "$SCRIPT_DIR/install_mongodb.sh"


install_db() {
    print_title "Installing Databases"

    info "Do you want to install postgresql?"
    read -p "Enter 'y' to install or 'n' to skip: " choice
    if [[ $choice == "y" ]]; then
        install_postgresql
    fi
}
