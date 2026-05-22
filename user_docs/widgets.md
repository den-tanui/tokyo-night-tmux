# Widgets

[← Back to README](../README.md) · [Installation →](installation.md) · [Themes →](themes.md) · [Customization →](customization.md)

---

Widgets appear in the tmux status bar. There are two ways to enable them:

1. **Widget order lists** (recommended) — add widgets to a comma-separated list
   in the correct position. Being in the list **auto-enables** the widget.
2. **Individual toggles** — set `@tokyo-night-tmux_show_<name> 1` per widget.

Both approaches work together. A widget shows if either method enables it.
Setting `@tokyo-night-tmux_show_<name> 0` is a hard opt-out that overrides
any order list.

---

## Widget order & second status bar

Instead of individual `_show_*` flags, you can define widget layout with three
options:

```bash
# Main status bar (right side)
set -g @tokyo-night-tmux_show_right_widgets "battery,git,datetime"

# Second status bar — left and right halves (tmux ≥ 3.2, auto-enabled)
set -g @tokyo-night-tmux_show_second_left_widgets "path"
set -g @tokyo-night-tmux_show_second_right_widgets "music,netspeed"
```

### Available widget names

| Name | Widget | `_show_*` option | Notes |
|---|---|---|---|
| `battery` | Battery | `_show_battery_widget` | |
| `path` | Path | `_show_path` | |
| `music` | Now Playing | `_show_music` | |
| `netspeed` | Netspeed | `_show_netspeed` | |
| `git` | Git status | `_show_git` | |
| `wbg` | GitHub/GitLab | `_show_wbg` | |
| `datetime` | Date & Time | `_show_datetime` | |
| `date` | Date only | `_show_date` | |
| `time` | Time only | `_show_time` | |
| `hostname` | Hostname | `_show_hostname` | |

### Second status bar

When `@tokyo-night-tmux_show_second_left_widgets` or
`@tokyo-night-tmux_show_second_right_widgets` is set, the second status bar is
**automatically enabled** (no need for a separate flag). Requires tmux ≥ 3.2.

Set `@tokyo-night-tmux_show_second_status 0` to explicitly disable it.

### Custom passthrough entries

Widget order lists support tmux format variables and arbitrary `#()` commands:

```bash
set -g @tokyo-night-tmux_show_right_widgets "git,#[fg=#73daca]#{pane_current_command},datetime"
```

Entries starting with `#(` or `#{` or `#[` are passed through verbatim.

### Hard opt-out

Setting `@tokyo-night-tmux_show_<name> 0` always disables the widget,
even if it's listed in an order list:

```bash
# Disable git everywhere, even if in show_right_widgets
set -g @tokyo-night-tmux_show_git 0
```

---

## Date & Time

Displays current date and time in the status bar.

```bash
set -g @tokyo-night-tmux_show_datetime 1
set -g @tokyo-night-tmux_date_format YMD   # see options below
set -g @tokyo-night-tmux_time_format 24H   # see options below
```

### Date format options

| Value | Format | Example |
|---|---|---|
| `YMD` | Year-Month-Day | `2024-01-31` |
| `MDY` | Month-Day-Year | `01-31-2024` |
| `DMY` | Day-Month-Year | `31-01-2024` |
| `hide` | Hidden | *(not shown)* |

### Time format options

| Value | Format | Example |
|---|---|---|
| `24H` | 24-hour | `18:30` |
| `12H` | 12-hour with AM/PM | `6:30 PM` |
| `hide` | Hidden | *(not shown)* |

---

## Now Playing

Shows the currently playing track from your media player.

```bash
set -g @tokyo-night-tmux_show_music 1
```

