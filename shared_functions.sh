#!/bin/bash

# ==============================================================================
# Script: shared_functions.sh
# Description: Contains common functions and settings for multi-script installations.
# ==============================================================================

set -e
set -u
set -o pipefail

if command -v tput >/dev/null 2>&1 && [[ $(tput colors) -ge 8 ]]; then
    COLOR_RESET=$(tput sgr0)
    COLOR_GREEN=$(tput setaf 2)
    COLOR_YELLOW=$(tput setaf 3)
    COLOR_BLUE=$(tput setaf 4)
    COLOR_RED=$(tput setaf 1)
    BOLD=$(tput bold)
else
    COLOR_RESET=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_RED=""
    BOLD=""
fi

info() {
    echo "${COLOR_BLUE}${BOLD}==>${COLOR_RESET}${BOLD} $1${COLOR_RESET}"
}

success() {
    echo "${COLOR_GREEN} ✓ ${COLOR_RESET} $1"
}

warn() {
    echo "${COLOR_YELLOW} ! ${COLOR_RESET} $1"
}

error() {
    echo "${COLOR_RED} ❌ ERROR: ${COLOR_RESET} $1" >&2
    exit 1
}

print_title() {
    if [[ -z "$1" ]]; then
        error "print_title function requires a title string as an argument."
    fi
    local title_text="   $1   "
    local title_len=${#title_text}
    local border
    border=$(printf '%*s' "$title_len" '' | tr ' ' '=')

    echo ""
    echo "${BOLD}${COLOR_YELLOW}${border}${COLOR_RESET}"
    echo "${BOLD}${COLOR_YELLOW}${title_text}${COLOR_RESET}"
    echo "${BOLD}${COLOR_YELLOW}${border}${COLOR_RESET}"
    echo ""
}

