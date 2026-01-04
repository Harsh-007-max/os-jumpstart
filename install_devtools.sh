#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"
#spate maar
# --- STATUS HELPERS ---
STAT_DNF="/tmp/status_dnf"
STAT_FLATPAK="/tmp/status_flatpak"
STAT_IDES="/tmp/status_ides"

update_status() {
  echo "$2" > "$1"
}

# --- GENERIC HELPER: Install with Live Progress ---
install_tar_app() {
  local STATUS_FILE="$1"
  local APP_NAME="$2"
  local DOWNLOAD_URL="$3"
  local INSTALL_DIR="$4"
  local BIN_REL="$5"
  local ICON_REL="$6"
  local SYM_NAME="$7"
  local WM_CLASS="$8"

  update_status "$STATUS_FILE" "Initializing $APP_NAME..."

  if [ -d "$INSTALL_DIR" ]; then
      sudo rm -rf "$INSTALL_DIR"
  fi
  sudo mkdir -p "$INSTALL_DIR"

  local TEMP_TAR=$(mktemp)

  # --- THE FIX: Unbuffered Curl Loop ---
  # 1. curl -N disables output buffering.
  # 2. We read character-by-character until we hit a carriage return (\r).
  # 3. We extract the first column (Percentage) using bash substring.

  update_status "$STATUS_FILE" "Starting Download..."

  if ! curl -N -L "$DOWNLOAD_URL" -o "$TEMP_TAR" 2>&1 | \
     while IFS= read -r -d $'\r' line; do
        # Extract first 3 characters (The percentage column)
        # e.g. " 12" or "100"
        PCT="${line:0:4}"
        # Only update if it looks like a number
        if [[ "$PCT" =~ [0-9] ]]; then
            update_status "$STATUS_FILE" "Downloading $APP_NAME: ${PCT// /}%"
        fi
     done; then

      # Double check if file exists and has size
      if [ ! -s "$TEMP_TAR" ]; then
          update_status "$STATUS_FILE" "Error: Download failed."
          rm -f "$TEMP_TAR"
          return 1
      fi
  fi

  update_status "$STATUS_FILE" "Extracting $APP_NAME..."
  if ! sudo tar -xzf "$TEMP_TAR" -C "$INSTALL_DIR" --strip-components=1; then
      update_status "$STATUS_FILE" "Error: Extraction failed."
      rm -f "$TEMP_TAR"
      return 1
  fi
  rm -f "$TEMP_TAR"

  update_status "$STATUS_FILE" "Linking $APP_NAME..."
  sudo ln -sf "$INSTALL_DIR/$BIN_REL" "/usr/local/bin/$SYM_NAME"

  local DESKTOP_FILE="/usr/share/applications/$SYM_NAME.desktop"
  local ICON_PATH="$INSTALL_DIR/$ICON_REL"

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

  update_status "$STATUS_FILE" "Installed $APP_NAME."
}

# --- THREAD: Heavy Apps (Sequential) ---
install_heavy_apps_thread() {
  update_status "$STAT_IDES" "Starting..."

  if ! command -v jq &>/dev/null; then
    update_status "$STAT_IDES" "Error: jq missing."
    return 1
  fi

  # 1. WEBSTORM
  update_status "$STAT_IDES" "Finding WebStorm URL..."
  local URL_WS=$(curl -s "https://data.services.jetbrains.com/products/releases?code=WS&latest=true&type=release" | jq -r ".WS[0].downloads.linux.link")

  if [[ -n "$URL_WS" && "$URL_WS" != "null" ]]; then
    install_tar_app "$STAT_IDES" "WebStorm" "$URL_WS" "/opt/jetbrains/webstorm" \
      "bin/webstorm" "bin/webstorm.svg" "webstorm" "jetbrains-webstorm"
  else
    update_status "$STAT_IDES" "Error: WebStorm URL not found."
  fi

  # 2. DATAGRIP
  update_status "$STAT_IDES" "Finding DataGrip URL..."
  local URL_DG=$(curl -s "https://data.services.jetbrains.com/products/releases?code=DG&latest=true&type=release" | jq -r ".DG[0].downloads.linux.link")

  if [[ -n "$URL_DG" && "$URL_DG" != "null" ]]; then
    install_tar_app "$STAT_IDES" "DataGrip" "$URL_DG" "/opt/jetbrains/datagrip" \
      "bin/datagrip" "bin/datagrip.svg" "datagrip" "jetbrains-datagrip"
  else
    update_status "$STAT_IDES" "Error: DataGrip URL not found."
  fi

  # 3. POSTMAN
  install_tar_app "$STAT_IDES" "Postman" \
    "https://dl.pstmn.io/download/latest/linux64" \
    "/opt/Postman" "Postman" "app/resources/app/assets/icon.png" "postman" "Postman"

  update_status "$STAT_IDES" "All Apps Installed."
}

