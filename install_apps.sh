#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

install_apps() {
  print_title "Installing Desktop Applications"
  local REAL_USER="${SUDO_USER:-$USER}"
  local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

  local APPS=(
    "brave-browser"
    "google-chrome-stable"
    "spotify-client"
    "mpv"
    "discord"
  )
  info "Installing ${#APPS[@]} desktop applications..."
  if sudo dnf install -y "${APPS[@]}"; then
    success "Desktop applications installed successfully."
  else
    error "Failed to install desktop applications."
    return 1
  fi
  info "Installing spotify adblock"
  # Check if Rust is available for the USER
  if ! sudo -u "$REAL_USER" sh -c "source $REAL_HOME/.cargo/env && command -v cargo" &>/dev/null; then
    warn "Rust/Cargo not found for user $REAL_USER. Skipping Adblock compilation."
    return 1
  fi
  local BUILD_DIR=$(mktemp -d)
  chown "$REAL_USER:$REAL_USER" "$BUILD_DIR"
  info "Compiling adblock (this may take a moment)..."
  sudo -u "$REAL_USER" bash -c "
    source \"$REAL_HOME/.cargo/env\"
    git clone https://github.com/abba23/spotify-adblock.git \"$BUILD_DIR\"
    cd \"$BUILD_DIR\"
    make
  "
  pushd "$BUILD_DIR" >/dev/null
  if sudo make install; then
     success "Adblock library installed to system."
  else
     error "Adblock compilation failed."
     rm -rf "$BUILD_DIR"
     return 1
  fi
  popd >/dev/null
  rm -rf "$BUILD_DIR"

  local DESKTOP_FILE="$REAL_HOME/.local/share/applications/spotify-adblock.desktop"
  mkdir -p "$(dirname "$DESKTOP_FILE")"
  cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Spotify (Adblock)
GenericName=Music Player
Icon=spotify-client
Exec=env LD_PRELOAD=/usr/local/lib/spotify-adblock.so spotify %U
Terminal=false
Categories=Audio;Music;Player;AudioVideo;
StartupWMClass=spotify
EOF

  chown -R "$REAL_USER:$REAL_USER" "$(dirname "$DESKTOP_FILE")"
  sudo -u "$REAL_USER" update-desktop-database "$REAL_HOME/.local/share/applications"
  success "Spotify Adblock configured successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_apps
fi
