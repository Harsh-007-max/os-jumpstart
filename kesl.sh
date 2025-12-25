#!/bin/bash

# manage_kaspersky.sh - Install/Uninstall Kaspersky Endpoint Security for Linux
# Usage: sudo ./manage_kaspersky.sh [--install | --uninstall]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source shared functions, but fallback to simple colors if missing
if [ -f "$SCRIPT_DIR/shared_functions.sh" ]; then
    source "$SCRIPT_DIR/shared_functions.sh"
else
    # Simple fallback definitions if shared_functions.sh is missing
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
    print_title() { echo -e "\n${GREEN}=== $1 ===${NC}"; }
    info() { echo -e "${NC} -> $1"; }
    success() { echo -e "${GREEN} -> [SUCCESS] $1${NC}"; }
    warn() { echo -e "${YELLOW} -> [WARN] $1${NC}"; }
    error() { echo -e "${RED} -> [ERROR] $1${NC}"; }
fi

# --- Check Root ---
if [ "$EUID" -ne 0 ]; then
    print_title "Error"
    error "This script requires sudo privileges."
    echo "Usage: sudo $0"
    exit 1
fi

# --- FUNCTION: INSTALL ---
install_kesl() {
    print_title "Installing Kaspersky Endpoint Security"

    local REAL_USER="${SUDO_USER:-$USER}"
    local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

    # 1. Locate RPMs (Strict Regex to avoid duplicates)
    info "Looking for RPM files in current directory..."
    
    # Core: Matches 'kesl-' followed immediately by a digit (e.g. kesl-12.3...)
    # This prevents it from accidentally matching 'kesl-gui'
    local CORE_RPM=$(find "$SCRIPT_DIR" -maxdepth 1 -name "kesl-[0-9]*.x86_64.rpm" | head -n 1)
    
    # GUI: Matches 'kesl-gui-' specifically
    local GUI_RPM=$(find "$SCRIPT_DIR" -maxdepth 1 -name "kesl-gui-*.x86_64.rpm" | head -n 1)

    # Debug Output
    if [[ -n "$CORE_RPM" ]]; then
        success "Found Core: $(basename "$CORE_RPM")"
    else
        error "Core RPM (kesl-[version].rpm) NOT found!"
    fi

    if [[ -n "$GUI_RPM" ]]; then
        success "Found GUI:  $(basename "$GUI_RPM")"
    else
        error "GUI RPM (kesl-gui-[version].rpm) NOT found!"
    fi

    if [[ -z "$CORE_RPM" || -z "$GUI_RPM" ]]; then
        error "Missing files. You need both RPMs in this folder:"
        echo "  1. kesl-12.x.x...x86_64.rpm"
        echo "  2. kesl-gui-12.x.x...x86_64.rpm"
        return 1
    fi

    # 2. Install Packages
    info "Installing packages via DNF..."
    if dnf install -y "$CORE_RPM" "$GUI_RPM"; then
        success "RPMs installed successfully."
    else
        error "DNF installation failed."
        return 1
    fi

    # 3. Post-Install Setup
    print_title "Kaspersky Configuration"
    warn "IMPORTANT: When asked to 'configure SELinux automatically', answer NO (n)."
    warn "We will configure it manually to avoid Fedora-specific errors."
    echo "Press Enter to start configuration..."
    read
    
    /opt/kaspersky/kesl/bin/kesl-setup.pl

    # 4. Manual SELinux Fixes
    info "Applying manual SELinux context fixes..."
    
    # Check if semanage exists, install if not
    if ! command -v semanage &>/dev/null; then
        info "Installing policycoreutils-python-utils (semanage)..."
        dnf install -y policycoreutils-python-utils
    fi

    local CONTEXTS=(
        "/opt/kaspersky/kesl/libexec/kesl:kesl_exec_t"
        "/opt/kaspersky/kesl/bin/kesl-control:kesl_control_exec_t"
        "/opt/kaspersky/kesl/shared/kesl:kesl_control_exec_t"
        "/opt/kaspersky/kesl/libexec/kesl-gui:kesl_control_exec_t"
    )

    for entry in "${CONTEXTS[@]}"; do
        path="${entry%%:*}"
        ctx="${entry##*:}"
        # Only apply if path exists
        if [ -e "$path" ]; then
             semanage fcontext -a -t "$ctx" "$path" 2>/dev/null || true
        fi
    done
    
    info "Restoring file contexts (restorecon)..."
    restorecon -Rv /opt/kaspersky/kesl &>/dev/null
    success "SELinux contexts applied."

    # 5. Create Desktop Shortcut (Wayland Fix)
    info "Creating Wayland-compatible desktop shortcut..."
    local APP_DIR="$REAL_HOME/.local/share/applications"
    mkdir -p "$APP_DIR"
    chown "$REAL_USER:$REAL_USER" "$APP_DIR"

    local DESKTOP_FILE="$APP_DIR/kesl-gui.desktop"
    
    cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Kaspersky Endpoint Security
GenericName=Antivirus
Comment=Kaspersky Security for Linux
# Fixes: Library paths and Wayland visibility (xcb)
Exec=env LD_LIBRARY_PATH=/opt/kaspersky/kesl/lib64:/opt/kaspersky/kesl/shared/lib QT_QPA_PLATFORM=xcb /opt/kaspersky/kesl/libexec/kesl-gui
Icon=kesl
Terminal=false
Type=Application
Categories=System;Security;
Keywords=antivirus;security;kesl;
StartupNotify=true
EOF

    chown "$REAL_USER:$REAL_USER" "$DESKTOP_FILE"
    
    # 6. Fix Icon
    info "Setting up application icon..."
    local ICON_SRC=$(find /opt/kaspersky -name "logo.png" 2>/dev/null | head -n 1)
    if [[ -n "$ICON_SRC" ]]; then
        cp "$ICON_SRC" /usr/share/pixmaps/kesl.png
    fi

    print_title "Installation Complete"
    success "Kaspersky installed. Find it in your application menu."
    info "If it fails to start, verify SELinux is not blocking it (check 'sudo audit2allow -a')."
}

