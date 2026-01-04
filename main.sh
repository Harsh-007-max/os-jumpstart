#!/bin/bash
# Master Setup Script for Fedora 43 SDE Environment
# Usage: ./main.sh

# 1. Robust Directory Detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

main() {
  print_title "Starting Fedora 43 System Setup"

  # 2. Sudo Keep-Alive
  # Ask for password once, then refresh the timestamp in the background
  # so the script doesn't pause for passwords later.
  if sudo -v; then
      while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
      success "Sudo privileges acquired."
  else
      error "Sudo privileges required to run this script."
      exit 1
  fi

  # 3. Define Scripts (Using your specific filenames)
  local scripts_to_run=(
    "install_fedora_repos.sh"
    "install_zsh.sh"
    "install_languages.sh"
    "install_utils.sh"
    "install_apps.sh"
    "install_devtools.sh"
    "install_db.sh"
    "optimize_system.sh"
    "setswap_fedora.sh"
    "setup_git.sh"
    "kesl.sh"
  )

  # 4. Execution Loop
  for script in "${scripts_to_run[@]}"; do
    local script_path="$SCRIPT_DIR/$script"

    if [ -f "$script_path" ]; then
      print_title "Executing ${script}..."
      chmod +x "$script_path"

      # Run the script
      if [[ "$script" == "setswap_fedora.sh" ]]; then
        # Explicit sudo for swap script with arguments
        sudo "$script_path" --set 16G
      elif [[ "$script" == "kesl.sh" ]]; then
        sudo "$script_path" --install
      else
        # Run standard script
        "$script_path"
      fi

      # Check for failure (Exit immediately if a core script fails)
      if [ $? -ne 0 ]; then
        error "Script ${script} failed! Aborting."
        exit 1
      fi
    else
      warn "Script not found: $script"
    fi
    echo ""
    sleep 1
  done

  print_title "Fedora 43 System Setup Complete!"
  info "Please reboot your system for all changes (Docker group, Zsh, Swap) to take effect."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
