#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/idempotancy_store/os-config/detected_os" ]]; then
    source "$SCRIPT_DIR/idempotancy_store/os-config/detected_os"
fi
declare -A DISTRO_MAP
declare -A PACKAGE_MANAGER_MAP

DISTRO_MAP['arch']='arch'
DISTRO_MAP['fedora']='fedora'
DISTRO_MAP['debian']='debian'

PACKAGE_MANAGER_MAP['arch']='pacman|yay,paru|flatpak,tar'
PACKAGE_MANAGER_MAP['fedora']='dnf|yum,rpm|flatpak,tar'
PACKAGE_MANAGER_MAP['debian']='apt|apt-get,dpkg|flatpak,tar'

export DISTRO_MAP

update_system() {

    case "$PRIMARY_PACKAGE_MANAGER" in
        dnf|yum) $PRIMARY_PACKAGE_MANAGER update -y ;;
        apt) $PRIMARY_PACKAGE_MANAGER update && $PRIMARY_PACKAGE_MANAGER upgrade -y ;;
        pacman) $PRIMARY_PACKAGE_MANAGER -Syu --noconfirm ;;
        *) echo "Unsupported: $PRIMARY_PACKAGE_MANAGER"; return 1 ;;
    esac
}

install_pkg() {
    local packages="$*"

    case "$PRIMARY_PACKAGE_MANAGER" in
        dnf|yum) echo "$PRIMARY_PACKAGE_MANAGER install -y $packages" ;;
        apt) echo "$PRIMARY_PACKAGE_MANAGER install -y $packages" ;;
        pacman) echo "$PRIMARY_PACKAGE_MANAGER -S --noconfirm $packages" ;;
        *) echo "echo 'Unsupported: $PRIMARY_PACKAGE_MANAGER'; return 1" ;;
    esac
}
