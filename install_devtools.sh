#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

# --- GENERIC HELPER: Install any App from Tarball ---
# Usage: install_tar_app "AppName" "URL" "InstallPath" "RelBinaryPath" "RelIconPath" "SymlinkName" "WMClass"
install_tar_app() {
  local APP_NAME="$1"
  local DOWNLOAD_URL="$2"
  local INSTALL_DIR="$3"
  local BIN_REL="$4"    # Path to binary inside install dir
  local ICON_REL="$5"   # Path to icon inside install dir
  local SYM_NAME="$6"   # Name for /usr/local/bin/<name>
  local WM_CLASS="$7"   # (Optional) StartupWMClass for desktop file

  echo "  -> [$APP_NAME] Starting installation..."

  # Check if already exists
  if [ -d "$INSTALL_DIR" ]; then
      echo "  -> [$APP_NAME] Removing previous installation..."
      sudo rm -rf "$INSTALL_DIR"
  fi
  sudo mkdir -p "$INSTALL_DIR"

  # Download
  local TEMP_TAR=$(mktemp)
  echo "  -> [$APP_NAME] Downloading..."
  # -sS = Silent but show errors
  if ! curl -L "$DOWNLOAD_URL" -o "$TEMP_TAR" -sS; then
      echo "Error: [$APP_NAME] Download failed."
      rm -f "$TEMP_TAR"
      return 1
  fi

  # Extract
  echo "  -> [$APP_NAME] Extracting..."
  # --strip-components=1 removes the top-level folder inside the tarball
  # so files go directly into INSTALL_DIR (e.g. /opt/Postman/Postman)
  if ! sudo tar -xzf "$TEMP_TAR" -C "$INSTALL_DIR" --strip-components=1; then
      echo "Error: [$APP_NAME] Extraction failed."
      rm -f "$TEMP_TAR"
      return 1
  fi
  rm -f "$TEMP_TAR"

  # Symlink
  echo "  -> [$APP_NAME] Creating symlink '$SYM_NAME'..."
  sudo ln -sf "$INSTALL_DIR/$BIN_REL" "/usr/local/bin/$SYM_NAME"

  # Desktop Shortcut
  echo "  -> [$APP_NAME] Creating desktop entry..."
  local DESKTOP_FILE="/usr/share/applications/$SYM_NAME.desktop"
  local ICON_PATH="$INSTALL_DIR/$ICON_REL"
  
  # Construct Desktop Entry content
  sudo bash -c "cat > $DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Icon=$ICON_PATH
Exec="$INSTALL_DIR/$BIN_REL" %f
Comment=$APP_NAME
Categories=Development;IDE;
Terminal=false
StartupWMClass=${WM_CLASS:-$SYM_NAME}
EOF

  echo "  -> [$APP_NAME] Installation complete."
}

# --- WRAPPER: JetBrains Logic ---
install_jetbrains() {
  local APP_CODE="$1"
  local APP_NAME="$2"
  local CMD_NAME="$3"

  # 1. Fetch Dynamic URL
  echo "  -> [JetBrains] Fetching URL for $APP_NAME..."
  if ! command -v jq &>/dev/null; then echo "Error: jq missing."; return 1; fi

  local API="https://data.services.jetbrains.com/products/releases?code=${APP_CODE}&latest=true&type=release"
  local URL=$(curl -s "$API" | jq -r ".${APP_CODE}[0].downloads.linux.link")

  if [[ -z "$URL" || "$URL" == "null" ]]; then
    echo "Error: Could not resolve URL for $APP_NAME"
    return 1
  fi

  # 2. Call Generic Helper
  # Structure: /opt/jetbrains/webstorm/bin/webstorm.sh
  install_tar_app \
    "$APP_NAME" \
    "$URL" \
    "/opt/jetbrains/$CMD_NAME" \
    "bin/$CMD_NAME.sh" \
    "bin/$CMD_NAME.svg" \
    "$CMD_NAME" \
    "jetbrains-$CMD_NAME"
}

