# Tokyo Night Tmux

A clean, dark Tmux theme inspired by the lights of [Tokyo at night](https://www.google.com/search?q=tokyo+night&tbm=isch).
Adapted from the [Tokyo Night VS Code theme](https://github.com/enkia/tokyo-night-vscode-theme) — the perfect companion for [tokyonight-vim](https://github.com/ghifarit53/tokyonight-vim).

---

## Preview

> Terminal: [Kitty](https://github.com/davidmathers/tokyo-night-kitty-theme) · Font: [SFMono Nerd Font Ligaturized](https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized)

![Default status bar](snaps/logico.png)
*Default status bar*

![Second status bar](snaps/Second-status.png)
*Second status bar with path, netspeed, and music widgets*

![Path widget with spaces](snaps/Path-with-spaces.png)
*Path widget showing directories with spaces*

---

## Quick start

### 1. Install dependencies

**Nerd Fonts v3+** and **Bash 4.2+** are required.

<details>
<summary>macOS</summary>

```bash
brew install --cask font-monaspace-nerd-font font-noto-sans-symbols-2
brew install bash bc coreutils gawk gh glab gsed jq nowplaying-cli
```

</details>

<details>
<summary>Arch Linux</summary>

```bash
pacman -Sy bash bc coreutils git jq playerctl
```

</details>

<details>
<summary>Ubuntu / Debian</summary>

```bash
apt-get install bash bc coreutils gawk git jq playerctl
```

</details>

<details>
<summary>Alpine Linux</summary>

```bash
apk add bash bc coreutils gawk git jq playerctl sed
```

</details>

→ Full dependency list: [user_docs/installation.md](user_docs/installation.md)

### 2. Install the plugin via TPM

Add to `~/.tmux.conf` and press `prefix` + <kbd>I</kbd> to install:

```bash
set -g @plugin "den-tanui/tokyo-night-tmux"
```

### 3. Pick a theme *(optional)*

```bash
set -g @tokyo-night-tmux_theme night   # night (default) | storm | moon | day
set -g @tokyo-night-tmux_transparent 1 # transparent background
```

### 4. Enable and reorder widgets

Configure which widgets appear and in what order. Being in a widget list
**auto-enables** the widget — no need for individual `_show_*` flags.

```bash
# Main bar (right side)
set -g @tokyo-night-tmux_show_right_widgets "battery,git,datetime"

# Second status bar (tmux ≥ 3.2 — auto-enabled when these options are set)
set -g @tokyo-night-tmux_show_second_left_widgets "path"
set -g @tokyo-night-tmux_show_second_right_widgets "music,netspeed"
```

Reload: `tmux source ~/.tmux.conf`

### Alternative: per-widget toggles

You can still use the traditional `_show_<name>` flags if you prefer:

```bash
set -g @tokyo-night-tmux_show_git 1
set -g @tokyo-night-tmux_show_netspeed 1
set -g @tokyo-night-tmux_show_battery_widget 1
set -g @tokyo-night-tmux_show_music 1
set -g @tokyo-night-tmux_show_datetime 1
```

---

## Features

| Feature | Description |
|---|---|
| 4 color themes | Night, Storm, Moon, Day — plus transparent background |
| **Widget reordering** | Customize widget order and position via comma-separated lists |
| **Second status bar** | Dedicated row for path, netspeed, music, etc. (tmux ≥ 3.2) |
| **Auto-enable by order** | Listing a widget in your config implicitly enables it |
| Local git status | Branch, changes, push/pull sync indicator |
| GitHub / GitLab widget | Open PRs, pending reviews, assigned issues |
| Netspeed | Upload/download speed with Wi-Fi signal (%) and interface detection |
| Signal strength | Color-coded percentage (red/yellow/green) |
| Now Playing | Track info via playerctl (Linux) or nowplaying-cli (macOS) |
| Battery | Level and charge state with contextual icons |
| Date & Time | Configurable format (YMD/MDY/DMY, 12H/24H) |
| Path widget | Current pane path (relative or absolute) |
| Hostname | Machine hostname in the status bar |
| Number styles | 8 styles for window/pane IDs (digital, roman, squares, …) |
| SSH indicator | Automatic icon change for SSH sessions |
| Prefix highlight | Visual indicator when tmux prefix is active |
| Zoom indicator | Separate style for zoomed panes |

---

## Documentation

| Topic | Link |
|---|---|
| Installation & dependencies | [user_docs/installation.md](user_docs/installation.md) |
| Color themes & transparency | [user_docs/themes.md](user_docs/themes.md) |
| Widget ordering & status bar | [user_docs/widgets.md](user_docs/widgets.md) |
| Number styles & window icons | [user_docs/customization.md](user_docs/customization.md) |

---

## Contributing

> [!IMPORTANT]
> This is a personal fork — changes here may diverge significantly from the
> upstream. PRs are welcome, but expect a different feature set.

Feel free to open an issue or pull request with suggestions or improvements.
Ensure your editor follows `.editorconfig`.

[Nerd Fonts]: https://www.nerdfonts.com/
[bc]: https://www.gnu.org/software/bc/
[jq]: https://jqlang.github.io/jq/
[playerctl]: https://github.com/altdesktop/playerctl
[nowplaying-cli]: https://github.com/kirtan-shah/nowplaying-cli
[Homebrew]: https://brew.sh/
