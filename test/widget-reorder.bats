#!/usr/bin/env bats

# shellcheck source=lib/widget-reorder.sh
source "${BATS_TEST_DIRNAME}/../lib/widget-reorder.sh"

setup() {
  # Mock TMUX_VARS as it would appear from "tmux show -g"
  export TMUX_VARS="
@tokyo-night-tmux_show_right_widgets path, git, netspeed
@tokyo-night-tmux_window_id_style digital
@tokyo-night-tmux_show_git 1
"

  # Mock widget #() substitution strings (same format as in tokyo-night.tmux)
  export battery_status="#(${BATS_TEST_DIRNAME}/../src/battery-widget.sh)"
  export current_path="#(${BATS_TEST_DIRNAME}/../src/path-widget.sh #{pane_current_path})"
  export cmus_status="#(${BATS_TEST_DIRNAME}/../src/music-tmux-statusbar.sh)"
  export netspeed="#(${BATS_TEST_DIRNAME}/../src/netspeed.sh)"
  export git_status="#(${BATS_TEST_DIRNAME}/../src/git-status.sh #{pane_current_path})"
  export wb_git_status="#(${BATS_TEST_DIRNAME}/../src/wb-git-status.sh #{pane_current_path} &)"
  export date_and_time="#(${BATS_TEST_DIRNAME}/../src/datetime-widget.sh)"
  export hostname="#(${BATS_TEST_DIRNAME}/../src/hostname-widget.sh)"
  export netinfo="#(${BATS_TEST_DIRNAME}/../src/netinfo.sh)"
  export netinfo_ssid="#(NETINFO_SHOW=ssid ${BATS_TEST_DIRNAME}/../src/netinfo.sh)"
  export netinfo_signal="#(NETINFO_SHOW=signal ${BATS_TEST_DIRNAME}/../src/netinfo.sh)"
  export netinfo_privateip="#(NETINFO_SHOW=privateip ${BATS_TEST_DIRNAME}/../src/netinfo.sh)"
  export netinfo_publicip="#(NETINFO_SHOW=publicip ${BATS_TEST_DIRNAME}/../src/netinfo.sh)"
  export netinfo_dns="#(NETINFO_SHOW=dns ${BATS_TEST_DIRNAME}/../src/netinfo.sh)"
}

@test "build_widget_string returns empty for unset option" {
  run build_widget_string "show_nonexistent"
  [[ -z $output ]]
}

@test "build_widget_string returns single widget" {
  # Override TMUX_VARS with a single-widget list
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets git"
  run build_widget_string "show_right_widgets"
  [[ $output == "$git_status" ]]
}

@test "build_widget_string returns widgets in specified order" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets datetime, git, battery"
  run build_widget_string "show_right_widgets"
  [[ $output == "${date_and_time}${git_status}${battery_status}" ]]
}

@test "build_widget_string trims whitespace around widget names" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets  path ,  netspeed  ,  hostname  "
  run build_widget_string "show_right_widgets"
  [[ $output == "${current_path}${netspeed}${hostname}" ]]
}

@test "build_widget_string passes through #() commands verbatim" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets #(~/.tmux/foo.sh arg1 arg2)"
  run build_widget_string "show_right_widgets"
  [[ $output == "#(~/.tmux/foo.sh arg1 arg2)" ]]
}

@test "build_widget_string passes through #{ format vars verbatim" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets #{session_name}, #{pane_current_command}"
  run build_widget_string "show_right_widgets"
  [[ $output == "#{session_name}#{pane_current_command}" ]]
}

@test "build_widget_string passes through #[ format attributes verbatim" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets #[fg=red]●, #[bold]text"
  run build_widget_string "show_right_widgets"
  [[ $output == "#[fg=red]●#[bold]text" ]]
}

@test "build_widget_string mixes known widgets and passthrough entries" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets git, #(curl -s http://status), datetime"
  run build_widget_string "show_right_widgets"
  [[ $output == "${git_status}#(curl -s http://status)${date_and_time}" ]]
}

@test "build_widget_string ignores unknown widget names silently" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets git, nonexistent_widget, datetime"
  run build_widget_string "show_right_widgets"
  [[ $output == "${git_status}${date_and_time}" ]]
}

@test "build_widget_string handles empty list item gracefully" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets git, , datetime"
  run build_widget_string "show_right_widgets"
  [[ $output == "${git_status}${date_and_time}" ]]
}

@test "build_widget_string works with show_second_left_widgets option name" {
  export TMUX_VARS="@tokyo-night-tmux_show_second_left_widgets ssid, signal"
  run build_widget_string "show_second_left_widgets"
  [[ $output == "${netinfo_ssid}${netinfo_signal}" ]]
}

@test "build_widget_string works with show_second_right_widgets option name" {
  export TMUX_VARS="@tokyo-night-tmux_show_second_right_widgets git, netspeed"
  run build_widget_string "show_second_right_widgets"
  [[ $output == "${git_status}${netspeed}" ]]
}

@test "build_widget_string resolves monolithic netinfo" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets netinfo"
  run build_widget_string "show_right_widgets"
  [[ $output == "$netinfo" ]]
}

@test "build_widget_string resolves netinfo sub-items" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets dns, publicip, ssid"
  run build_widget_string "show_right_widgets"
  [[ $output == "${netinfo_dns}${netinfo_publicip}${netinfo_ssid}" ]]
}

@test "build_widget_string mixes netspeed and netinfo sub-items" {
  export TMUX_VARS="@tokyo-night-tmux_show_right_widgets netspeed, dns, privateip"
  run build_widget_string "show_right_widgets"
  [[ $output == "${netspeed}${netinfo_dns}${netinfo_privateip}" ]]
}

@test "tmux_version_gte returns true for versions below installed" {
  run tmux_version_gte "0.8"
  [[ $status -eq 0 ]]
}

@test "tmux_version_gte returns false for versions above installed" {
  run tmux_version_gte "99.0"
  [[ $status -eq 1 ]]
}
