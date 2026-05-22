# tokyo-night-tmux — Agent Guide

A Tokyo Night themed Tmux plugin (TPM-compatible). All shell scripts (`#!/usr/bin/env bash`).

## Entry point

`tokyo-night.tmux` — sourced by TPM at tmux start. Sources `src/themes.sh` then calls widget scripts via `#()` tmux substitution syntax.

## Widget pattern

Every script in `src/` gatekeeps itself:
```bash
ENABLED=$(tmux show-option -gv @tokyo-night-tmux_show_<name> 2>/dev/null)
[[ ${ENABLED} -ne 1 ]] && exit 0
```
This means **widget scripts fail silently by default** if the tmux option isn't set. Don't assume they produce output.

## Theme system

- `src/themes.sh` reads `@tokyo-night-tmux_theme` (night|storm|moon|day, default: night) and `@tokyo-night-tmux_transparent` (1 = transparent bg).
- Exports `$THEME` (associative array of color keys) and `$RESET` (tmux format reset string).
- Widgets `source` this file to use theme colors.

## Core libraries

- `lib/coreutils-compat.sh` — sourced by macOS-only widgets. Adds GNU coreutils/gawk/gsed/bc to `$PATH` via Homebrew prefixes.
- `lib/netspeed.sh` — functions shared between `src/netspeed.sh` and tests. Has `get_bytes`, `readable_format`, `find_interface`, `interface_ipv4`.

## Testing

- **BATS framework** (`bats`). Only test file: `test/netspeed.bats`.
- Uses `bats-mock` for stubbing system commands.
- Run all tests: `bats --verbose-run --report-formatter junit test/`
- CI runs on Alpine (bash 4.2, 4.4, 5.0, 5.2) + macOS (GNU and builtin coreutils).
- Test report artifacts uploaded as JUnit XML.

## Dev workflow

- **Pre-commit hooks:** `pre-commit run --all-files` — uses shfmt (indent 2, simplify) + codespell.
- **EditorConfig:** indent 2 spaces, UTF-8, LF endings, 160 char line limit.
- **Commit style:** Conventional Commits (`type(scope): message`).
- **PRs target `next` branch** — NOT `main`. PRs to `main` are rejected.

## Config options (set via `tmux set -g @tokyo-night-tmux_<key> <val>`)

| Prefix | Examples |
|--------|----------|
| Theme/layout | `theme`, `transparent` |
| Widget toggles | `show_git`, `show_wbg`, `show_netspeed`, `show_battery_widget`, `show_music`, `show_path`, `show_hostname`, `show_datetime` |
| Display format | `date_format` (YMD/MDY/DMY/hide), `time_format` (12H/24H/hide) |
| Style | `window_id_style`, `pane_id_style`, `zoom_id_style`, `terminal_icon`, `active_terminal_icon`, `window_tidy_icons` |
| Netspeed | `netspeed_iface`, `netspeed_showip`, `netspeed_refresh` |
| Battery | `battery_name`, `battery_low_threshold` |

## Key dependencies

bash 4.2+, Nerd Fonts v3+ (glyphs), bc, jq (git widget), playerctl (Linux music), nowplaying-cli (macOS music).

## OS quirks

- Widgets use `$(uname)` to branch on macOS vs Linux vs CYGWIN/MINGW.
- macOS needs GNU coreutils from Homebrew (`brew install coreutils gawk gsed bc`).
- Battery widget on Linux reads `/sys/class/power_supply/BAT1/`.
- Music widget prefers playerctl (Linux), then nowplaying-cli (macOS <15), then media-control (fallback).
