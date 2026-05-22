#!/usr/bin/env bash

# Build a status string from a comma-separated widget list option
# Usage: build_widget_string <option_suffix>
#   e.g. build_widget_string "show_right_widgets" reads @tokyo-night-tmux_show_right_widgets
#
# Known widget names are mapped to their predefined #() substitution strings.
# Entries starting with #( or #{ are passed through verbatim (arbitrary commands/format vars).
# Entries starting with #[ are passed through verbatim (tmux format attributes).
# Unknown widget names are silently skipped.
# Empty items in the list are silently skipped.
function build_widget_string() {
  local option_name="@tokyo-night-tmux_$1"
  local list
  list=$(echo "$TMUX_VARS" | grep "${option_name}" | sed 's/^[^ ]* //')
  [[ -z $list ]] && return

  local result=""
  local saved_ifs="$IFS"
  IFS=','
  for item in $list; do
    # Trim leading/trailing whitespace
    item="$(echo "$item" | xargs)"
    # Skip empty items
    [[ -z $item ]] && continue
    if [[ $item == "#("* ]] || [[ $item == "#{"* ]] || [[ $item == "#["* ]]; then
      # Passthrough — user-supplied tmux command, format variable, or attribute
      result+="$item"
    else
      case "$item" in
      battery) result+="$battery_status" ;;
      path) result+="$current_path" ;;
      music) result+="$cmus_status" ;;
      netspeed) result+="$netspeed" ;;
      git) result+="$git_status" ;;
      wbg) result+="$wb_git_status" ;;
      datetime) result+="$date_and_time" ;;
      hostname) result+="$hostname" ;;
      esac
    fi
  done
  IFS="$saved_ifs"
  echo "$result"
}

# Check if tmux version is >= a minimum version
# Usage: tmux_version_gte <major.minor>
#   e.g. tmux_version_gte 3.2  →  returns 0 if tmux >= 3.2
function tmux_version_gte() {
  local target="$1"
  local tmux_ver
  tmux_ver=$(tmux -V 2>/dev/null | sed 's/[^0-9.]//g' | cut -d. -f1-2)
  [[ -z $tmux_ver ]] && return 1
  [[ $(echo "$tmux_ver >= $target" | bc) -eq 1 ]]
}
