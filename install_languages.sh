#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

setup_languages() {
  print_title "Installing Programming Languages"

  local REAL_USER="${SUDO_USER:-$USER}"
  local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

  if rpm -q golang &> /dev/null; then
    info "Go is already installed. Skipping."
  else
    info "Installing Go programming language..."
    sudo dnf install -y golang
    success "Go installed successfully."
  fi

  if [ -d "$REAL_HOME/.cargo" ]; then
    info "Rust/Cargo is already installed at $REAL_HOME/.cargo. Skipping."
  else
    info "Installing Rust (Rustup) for user '$REAL_USER'..."
    sudo -u "$REAL_USER" sh -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    if [ $? -eq 0 ]; then
      success "Rust installed successfully for user '$REAL_USER'."
    else
      error "Failed to install Rust for user '$REAL_USER'."
      return 1
    fi
  fi

  local NVM_DIR="$REAL_HOME/.nvm"

  if [ -d "$NVM_DIR" ]; then
    info "NVM is already installed at $NVM_DIR. Skipping."
  else
    info "Installing NVM for user '$REAL_USER'..."
    sudo -u "$REAL_USER" sh -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
    if [ $? -eq 0 ]; then
      success "NVM installed successfully for user '$REAL_USER'."

    else
      error "Failed to install NVM for user '$REAL_USER'."
      return 1
    fi
  fi

  info "Installing Node.js v22 via NVM for user '$REAL_USER'..."
  sudo -u "$REAL_USER" bash -c "
  export NVM_DIR='$NVM_DIR'
  [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"  # Load NVM

  if nvm ls 22 &>/dev/null; then
    echo 'Node v22 is already installed.'
  else
    echo 'Downloading Node v22...'
    nvm install 22
    nvm alias default 22
    nvm use default
      fi
      "
      if [ $? -eq 0 ]; then
        success "Node.js v22 installed successfully via NVM for user '$REAL_USER'."
      else
        error "Failed to install Node.js v22 via NVM for user '$REAL_USER'."
        return 1
      fi
    }

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_languages
  fi
