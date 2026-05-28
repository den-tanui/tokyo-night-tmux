#!/usr/bin/env bash
#<------------------------------Netspeed widget for TMUX------------------------------------>
# Shows only network RX/TX speed (no interface name, no network info)
#<------------------------------------------------------------------------------------------>

# Check if enabled
ENABLED=$(tmux show-option -gv @tokyo-night-tmux_show_netspeed 2>/dev/null)
[[ "${ENABLED}" == "0" ]] && exit 0
[[ ${ENABLED} -ne 1 ]] && ENABLED=$(tmux show-option -gv @tokyo-night-tmux_widget_enabled_netspeed 2>/dev/null)
[[ ${ENABLED} -ne 1 ]] && exit 0

# Imports
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source "$ROOT_DIR/src/themes.sh"
source "$ROOT_DIR/lib/netspeed.sh"

# Get network interface
INTERFACE=$(tmux show-option -gv @tokyo-night-tmux_netspeed_iface 2>/dev/null)
TIME_DIFF=$(tmux show-option -gv @tokyo-night-tmux_netspeed_refresh 2>/dev/null)
TIME_DIFF=${TIME_DIFF:-1}

# Determine interface if not set
if [[ -z $INTERFACE ]]; then
  INTERFACE=$(find_interface)
  [[ -z $INTERFACE ]] && exit 1
  tmux set-option -g @tokyo-night-tmux_netspeed_iface "$INTERFACE"
fi

# Echo network speed
read -r RX1 TX1 < <(get_bytes "$INTERFACE")
sleep "$TIME_DIFF"
read -r RX2 TX2 < <(get_bytes "$INTERFACE")

RX_DIFF=$((RX2 - RX1))
TX_DIFF=$((TX2 - TX1))

RX_SPEED="$(readable_format "$RX_DIFF" "$TIME_DIFF")"
TX_SPEED="$(readable_format "$TX_DIFF" "$TIME_DIFF")"

echo "${RESET}░ #[fg=${THEME[bgreen]}]\U000f06f4#[fg=${THEME[foreground]}] $RX_SPEED #[fg=${THEME[bblue]}]\U000f06f6#[fg=${THEME[foreground]}] $TX_SPEED "