# --- FUNCTION: UNINSTALL ---
uninstall_kesl() {
    print_title "Uninstalling Kaspersky"

    local REAL_USER="${SUDO_USER:-$USER}"
    local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

    # 1. Remove Packages
    info "Removing RPM packages..."
    dnf remove -y kesl kesl-gui
    dnf autoremove -y

    # 2. Remove SELinux Contexts
    info "Removing SELinux rules..."
    if command -v semanage &>/dev/null; then
        semanage fcontext -d -t kesl_exec_t "/opt/kaspersky/kesl/libexec/kesl" 2>/dev/null || true
        semanage fcontext -d -t kesl_control_exec_t "/opt/kaspersky/kesl/bin/kesl-control" 2>/dev/null || true
    fi

    # 3. Clean Directories
    info "Cleaning residue files..."
    rm -rf /opt/kaspersky
    rm -rf /var/opt/kaspersky
    rm -rf /var/log/kaspersky
    rm -rf /var/lib/kesl

    # 4. Remove Shortcut
    local DESKTOP_FILE="$REAL_HOME/.local/share/applications/kesl-gui.desktop"
    if [[ -f "$DESKTOP_FILE" ]]; then
        info "Removing desktop shortcut..."
        rm -f "$DESKTOP_FILE"
    fi

    # 5. Check SELinux Mode
    local CURRENT_MODE=$(getenforce)
    if [[ "$CURRENT_MODE" == "Permissive" ]]; then
        warn "System is currently in Permissive mode."
        read -p "  -> Do you want to re-enable Enforcing mode? [y/N]: " REVERT_SE
        if [[ "$REVERT_SE" =~ ^[Yy]$ ]]; then
            setenforce 1
            sed -i 's/^SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
            success "SELinux set back to Enforcing."
        fi
    fi

    success "Uninstallation Complete."
}

# --- MAIN MENU ---
if [ "$1" == "--install" ]; then
    install_kesl
elif [ "$1" == "--uninstall" ]; then
    uninstall_kesl
else
    print_title "Kaspersky Manager"
    echo "1) Install"
    echo "2) Uninstall"
    echo "3) Exit"
    echo ""
    read -p "Select option: " CHOICE
    case $CHOICE in
        1) install_kesl ;;
        2) uninstall_kesl ;;
        3) exit 0 ;;
        *) error "Invalid option." ;;
    esac
fi
