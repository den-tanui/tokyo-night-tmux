#!/usr/bin/env bash

ENABLED=$(tmux show-option -gv @tokyo-night-tmux_show_date 2>/dev/null)
[[ ${ENABLED} -eq 0 ]] && exit 0
[[ ${ENABLED} -ne 1 ]] && ENABLED=$(tmux show-option -gv @tokyo-night-tmux_widget_enabled_date 2>/dev/null)
[[ ${ENABLED} -ne 1 ]] && exit 0

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
. "${ROOT_DIR}/lib/coreutils-compat.sh"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $CURRENT_DIR/themes.sh

date_format=$(tmux show-option -gv @tokyo-night-tmux_date_format 2>/dev/null)
if [[ $date_format == "MDY" ]]; then
  date_string="%m-%d-%Y"
elif [[ $date_format == "DMY" ]]; then
  date_string="%d-%m-%Y"
else
  date_string="%Y-%m-%d"
fi

date_string="$(date +"$date_string")"
echo "$RESET#[fg=${THEME[foreground]},bg=${THEME[bblack]}] $date_string "
