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

# ==============================================================================
# FILE UTILITY FUNCTIONS
# ==============================================================================

# Append data to file (creates file if it doesn't exist)
append_to_file() {
    local file_path="$1"
    local data="$2"
    local create_dirs="${3:-true}"  # Default: create directories if they don't exist

    if [ -z "$file_path" ] || [ -z "$data" ]; then
        error "append_to_file requires: <file_path> <data> [create_dirs]"
        return 1
    fi

    # Create directory structure if needed
    if [ "$create_dirs" = "true" ]; then
        local dir_path
        dir_path="$(dirname "$file_path")"
        mkdir -p "$dir_path"
    fi

    # Append data to file
    echo "$data" >> "$file_path"
    success "Data appended to $file_path"
}

# Write shell variables to file (overwrites existing content)
write_vars_to_file() {
    local file_path="$1"
    shift  # Remove first argument, rest are variable assignments

    if [ -z "$file_path" ]; then
        error "write_vars_to_file requires: <file_path> <var1=value1> [var2=value2] ..."
        return 1
    fi

    # Create directory if needed
    local dir_path
    dir_path="$(dirname "$file_path")"
    mkdir -p "$dir_path"

    # Write header
    cat > "$file_path" << EOF
#!/bin/bash
# Auto-generated file - $(date)
EOF

    # Write each variable
    for var_assignment in "$@"; do
        echo "$var_assignment" >> "$file_path"
    done

    chmod +x "$file_path"
    success "Variables written to $file_path"
}

# Append shell variables to file (preserves existing content)
append_vars_to_file() {
    local file_path="$1"
    shift  # Remove first argument, rest are variable assignments

    if [ -z "$file_path" ]; then
        error "append_vars_to_file requires: <file_path> <var1=value1> [var2=value2] ..."
        return 1
    fi

    # Create directory and file if needed
    local dir_path
    dir_path="$(dirname "$file_path")"
    mkdir -p "$dir_path"

    # Add header if file doesn't exist
    if [ ! -f "$file_path" ]; then
        cat > "$file_path" << EOF
#!/bin/bash
# Auto-generated file - $(date)
EOF
        chmod +x "$file_path"
    fi

    # Add timestamp comment
    echo "" >> "$file_path"
    echo "# Added $(date)" >> "$file_path"

    # Append each variable
    for var_assignment in "$@"; do
        echo "$var_assignment" >> "$file_path"
    done

    success "Variables appended to $file_path"
}

# Write associative array to file
write_array_to_file() {
    local file_path="$1"
    local array_name="$2"
    local -n array_ref="$2"  # Name reference to the array

    if [ -z "$file_path" ] || [ -z "$array_name" ]; then
        error "write_array_to_file requires: <file_path> <array_name>"
        return 1
    fi

    # Create directory if needed
    local dir_path
    dir_path="$(dirname "$file_path")"
    mkdir -p "$dir_path"

    # Write array to file
    cat > "$file_path" << EOF
#!/bin/bash
# Array cache file - Generated $(date)
declare -A $array_name
EOF

    # Write array elements
    for key in "${!array_ref[@]}"; do
        echo "${array_name}['$key']=\"${array_ref[$key]}\"" >> "$file_path"
    done

    chmod +x "$file_path"
    success "Array $array_name written to $file_path"
}

# Check if file exists and source it, with optional validation
source_if_exists() {
    local file_path="$1"
    local max_age_hours="${2:-24}"  # Default: consider file valid for 24 hours

    if [ ! -f "$file_path" ]; then
        warn "File $file_path does not exist"
        return 1
    fi

    # Check file age if max_age_hours is specified
    if [ "$max_age_hours" != "0" ]; then
        local file_age_hours
        if command -v stat >/dev/null 2>&1; then
            # Linux/GNU stat
            file_age_hours=$(( ($(date +%s) - $(stat -c %Y "$file_path")) / 3600 ))
        else
            # macOS/BSD stat
            file_age_hours=$(( ($(date +%s) - $(stat -f %m "$file_path")) / 3600 ))
        fi

        if [ "$file_age_hours" -gt "$max_age_hours" ]; then
            warn "File $file_path is $file_age_hours hours old (max: $max_age_hours)"
            return 2  # File exists but is too old
        fi
    fi

    source "$file_path"
    info "Sourced $file_path"
    return 0
}

# Interactive menu function using fzf
# Parameters:
#   $1 - array of choices (passed as array name)
#   $2 - boolean flag for multi-select (true/false, default: false)
# Returns: selected choice(s) as space-separated string
interactive_menu() {
    local choices_array_name="$1"
    local multi_select="${2:-false}"
    local -n choices_ref="$choices_array_name"

    if [ -z "$choices_array_name" ]; then
        error "interactive_menu requires: <choices_array_name> [multi_select]"
        return 1
    fi

    # Check if fzf is available
    if ! command -v fzf >/dev/null 2>&1; then
        error "fzf is not installed. Please install fzf to use interactive menu."
        return 1
    fi

    # Convert array to fzf input
    local fzf_input=""
    for choice in "${choices_ref[@]}"; do
        fzf_input+="$choice"$'\n'
    done

    # Build fzf command
    local fzf_cmd="fzf --height=40% --border"

    if [ "$multi_select" = "true" ]; then
        fzf_cmd+=" --multi --bind=tab:toggle"
        info "Use Tab to select/deselect multiple options, Enter to confirm"
    else
        info "Use arrow keys to navigate, Enter to select"
    fi

    # Execute fzf and capture selection
    local selection
    selection=$(echo -e "$fzf_input" | eval "$fzf_cmd")

    if [ -z "$selection" ]; then
        warn "No selection made"
        return 1
    fi

    # Convert newlines to spaces for return value
    echo "$selection" | tr '\n' ' '
}
