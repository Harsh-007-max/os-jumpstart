#!/bin/bash

# setswap_fedora.sh - Manage swap file on Fedora (Disables ZRAM & Handles Btrfs)
# Usage: sudo ./setswap_fedora.sh --set 16G

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

setup_swap() {
    local SIZE="$1"
    
    # 1. Detect Real User Home (Avoid putting swap in /root/)
    local REAL_USER="${SUDO_USER:-$USER}"
    local REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    local SWAPFILE="$REAL_HOME/swapfile"

    print_title "Configuring System Swap"

    if [ -z "$SIZE" ]; then
        error "Usage: $0 --set <SIZE> (e.g., 16G)"
        return 1
    fi
    
    # 2. Disable ZRAM (Fedora Default)
    # ZRAM compresses RAM to use as swap. It's good for low-RAM devices, 
    # but for heavy dev work (Docker/IntelliJ), a real swapfile is often more stable.
    info "Disabling ZRAM to prioritize disk swap..."
    
    if swapoff /dev/zram0 2>/dev/null; then
        info "ZRAM swap turned off."
    fi
    
    # Disable the generator so it doesn't come back on reboot
    if [ -d "/etc/systemd/zram-generator.conf.d" ]; then
        echo -e "[zram0]\nzram-size = 0" > /etc/systemd/zram-generator.conf.d/disable-zram.conf
        success "ZRAM persistently disabled via config."
    else
        # If the directory doesn't exist, maybe zram-generator isn't installed.
        # We create it anyway to be safe.
        mkdir -p /etc/systemd/zram-generator.conf.d
        echo -e "[zram0]\nzram-size = 0" > /etc/systemd/zram-generator.conf.d/disable-zram.conf
    fi

    # 3. Clean up old swapfile
    if [ -f "$SWAPFILE" ]; then
        warn "Existing swapfile found at $SWAPFILE. Removing..."
        swapoff "$SWAPFILE" 2>/dev/null
        rm -f "$SWAPFILE"
    fi

    # 4. Create new Swapfile (Btrfs Safe Mode)
    info "Creating $SIZE swapfile at $SWAPFILE..."
    
    # Create empty file
    touch "$SWAPFILE"
    
    # CRITICAL: Disable Copy-on-Write (CoW) for Btrfs
    # Must be done on an empty 0-byte file before writing data.
    chattr +C "$SWAPFILE"
    
    # Calculate blocks
    local SIZE_NUM=$(echo "$SIZE" | sed 's/[^0-9]*//g')
    local COUNT
    if [[ "$SIZE" == *"G" ]]; then 
        COUNT=$(( SIZE_NUM * 1024 ))
    else 
        COUNT=$SIZE_NUM
    fi

    # Allocate space (using dd is safer for ensuring allocation than fallocate on some FS)
    dd if=/dev/zero of="$SWAPFILE" bs=1M count="$COUNT" status=progress

    # 5. secure and Activate
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"
    
    # 6. Persist in fstab
    if ! grep -q "$SWAPFILE" /etc/fstab; then
        # Back up fstab first
        cp /etc/fstab /etc/fstab.bak
        echo "$SWAPFILE none swap defaults 0 0" >> /etc/fstab
        success "Swapfile added to /etc/fstab."
    else
        info "Swapfile entry already exists in fstab."
    fi
    
    success "Swap configuration complete. Current Swap Status:"
    swapon --show
}

# Ensure Root
if [ "$EUID" -ne 0 ]; then
    print_title "Error"
    echo "This script requires sudo privileges."
    exit 1
fi

if [ "$1" == "--set" ]; then
    setup_swap "$2"
else
    echo "Usage: sudo ./setswap_fedora.sh --set 16G"
fi
