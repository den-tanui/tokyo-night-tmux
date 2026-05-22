#!/usr/bin/env bash

ENABLED=$(tmux show-option -gv @tokyo-night-tmux_show_time 2>/dev/null)
[[ ${ENABLED} -eq 0 ]] && exit 0
[[ ${ENABLED} -ne 1 ]] && ENABLED=$(tmux show-option -gv @tokyo-night-tmux_widget_enabled_time 2>/dev/null)
[[ ${ENABLED} -ne 1 ]] && exit 0

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
. "${ROOT_DIR}/lib/coreutils-compat.sh"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $CURRENT_DIR/themes.sh

time_format=$(tmux show-option -gv @tokyo-night-tmux_time_format 2>/dev/null)
if [[ $time_format == "12H" ]]; then
  time_string="%I:%M %p"
else
  time_string="%H:%M"
fi

time_string="$(date +"$time_string")"
echo "$RESET#[fg=${THEME[foreground]},bg=${THEME[bblack]}] $time_string "
