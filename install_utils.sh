#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

install_utils() {
  print_title "Installing Utility Packages"

  local PACKAGES=(
    "htop"
    "btop"
    "jq"
    "make"
    "gcc-c++"
    "wl-clipboard"
    "ripgrep"
    "bat"
    "tmux"
    "lazygit"
    "libsecret"
  )
  info "Installing ${#PACKAGES[@]} utility packages..."
  if sudo dnf install -y "${PACKAGES[@]}"; then
    success "Utility packages installed successfully."
  else
    error "Failed to install utility packages."
    return 1
  fi

  info "Installing Microsoft Dev Tunnel CLI..."

  if command -v devtunnel &>/dev/null; then
    info "Dev Tunnel CLI is already installed. Skipping."
  else
    local TEMP_DIR
    TEMP_DIR=$(mktemp)
    if curl -sL "https://aka.ms/TunnelsCliDownload/linux-x64" -o "$TEMP_DIR"; then
      chmod +x "$TEMP_DIR"
      sudo mv "$TEMP_DIR" /usr/local/bin/devtunnel

      if command -v devtunnel &>/dev/null; then
        success "Microsoft Dev Tunnel CLI installed successfully."
      else
        error "Dev Tunnel CLI installation failed."
        return 1
      fi
    else
      error "Failed to download Dev Tunnel CLI."
      rm -f "$TEMP_DIR"
      return 1
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_utils
fi
