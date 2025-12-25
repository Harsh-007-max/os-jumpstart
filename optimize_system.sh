#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

optimize_system() {
  print_title "Optimizing Fedora System Resources"

  local REAL_USER="${SUDO_USER:-$USER}"
  local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

  # 1. Disable PackageKit (RAM Hog)
  # Prevents "Discover" store from running in background. Safe since you use DNF.
  info "Masking PackageKit (Saves ~300MB RAM)..."
  if systemctl is-active --quiet packagekit; then
    sudo systemctl stop packagekit
  fi
  sudo systemctl mask packagekit
  success "PackageKit disabled."

  # 2. Disable Baloo (File Indexer)
  # Must run as the REAL USER to affect your session
  info "Disabling Baloo File Indexer for user '$REAL_USER'..."
  
  # Try KDE 6 command first, then KDE 5
  if command -v balooctl6 &>/dev/null; then
    sudo -u "$REAL_USER" balooctl6 disable &>/dev/null
    sudo -u "$REAL_USER" balooctl6 purge &>/dev/null
  else
    sudo -u "$REAL_USER" balooctl disable &>/dev/null
    sudo -u "$REAL_USER" balooctl purge &>/dev/null
  fi

  # Hard disable via config file (ensure ownership remains with user)
  local BALOO_CFG="$REAL_HOME/.config/baloofilerc"
  
  if [ -f "$BALOO_CFG" ]; then
    sudo -u "$REAL_USER" sed -i 's/^Indexing-Enabled=true/Indexing-Enabled=false/' "$BALOO_CFG"
    if ! grep -q "Indexing-Enabled=false" "$BALOO_CFG"; then
         echo -e "\n[Basic Settings]\nIndexing-Enabled=false" | sudo -u "$REAL_USER" tee -a "$BALOO_CFG" >/dev/null
    fi
  else
    printf "[Basic Settings]\nIndexing-Enabled=false\n" | sudo -u "$REAL_USER" tee "$BALOO_CFG" >/dev/null
  fi
  success "Baloo disabled."

  # 3. Disable Unused Hardware Services
  info "Disabling unused hardware services..."

  # ModemManager (Only used for Cellular/LTE USB sticks)
  if systemctl is-active --quiet ModemManager; then
    sudo systemctl disable --now ModemManager
    success "ModemManager disabled."
  fi

  # ABRT (Automated Bug Reporting Tool)
  if systemctl is-active --quiet abrtd; then
    sudo systemctl disable --now abrtd
    success "ABRT disabled."
  fi

  success "System optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    optimize_system
fi
