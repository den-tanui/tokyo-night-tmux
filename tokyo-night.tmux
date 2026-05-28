#!/usr/bin/env bash
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# title      Tokyo Night                                              +
# version    1.0.0                                                    +
# repository https://github.com/den-tanui/tokyo-night-tmux           +
# author     den-tanui                                                +
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/src"

source $SCRIPTS_PATH/themes.sh
source "$CURRENT_DIR/lib/widget-reorder.sh"

tmux set -g status-left-length 80
tmux set -g status-right-length 150

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
# Highlight colors
tmux set -g mode-style "fg=${THEME[bgreen]},bg=${THEME[bblack]}"

tmux set -g message-style "bg=${THEME[blue]},fg=${THEME[bblack]}"
tmux set -g message-command-style "fg=${THEME[blue]},bg=${THEME[bblack]}"

tmux set -g pane-border-style "fg=${THEME[bblack]}"
tmux set -g pane-active-border-style "fg=${THEME[blue]}"
tmux set -g pane-border-status off

tmux set -g status-style bg="${THEME[background]}"
tmux set -g popup-border-style "fg=${THEME[blue]}"

TMUX_VARS="$(tmux show -g)"

# Reset companion widget flags so only explicitly ordered widgets light up
reset_widget_enabled

default_window_id_style="digital"
default_pane_id_style="hsquare"
default_zoom_id_style="dsquare"

default_terminal_icon=""
default_active_terminal_icon=""

window_id_style="$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_window_id_style' | cut -d" " -f2)"
pane_id_style="$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_pane_id_style' | cut -d" " -f2)"
zoom_id_style="$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_zoom_id_style' | cut -d" " -f2)"
terminal_icon="$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_terminal_icon' | cut -d" " -f2)"
active_terminal_icon="$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_active_terminal_icon' | cut -d" " -f2)"
window_tidy="$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_window_tidy_icons' | cut -d" " -f2)"

window_id_style="${window_id_style:-$default_window_id_style}"
pane_id_style="${pane_id_style:-$default_pane_id_style}"
zoom_id_style="${zoom_id_style:-$default_zoom_id_style}"
terminal_icon="${terminal_icon:-$default_terminal_icon}"
active_terminal_icon="${active_terminal_icon:-$default_active_terminal_icon}"
window_space="${window_tidy:-0}"

window_space=$([[ $window_tidy == "0" ]] && echo " " || echo "")

netspeed="#($SCRIPTS_PATH/netspeed.sh)"
netinfo="#($SCRIPTS_PATH/netinfo.sh)"
netinfo_ssid="#(NETINFO_SHOW=ssid $SCRIPTS_PATH/netinfo.sh)"
netinfo_signal="#(NETINFO_SHOW=signal $SCRIPTS_PATH/netinfo.sh)"
netinfo_privateip="#(NETINFO_SHOW=privateip $SCRIPTS_PATH/netinfo.sh)"
netinfo_publicip="#(NETINFO_SHOW=publicip $SCRIPTS_PATH/netinfo.sh)"
netinfo_dns="#(NETINFO_SHOW=dns $SCRIPTS_PATH/netinfo.sh)"
cmus_status="#($SCRIPTS_PATH/music-tmux-statusbar.sh)"
git_status="#($SCRIPTS_PATH/git-status.sh #{q:pane_current_path})"
wb_git_status="#($SCRIPTS_PATH/wb-git-status.sh #{q:pane_current_path} &)"
window_number="#($SCRIPTS_PATH/custom-number.sh #I $window_id_style)"
custom_pane="#($SCRIPTS_PATH/custom-number.sh #P $pane_id_style)"
zoom_number="#($SCRIPTS_PATH/custom-number.sh #P $zoom_id_style)"
date_and_time="#($SCRIPTS_PATH/datetime-widget.sh)"
date_widget="#($SCRIPTS_PATH/date-widget.sh)"
time_widget="#($SCRIPTS_PATH/time-widget.sh)"
current_path="#($SCRIPTS_PATH/path-widget.sh #{q:pane_current_path})"
battery_status="#($SCRIPTS_PATH/battery-widget.sh)"
hostname="#($SCRIPTS_PATH/hostname-widget.sh)"

#+--- Bars LEFT ---+
# Session name
tmux set -g status-left "#[fg=${THEME[bblack]},bg=${THEME[blue]},bold] #{?client_prefix,󰠠 ,#[dim]󰤂 }#[bold,nodim]#S$hostname "

#+--- Windows ---+
# Focus
tmux set -g window-status-current-format "$RESET#[fg=${THEME[green]},bg=${THEME[bblack]}] #{?#{==:#{pane_current_command},ssh},󰣀 ,  }#[fg=${THEME[foreground]},bold,nodim]$window_number#W#[nobold]#{?window_zoomed_flag, $zoom_number, $custom_pane}#{?window_last_flag, , }"
# Unfocused
tmux set -g window-status-format "$RESET#[fg=${THEME[foreground]}] #{?#{==:#{pane_current_command},ssh},󰣀 ,  }${RESET}$window_number#W#[nobold,dim]#{?window_zoomed_flag, $zoom_number, $custom_pane}#[fg=${THEME[yellow]}]#{?window_last_flag,󰁯  , }"

#+--- Second Status Line (checked early to govern main bar defaults) ---+
SECOND_STATUS=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_second_status' | cut -d" " -f2)

# Auto-enable if widget order lists are set, unless explicitly disabled
if [[ $SECOND_STATUS != "0" ]]; then
  LEFT_SET=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_second_left_widgets' | cut -d" " -f2)
  RIGHT_SET=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_second_right_widgets' | cut -d" " -f2)
  [[ -n $LEFT_SET || -n $RIGHT_SET ]] && SECOND_STATUS=1
fi

if [[ ${SECOND_STATUS} -eq 1 ]] && tmux_version_gte 3.2; then
  tmux set -g status 2

  SECOND_LEFT=$(build_widget_string "show_second_left_widgets")
  SECOND_RIGHT=$(build_widget_string "show_second_right_widgets")

  # Default: path on the left, full netspeed info on the right
  if [[ -z $SECOND_LEFT ]] && [[ -z $SECOND_RIGHT ]]; then
    SECOND_LEFT="$current_path"
    SECOND_RIGHT="$netinfo"
  fi

  if [[ -n $SECOND_LEFT ]] || [[ -n $SECOND_RIGHT ]]; then
    tmux set -g status-format[1] "${RESET}#[align=left]${SECOND_LEFT}#[align=right]${SECOND_RIGHT}"
  fi
fi

#+--- Bars RIGHT ---+
# When the second status line is active, netspeed moves there → exclude from main bar
RIGHT_WIDGETS=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_right_widgets' | cut -d" " -f2)
if [[ -n $RIGHT_WIDGETS ]]; then
  tmux set -g status-right "$(build_widget_string "show_right_widgets")"
else
  MAIN_NETSPEED=""
  MAIN_PATH=""
  [[ ${SECOND_STATUS} -ne 1 ]] && MAIN_NETSPEED="$netspeed" && MAIN_PATH="$current_path"
  tmux set -g status-right "$battery_status${MAIN_PATH}$cmus_status${MAIN_NETSPEED}$git_status$wb_git_status$date_and_time"
fi
tmux set -g window-status-separator ""
