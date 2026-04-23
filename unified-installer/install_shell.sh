#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"
source "$SCRIPT_DIR/idempotancy_store/os-config/detected_os"
source "$SCRIPT_DIR/idempotancy_store/distro_config.sh"

install_shell() {
    read -p "Do you want to install zsh? [y/N] " choice
    case "$choice" in
        [yY]|[yY][eE][sS])
            if command -v zsh &> /dev/null; then
                info "[Info]: zsh is already installed."
            else
                info "[Install]: zsh is installing..."
                install_cmd=$(install_pkg "zsh")
                eval $install_cmd
            fi
            ;;
        *)
            echo "Skipping zsh installation."
            return 0
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_shell
fi
