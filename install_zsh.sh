#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

setup_zsh() {
  print_title "Configuring Zsh and Oh My Zsh"
  local REAL_USER="${SUDO_USER:-$USER}"
  local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

  # 1. Install Dependencies
  info "Checking Zsh dependencies..."
  if ! rpm -q zsh git curl util-linux-user &>/dev/null; then
    sudo dnf install -y zsh git curl util-linux-user
  else
    info "Zsh packages already installed."
  fi

  local ZSH_PATH=$(which zsh)
  
  # 2. Change System Default Shell (For SSH/TTY)
  local CURRENT_SHELL=$(getent passwd "$REAL_USER" | cut -d: -f7)
  if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    info "Changing default shell for user '$REAL_USER' to Zsh..."
    if sudo usermod --shell "$ZSH_PATH" "$REAL_USER"; then
      success "System default shell changed to Zsh."
    else
      error "Failed to change shell. Try manually: chsh -s $ZSH_PATH"
    fi
  else
    info "Default shell is already Zsh. Skipping."
  fi

  # 3. Install Oh My Zsh
  local OMZ_DIR="$REAL_HOME/.oh-my-zsh"
  if [ -d "$OMZ_DIR" ]; then
    info "Oh My Zsh is already installed. Skipping."
  else
    info "Installing Oh My Zsh..."
    sudo -u "$REAL_USER" sh -c "ZSH=$OMZ_DIR sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
    if [ $? -eq 0 ]; then
      success "Oh My Zsh installed successfully."
    else
      error "Failed to install Oh My Zsh."
      return 1
    fi
  fi

  # --- 4. THE KONSOLE FIX (Force Profile) ---
  info "Configuring KDE Konsole to strictly use Zsh..."
  
  local KONSOLE_DIR="$REAL_HOME/.local/share/konsole"
  local KONSOLE_RC="$REAL_HOME/.config/konsolerc"
  
  # Ensure Konsole profile directory exists
  sudo -u "$REAL_USER" mkdir -p "$KONSOLE_DIR"

  # A. Create a dedicated Zsh Profile
  local PROFILE_FILE="$KONSOLE_DIR/Zsh.profile"
  
  # We write a clean profile that forces the Command to be Zsh
  sudo -u "$REAL_USER" bash -c "cat > '$PROFILE_FILE'" <<EOF
[General]
Name=Zsh
Parent=FALLBACK/
Command=$ZSH_PATH
EOF
  success "Created Zsh profile at $PROFILE_FILE"

  # B. Force Konsole to use this profile by default
  # We verify if konsolerc exists, then update or append the DefaultProfile
  if [ -f "$KONSOLE_RC" ]; then
      # If DefaultProfile is set, replace it
      if grep -q "DefaultProfile=" "$KONSOLE_RC"; then
          sudo -u "$REAL_USER" sed -i "s|^DefaultProfile=.*|DefaultProfile=Zsh.profile|" "$KONSOLE_RC"
      else
          # If [Desktop Entry] exists but no profile, insert it
          if grep -q "\[Desktop Entry\]" "$KONSOLE_RC"; then
              sudo -u "$REAL_USER" sed -i "/\[Desktop Entry\]/a DefaultProfile=Zsh.profile" "$KONSOLE_RC"
          else
              # File exists but likely empty or missing main section
              echo -e "[Desktop Entry]\nDefaultProfile=Zsh.profile" | sudo -u "$REAL_USER" tee -a "$KONSOLE_RC" >/dev/null
          fi
      fi
  else
      # Create new config file if missing
      echo -e "[Desktop Entry]\nDefaultProfile=Zsh.profile" | sudo -u "$REAL_USER" tee "$KONSOLE_RC" >/dev/null
  fi
  
  success "Set Konsole default profile to 'Zsh.profile'."

  # 5. Fix permissions (Just in case root touched anything incorrectly)
  chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.local/share/konsole" "$REAL_HOME/.config/konsolerc" 2>/dev/null

  print_title "Zsh Setup Complete"
  info "Please restart Konsole for changes to take effect."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_zsh
fi