# --- MAIN FUNCTION ---
install_devtools() {
  print_title "Installing Development Tools"

  local REAL_USER="${SUDO_USER:-$USER}"
  local LOG_DNF="/tmp/devtools_dnf.log"
  local LOG_FLATPAK="/tmp/devtools_flatpak.log"

  # Initialize status
  echo "Waiting..." > "$STAT_DNF"
  echo "Waiting..." > "$STAT_FLATPAK"
  echo "Waiting..." > "$STAT_IDES"

  # 1. Pre-requisites
  if ! command -v jq &>/dev/null; then
    info "Installing 'jq'..."
    sudo dnf install -y jq &>/dev/null
  fi

  sudo dnf remove -y docker docker-client docker-common podman-docker &>/dev/null

  # 2. Start Parallel Threads
  print_title "Starting Installation"

  # THREAD A: DNF
  (
    update_status "$STAT_DNF" "Running transaction..."
    local DNF_PACKAGES=("@Development Tools" "code" "neovim" "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    if sudo dnf install -y --skip-unavailable "${DNF_PACKAGES[@]}" > "$LOG_DNF" 2>&1; then
       update_status "$STAT_DNF" "Done."
    else
       update_status "$STAT_DNF" "Error (See logs)."
       exit 1
    fi
  ) & PID_DNF=$!

  # THREAD B: Flatpak
  (
    update_status "$STAT_FLATPAK" "Installing flatpak apps..."
    local FLATPAK_PACKAGES=(
      "dev.zed.Zed"
      "com.obsproject.Studio"
      "com.mongodb.Compass"
      "md.obsidian.Obsidian"
    )
    if flatpak install -y flathub "${FLATPAK_PACKAGES[@]}" > "$LOG_FLATPAK" 2>&1; then
       update_status "$STAT_FLATPAK" "Done."
    else
       update_status "$STAT_FLATPAK" "Error (See logs)."
       exit 1
    fi
  ) & PID_FLATPAK=$!

  # THREAD C: IDEs & Tools (Sequential)
  ( install_heavy_apps_thread ) & PID_IDES=$!

  # 3. LIVE STATUS DASHBOARD
  tput civis # Hide cursor
  echo ""
  echo "  [DNF]     ..."
  echo "  [Flatpak] ..."
  echo "  [IDEs]    ..."

  while kill -0 $PID_DNF 2>/dev/null || \
        kill -0 $PID_FLATPAK 2>/dev/null || \
        kill -0 $PID_IDES 2>/dev/null; do

    tput cuu 3

    # Read status files directly
    S_DNF=$(cat "$STAT_DNF")
    S_FP=$(cat "$STAT_FLATPAK")
    S_IDES=$(cat "$STAT_IDES")

    # \033[K clears the line to the right to prevent ghost text
    echo -e "  [DNF]     ${S_DNF}\033[K"
    echo -e "  [Flatpak] ${S_FP}\033[K"
    echo -e "  [IDEs]    ${S_IDES}\033[K"

    sleep 0.2
  done

  tput cnorm # Restore cursor
  echo ""

  # 4. Final Wait
  wait $PID_DNF;     [ $? -eq 0 ] && success "DNF finished."     || error "DNF failed."
  wait $PID_FLATPAK; [ $? -eq 0 ] && success "Flatpak finished." || warn  "Flatpak failed."
  wait $PID_IDES;    [ $? -eq 0 ] && success "IDEs finished."    || error "IDEs failed."

  # 5. Post-Config
  sudo systemctl enable --now docker
  sudo groupadd -f docker
  sudo usermod -aG docker "$REAL_USER"

  if ! command -v opencode &>/dev/null; then
    info "Installing OpenCode CLI..."
    sudo -u "$REAL_USER" sh -c "curl -fsSL https://opencode.ai/install | bash" &>/dev/null
  fi

  success "Dev environment setup complete!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_devtools
fi
