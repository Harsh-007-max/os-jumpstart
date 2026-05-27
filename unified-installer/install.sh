#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

main() {
  print_title "Starting Installer..."

  if sudo -v; then
      while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
      success "Sudo privileges acquired."
  else
      error "Sudo privileges required to run this script."
      exit 1
  fi
  declare -A scripts_to_run=(
    ["os-config.sh"]=true
    ["update_os.sh"]=true
    ["install_shell.sh"]=true
  )
  for script in "${!scripts_to_run[@]}"; do
      local script_path="$SCRIPT_DIR/$script"
      local needs_sudo=${scripts_to_run[$script]}
      if [[ -f "$script_path" ]]; then
          if [[ "$needs_sudo" == "true" ]]; then
              sudo "$script_path"
          else
              "$script_path"
          fi
      else
          error "Script not found: $script"
          exit 1
      fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
