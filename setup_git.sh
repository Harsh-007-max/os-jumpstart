#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

setup_git() {
  print_title "Git Configuration & Repository Setup"
  
  local REAL_USER="${SUDO_USER:-$USER}"
  local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
  
  # --- 1. Git Identity Setup ---
  info "Configuring Global Git Identity..."
  
  # Check if already configured to avoid annoying prompts on re-runs
  local current_name=$(git config --global user.name)
  local current_email=$(git config --global user.email)

  if [ -n "$current_name" ] && [ -n "$current_email" ]; then
    info "Git identity already set to: $current_name <$current_email>"
    read -p "Do you want to change this? (y/N): " change_git
    if [[ "$change_git" =~ ^[Yy]$ ]]; then
       unset current_name
    fi
  fi

  if [ -z "$current_name" ]; then
    read -p "Enter your Name (e.g., Harsh Bhalodia): " git_name
    read -p "Enter your Email: " git_email
    
    # We run git config as the USER, not root, to save to ~/.gitconfig
    sudo -u "$REAL_USER" git config --global user.name "$git_name"
    sudo -u "$REAL_USER" git config --global user.email "$git_email"
    sudo -u "$REAL_USER" git config --global init.defaultBranch main
    sudo -u "$REAL_USER" git config --global credential.helper store
    success "Git identity configured."
  fi

  # --- 2. GitHub CLI Authentication ---
  info "Checking GitHub Authentication..."
  
  if ! command -v gh &>/dev/null; then
    warn "GitHub CLI (gh) is not installed. Skipping auth."
  else
    # Check status as the real user
    if sudo -u "$REAL_USER" gh auth status &>/dev/null; then
      success "Already logged into GitHub."
    else
      info "Logging into GitHub CLI..."
      # Interactive login as the user
      sudo -u "$REAL_USER" gh auth login -h github.com -p https -w
      success "GitHub authentication complete."
    fi
  fi

  # --- 3. Repository Cloning Loop ---
  print_title "Clone Repositories"
  
  # Changed target to ~/coding
  local TARGET_DIR="$REAL_HOME/coding"
  
  # Create directory with correct ownership
  if [ ! -d "$TARGET_DIR" ]; then
      mkdir -p "$TARGET_DIR"
      chown "$REAL_USER:$REAL_USER" "$TARGET_DIR"
  fi
  
  info "Target Directory: $TARGET_DIR"
  echo "Paste repository URLs below. Press ENTER (empty line) or type 'stop' to finish."
  
  while true; do
    echo ""
    read -p "Repo URL > " REPO_URL
    
    # Exit condition
    if [[ -z "$REPO_URL" || "$REPO_URL" == "stop" ]]; then
      break
    fi
    
    local REPO_NAME=$(basename "$REPO_URL" .git)
    info "Cloning $REPO_NAME..."
    
    # Run git clone as the REAL USER
    if sudo -u "$REAL_USER" git -C "$TARGET_DIR" clone "$REPO_URL"; then
      success "Cloned successfully."
    else
      error "Failed to clone $REPO_URL"
    fi
  done
  
  success "Git setup and cloning complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_git
fi