**Requirements:**
- **Linux:** [playerctl](https://github.com/altdesktop/playerctl)
- **macOS:** [nowplaying-cli](https://github.com/kirtan-shah/nowplaying-cli)

Supports any MPRIS-compatible player on Linux (Spotify, VLC, Firefox, etc.)
and the macOS system media controls.

---

## Netspeed

Displays real-time upload and download speeds, local and public IPs, Wi-Fi
signal strength with color-coded percentage, and the active SSID.

```bash
set -g @tokyo-night-tmux_show_netspeed 1
set -g @tokyo-night-tmux_netspeed_iface "wlan0"      # auto-detected via default route if omitted
set -g @tokyo-night-tmux_netspeed_showip "local"      # off / local / public / both (default: local)
set -g @tokyo-night-tmux_netspeed_show_country 1      # show flag next to public IP (default: 1)
set -g @tokyo-night-tmux_netspeed_show_dns 0          # show active DNS server (default: 0)
set -g @tokyo-night-tmux_netspeed_refresh 1           # speed sample interval in seconds
set -g @tokyo-night-tmux_netspeed_ip_refresh_rate 300 # public IP fetch interval in seconds
set -g @tokyo-night-tmux_netspeed_signal_refresh_rate 10  # SSID/signal re-sample interval in seconds
```

**Requirements:** [bc](https://www.gnu.org/software/bc/)

### Signal strength

When connected to Wi-Fi, the SSID is prefixed with a color-coded signal
percentage:

| Range | Color | Example |
|---|---|---|
| 0-30% | Red (`#f7768e`) | `30%` |
| 31-65% | Yellow (`#e0af68`) | `55%` |
| 66-100% | Green (`#73daca`) | `85%` |

Signal strength is fetched at the `signal_refresh_rate` interval (default 10s)
and cached to avoid calling `iw`/`iwconfig` on every status refresh.

### second status bar mode

When shown on the second status bar, netspeed displays in **full mode**:
public IP, country flag, local IP, signal strength, SSID, and traffic speeds.
When on the main bar, only TX/RX speeds are shown.

---

## Path

Shows the current pane's working directory in the status bar.

```bash
set -g @tokyo-night-tmux_show_path 1
set -g @tokyo-night-tmux_path_format relative   # 'relative' or 'full'
```

| Value | Description | Example |
|---|---|---|
| `relative` | Home directory replaced with `~` | `~/dev/myproject` |
| `full` | Absolute path | `/home/user/dev/myproject` |

---

## Battery

Displays battery level with a contextual icon that changes based on charge
state (discharging, charging, full, plugged in).

```bash
set -g @tokyo-night-tmux_show_battery_widget 1
set -g @tokyo-night-tmux_battery_name "BAT1"      # default: 'BAT1' (Linux), 'InternalBattery-0' (macOS)
set -g @tokyo-night-tmux_battery_low_threshold 21  # show warning below this % (default: 21)
```

**Supported platforms:** Linux, macOS, Windows (Cygwin/WSL).

> On Linux, some distributions use `BAT0` instead of `BAT1`.
> Check with `ls /sys/class/power_supply/`.

---

## Local Git Status

Shows git information for the repository in the current pane, including
branch name, file changes, and remote sync state.

```bash
set -g @tokyo-night-tmux_show_git 1
```

**Requirements:** [bc](https://www.gnu.org/software/bc/)

### What it shows

| Indicator | Meaning |
|---|---|
| Branch name | Current branch (truncated to 25 chars) |
| `󱓎` (dim red) | Uncommitted local changes |
| `󰛃` (red) | Local commits not yet pushed |
| `󰛀` (magenta) | Remote is ahead — pull needed |
| `` (green) | Branch is clean and in sync |
| ` N` (yellow) | N changed files |
| ` N` (green) | N inserted lines |
| ` N` (red) | N deleted lines |
| ` N` (dim) | N untracked files |

---

## Web-based Git Widget

Shows GitHub or GitLab repository statistics directly from the remote server:
open PRs, pending reviews, and assigned issues.

```bash
set -g @tokyo-night-tmux_show_wbg 1
```

**Requirements:**
- GitHub: [gh CLI](https://cli.github.com/) — must be authenticated (`gh auth login`)
- GitLab: [glab CLI](https://gitlab.com/gitlab-org/cli) — must be authenticated (`glab auth login`)

### What it shows

| Indicator | Meaning |
|---|---|
| ` N` (green) | N open pull/merge requests |
| ` N` (yellow) | N PRs awaiting your review |
| ` N` (green) | N open issues assigned to you |
| ` N` (red) | N open bug issues assigned to you |

Works with both SSH (`git@github.com:user/repo.git`) and HTTPS
(`https://github.com/user/repo.git`) remotes.

> **Note:** The widget throttles API calls — if `status-interval` is under
> 20 seconds, requests are spaced out to avoid hitting rate limits.

---

## Hostname

Displays the machine hostname next to the session name on the left side of the
status bar.

```bash
set -g @tokyo-night-tmux_show_hostname 1
```

Hostname is detected via `hostnamectl` (Linux), `scutil` (macOS), or the
`hostname` command as a fallback.

---

## Next steps

- [Customize number and window styles](customization.md)
- [Change the color theme](themes.md)