# --- WRAPPER: Postman Logic ---
install_postman() {
  # Postman has a static URL, so we just pass data to the helper
  # Structure: /opt/Postman/Postman (binary)
  # Icon: /opt/Postman/app/resources/app/assets/icon.png
  
  install_tar_app \
    "Postman" \
    "https://dl.pstmn.io/download/latest/linux64" \
    "/opt/Postman" \
    "Postman" \
    "app/resources/app/assets/icon.png" \
    "postman" \
    "Postman"
}

install_devtools() {
  print_title "Installing Development Tools"

  local REAL_USER="${SUDO_USER:-$USER}"
  
  # Log files
  local LOG_DNF="/tmp/devtools_dnf.log"
  local LOG_FLATPAK="/tmp/devtools_flatpak.log"
  local LOG_JETBRAINS="/tmp/devtools_jetbrains.log"
  local LOG_POSTMAN="/tmp/devtools_postman.log"

  # --- 1. Pre-requisites ---
  if ! command -v jq &>/dev/null; then
    info "Installing 'jq'..."
    sudo dnf install -y jq &>/dev/null
  fi
  # Clean up conflicts
  sudo dnf remove -y docker docker-client docker-common podman-docker &>/dev/null

  # --- 2. Package Lists ---
  local DNF_PACKAGES=(
    "@Development Tools" "code" "neovim"
    "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"
  )
  local FLATPAK_PACKAGES=("dev.zed.Zed")

  # --- 3. Quad-Parallel Installation ---
  print_title "Starting Quad-Parallel Installation"
  echo "  1. DNF (System Utils)       -> $LOG_DNF"
  echo "  2. Flatpak (Zed)            -> $LOG_FLATPAK"
  echo "  3. JetBrains (WS, DG)       -> $LOG_JETBRAINS"
  echo "  4. Postman (Native)         -> $LOG_POSTMAN"

  # Thread A: DNF
  ( sudo dnf install -y --skip-unavailable "${DNF_PACKAGES[@]}" > "$LOG_DNF" 2>&1 ) & PID_DNF=$!

  # Thread B: Flatpak
  ( flatpak install -y flathub "${FLATPAK_PACKAGES[@]}" > "$LOG_FLATPAK" 2>&1 ) & PID_FLATPAK=$!

  # Thread C: JetBrains (WebStorm & DataGrip)
  (
    {
      install_jetbrains "WS" "WebStorm" "webstorm"
      install_jetbrains "DG" "DataGrip" "datagrip"
    } > "$LOG_JETBRAINS" 2>&1
  ) & PID_JETBRAINS=$!

  # Thread D: Postman
  ( install_postman > "$LOG_POSTMAN" 2>&1 ) & PID_POSTMAN=$!

  # --- 4. Wait & Report ---
  info "Waiting for background tasks..."
  
  wait $PID_DNF
  RESULT_DNF=$?
  
  wait $PID_FLATPAK
  RESULT_FLATPAK=$?
  
  wait $PID_JETBRAINS
  RESULT_JETBRAINS=$?

  wait $PID_POSTMAN
  RESULT_POSTMAN=$?

  [ $RESULT_DNF -eq 0 ]       && success "DNF installed."       || error "DNF failed (see $LOG_DNF)"
  [ $RESULT_FLATPAK -eq 0 ]   && success "Flatpak installed."   || warn  "Flatpak failed (see $LOG_FLATPAK)"
  [ $RESULT_JETBRAINS -eq 0 ] && success "JetBrains installed." || error "JetBrains failed (see $LOG_JETBRAINS)"
  [ $RESULT_POSTMAN -eq 0 ]   && success "Postman installed."   || error "Postman failed (see $LOG_POSTMAN)"

  # --- 5. Post-Config ---
  
  # Docker Permissions
  sudo systemctl enable --now docker
  sudo groupadd -f docker
  if sudo usermod -aG docker "$REAL_USER"; then
     success "User '$REAL_USER' added to Docker group."
  fi
  
  # OpenCode CLI
  if ! command -v opencode &>/dev/null; then
    info "Installing OpenCode CLI..."
    sudo -u "$REAL_USER" sh -c "curl -fsSL https://opencode.ai/install | bash" &>/dev/null
  fi

  success "Dev environment setup complete!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_devtools
fi
