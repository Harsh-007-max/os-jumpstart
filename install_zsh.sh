#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

setup_zsh() {
  print_title "Configuring Zsh and Oh My Zsh"
  local REAL_USER="${SUDO_USER:-$USER}"

  local REAL_HOME
  REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

  if [ "$REAL_USER" == "root" ]; then
    warn "Running as root user. Assuming you want to setup Zsh for root."
  fi

  info "Checking Zsh dependencies..."
  if ! rpm -q zsh git curl util-linux-user &>/dev/null; then
    sudo dnf install -y zsh git curl util-linux-user
  else
    info "Zsh packages already installed."
  fi

  local ZSH_PATH=$(which zsh)
  local CURRENT_SHELL=$(getent passwd "$REAL_USER" | cut -d: -f7)

  if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    info "Changing default shell for user '$REAL_USER' to Zsh..."

    if sudo usermod --shell "$ZSH_PATH" "$REAL_USER"; then
      success "Default shell changed to Zsh for user '$REAL_USER'."
    else
      error "Failed to change default shell for user '$REAL_USER'."
      return 1
    fi
  else
    info "Default shell is already Zsh for user '$REAL_USER' Skipping."
  fi

  local OMZ_DIR="$REAL_HOME/.oh-my-zsh"
  if [ -d "$OMZ_DIR" ]; then
    info "Oh My Zsh is already installed at $OMZ_DIR. Skipping."
  else
    info "Installing Oh My Zsh for user '$REAL_USER'..."

    sudo -u "$REAL_USER" sh -c "ZSH=$OMZ_DIR sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
    if [ $? -eq 0 ]; then
      success "Oh My Zsh installed successfully for user '$REAL_USER'."
    else
      error "Failed to install Oh My Zsh for user '$REAL_USER'."
      return 1
    fi
  fi

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_zsh
fi
