#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo_config.sh"
source "$SCRIPT_DIR/shared_functions.sh"



install_fedora_repos() {
  print_title "Configuring Fedora Repositories"

  if [ "$EUID" -ne 0 ]; then
    error "This function must be run as root. Please run with sudo."
  fi
  info "Enabling RPM Fusion Free and Non-Free Repositories"

  run_import "base-utils"
  run_import "rpm-fusion"
  run_import "brave-browser"
  run_import "vscode"
  run_import "spotify"
  run_import "docker"
  run_import "lazygit"
  run_import "google-chrome"
  run_import "neovim"
  run_import "flathub"

  info "Refreshing DNF package cache"
  sudo dnf makecache

  success "Fedora repositories configured successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_fedora_repos
fi
