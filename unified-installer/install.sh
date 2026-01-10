#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

main() {
  print "Starting Installer..."

  if sudo -v; then
    while true; do
      sudo -n true
      sleep 60
      kill -0 "$$" || exit
    done 2>/dev/null &
    success "Sudo privileges acquired."
  else
    error "Sudo privileges required to run this script."
    exit 1
  fi
}
