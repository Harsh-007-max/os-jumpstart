#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"
source "$SCRIPT_DIR/idempotancy_store/distro_config.sh"

detect_package_managers() {
  local base_distro="$1"
  local pkg_managers="${PACKAGE_MANAGER_MAP[$base_distro]:-}"
  local detected_managers=()
  local old_ifs=$IFS
  if [ -n "$pkg_managers" ]; then
    # Split by | to get priority levels
    IFS='|' read -ra priority_levels <<<"$pkg_managers"

    for level in "${priority_levels[@]}"; do
      # Split each level by , to get individual managers
      IFS=',' read -ra managers_in_level <<<"$level"

      for manager in "${managers_in_level[@]}"; do
        if command -v "$manager" >/dev/null 2>&1; then
          detected_managers+=("$manager")
        fi
      done
    done
  fi
  IFS=$old_ifs
  # Return space-separated list of detected managers
  echo "${detected_managers[*]}"
}

get_base_distro() {
  local cache_file="$SCRIPT_DIR/idempotancy_store/os-config/detected_os"
  ID=""
  ID_LIKE=""
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    success "[Success]: Found os-release $ID - $ID_LIKE"
  else
    error "[Error]: Unable to find os-release"
    return 1
  fi

  DISTRO_INFO="$ID $ID_LIKE"
  for key in "${!DISTRO_MAP[@]}"; do
    if [[ $DISTRO_INFO == *"$key"* ]]; then
      BASE_DISTRO="${DISTRO_MAP[$key]}"
      local available_pkg_managers=$(detect_package_managers "$BASE_DISTRO")
      local primary_manager=$(get_best_available_manager "$BASE_DISTRO")
      success "[Success]: Mapped to base distro: $BASE_DISTRO"

      write_vars_to_file "$cache_file" \
        "DISTRO_ID='$ID'" \
        "BASE_DISTRO='$BASE_DISTRO'" \
        "DISTRO_INFO='$DISTRO_INFO'" \
        "AVAILABLE_PACKAGE_MANAGERS='$available_pkg_managers'" \
        "DISTRO_DETECTED_AT='$(date +%s)'" \
        "PRIMARY_PACKAGE_MANAGER='$primary_manager'"

      echo "$BASE_DISTRO"
      return 0
    fi
  done
  error "[Error]: Unknown distro $DISTRO_INFO"
  echo "unknown"
  return 1
}

get_managers_by_priority() {
  local base_distro="$1"
  local priority_level="$2" # 0, 1, 2, etc.
  local pkg_managers="${PACKAGE_MANAGER_MAP[$base_distro]:-}"

  if [ -n "$pkg_managers" ]; then
    IFS='|' read -ra priority_levels <<<"$pkg_managers"
    if [ "$priority_level" -lt "${#priority_levels[@]}" ]; then
      echo "${priority_levels[$priority_level]}"
    fi
  fi
}
# Get highest priority available manager
get_best_available_manager() {
  local base_distro="$1"
  local pkg_managers="${PACKAGE_MANAGER_MAP[$base_distro]:-}"

  if [ -n "$pkg_managers" ]; then
    IFS='|' read -ra priority_levels <<<"$pkg_managers"

    for level in "${priority_levels[@]}"; do
      IFS=',' read -ra managers_in_level <<<"$level"

      for manager in "${managers_in_level[@]}"; do
        if command -v "$manager" >/dev/null 2>&1; then
          echo "$manager"
          return 0
        fi
      done
    done
  fi

  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  get_base_distro
fi
