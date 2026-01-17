#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

select_option() {
    # Single select
    tool_category=("Dev-Tools" "Cli-Tools" "Gui-Applications" "Programming-Language")
    selected_tool_category=$(interactive_menu tool_category)

    echo "Selected option: $selected_tool_category"
    # Multi-select
    tools_to_install=("Choice A" "Choice B" "Choice C" "Choice D")
    selected=$(interactive_menu tools_to_install true)

    echo "Selected options: $selected"

}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    select_option
fi
