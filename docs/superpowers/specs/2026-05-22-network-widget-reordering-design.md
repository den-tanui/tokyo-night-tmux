# Network Widget Reordering & Second Status Line

**Date:** 2026-05-22
**Status:** Draft

## Summary

Extend the tokyo-night-tmux plugin with three interlocking features:
1. **Widget reordering** — a single config option controls which right-bar widgets appear and in what order.
2. **Second status line** — an optional second tmux status bar where users can place widgets independently of the main bar.
3. **Enhanced network info** — SSID name, WiFi signal strength (5 levels), public IP (via ip-api.com), country flag, and active DNS server, all gated behind the second status line.

## Config Options

### New options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `@tokyo-night-tmux_show_right_widgets` | comma-separated widget names | *(unset)* | Widget order/selection for main status-right. When unset, current hardcoded order is preserved. |
| `@tokyo-night-tmux_show_second_status` | `0`, `1` | `0` | Enable second tmux status line. Requires tmux ≥ 3.2. |
| `@tokyo-night-tmux_show_second_left_widgets` | comma-separated widget names | *(unset)* | Widgets on the left side of the second status line. |
| `@tokyo-night-tmux_show_second_right_widgets` | comma-separated widget names | *(unset)* | Widgets on the right side of the second status line. |
| `@tokyo-night-tmux_netspeed_ip_refresh_rate` | integer (seconds) | `300` | Cache lifetime for public IP data from ip-api.com. |
| `@tokyo-night-tmux_netspeed_show_country` | `0`, `1` | `1` | Show country flag emoji alongside public IP. |
| `@tokyo-night-tmux_netspeed_show_dns` | `0`, `1` | `0` | Show active DNS server IP. |

### Extended option

| Option | Current | New | Description |
|--------|---------|-----|-------------|
| `@tokyo-night-tmux_netspeed_showip` | `0` or `1` | `0`, `local`, `public`, `1` | `0`=off, `local`=local IP only (current `1` behavior), `public`=public IP only, `1`=both. Backward-compatible — existing `0`/`1` values continue to work. |

### Widget names for the comma-separated lists

Valid values for `show_right_widgets`, `show_second_left_widgets`, and `show_second_right_widgets`:

| Name | Widget | Source file |
|------|--------|-------------|
| `battery` | Battery level + charge state | `src/battery-widget.sh` |
| `path` | Current pane path | `src/path-widget.sh` |
| `music` | Now playing track | `src/music-tmux-statusbar.sh` |
| `netspeed` | Speed, SSID, signal, IPs, DNS, interface (all network output). The sub-elements (ssid, signal, public_ip, etc.) are **not** individual list entries — they're output fields of this single widget, controlled by dedicated config options (see below). | `src/netspeed.sh` (enhanced) |
| `git` | Git branch + diff stats | `src/git-status.sh` |
| `wbg` | GitHub/GitLab PR/issue counts | `src/wb-git-status.sh` |
| `datetime` | Date and time | `src/datetime-widget.sh` |
| `hostname` | Machine hostname | `src/hostname-widget.sh` |

**Arbitrary commands and tmux formats:** Any list entry starting with `#(` or `#{` is passed through verbatim — no name-to-script mapping is applied. This allows users to inject their own `#(/path/to/script.sh)`, inline `#(curl http://...)`, tmux format variables like `#{session_name}`, or raw format attributes like `#[fg=red]  ●  `. This makes the widget list fully extensible without plugin changes.

Example config with arbitrary commands:
```
set -g @tokyo-night-tmux_show_right_widgets "path, git, #(~/.tmux/my-widget.sh)"
set -g @tokyo-night-tmux_show_second_right_widgets "netspeed, #(curl -s http://localhost:8080/status | head -c 40), #[fg=#82aaff]◆"
```

## Architecture

### Entrypoint (`tokyo-night.tmux`)

The entrypoint gains a function to build widget strings from comma-separated lists:

```
build_widget_string(tmux_vars, list_option_name) → formatted_status_string
```

This function parses the comma-separated option, iterates over widget names, and concatenates the corresponding `#()` tmux substitution strings. The same function is used for `status-right` (from `show_right_widgets`) and for both sides of `status-format[1]` (from `show_second_left_widgets` / `show_second_right_widgets`).

**Arbitrary command passthrough:** For each item in the list, the function checks if it starts with `#(` or `#{`. If so, the item is appended verbatim without any mapping. If not, the item is matched against the known widget names via a `case` statement. This allows users to inject custom scripts, inline commands, tmux format variables, or raw format attributes anywhere in the order.

```bash
build_widget_string() {
  local tmux_vars="$1"
  local list_option="$2"
  local list
  list=$(echo "$tmux_vars" | grep "@tokyo-night-tmux_${list_option}" | cut -d" " -f2)
  [[ -z $list ]] && return

  local result=""
  IFS=',' read -ra ITEMS <<< "$list"
  for item in "${ITEMS[@]}"; do
    item="$(echo "$item" | xargs)"
    # Passthrough for custom tmux commands / formats
    if [[ $item == "#("* ]] || [[ $item == "#{"* ]]; then
      result+="$item"
    else
      case "$item" in
        battery)  result+="$battery_status" ;;
        path)     result+="$current_path" ;;
        music)    result+="$cmus_status" ;;
        netspeed) result+="$netspeed" ;;
        git)      result+="$git_status" ;;
        wbg)      result+="$wb_git_status" ;;
        datetime) result+="$date_and_time" ;;
        hostname) result+="$hostname" ;;
      esac
    fi
  done
  echo "$result"
}
```

The same function serves both the main bar (`show_right_widgets`) and the second bar (`show_second_left_widgets`, `show_second_right_widgets`).

**Flow:**

1. Source `src/themes.sh` (already done).
2. Read `@tokyo-night-tmux_show_right_widgets`.
   - If set: parse, build `status-right` from the list.
   - If unset: use current hardcoded `status-right` (backward compat).
3. Read `@tokyo-night-tmux_show_second_status`:
   - If `1` AND tmux version ≥ 3.2:
     - `set -g status 2`
     - Build `status-format[1]` from `show_second_left_widgets` (left-aligned) + `show_second_right_widgets` (right-aligned), prefixed with `$RESET`.
   - If disabled or tmux < 3.2: do nothing (single status line, current behavior).

### Widget gating

Two-tier control:
- **Tier 1 (list):** If a widget isn't in the `show_right_widgets` list, its `#()` call is never added to `status-right`. Zero cost.
- **Tier 2 (toggle):** Each widget script still checks its own `@tokyo-night-tmux_show_<widget>` toggle and exits early if not enabled. This means a widget in the list can still be individually suppressed.

### Enhanced netspeed widget (`src/netspeed.sh`)

The existing `src/netspeed.sh` widget is extended with new data-fetching logic in `lib/netspeed.sh`. On each invocation, the widget:

1. Resolves the interface (existing logic).
2. Determines if it's wireless or wired (`/sys/class/net/$IFACE/wireless` on Linux, `en0` convention on macOS).
3. If wireless and second-status-line features are configured:
   - Reads SSID and signal strength.
   - Checks/reads public IP cache.
   - Fetches active DNS server.
4. Outputs the configured subset of network details.

The widget output on the second line replaces the older `#()` structures — the second line doesn't duplicate speed data from the main line unless the user explicitly includes `netspeed` in the second line's widget list.

### Network detail data functions (`lib/netspeed.sh`)

All new data-fetching functions are added to `lib/netspeed.sh` (shared between the widget and tests).

#### `get_ssid(interface)` → SSID string or empty

- **Linux:**
  1. `/proc/net/wireless` — parse for the interface line, confirm it's wireless. Read SSID via `iwgetid -r`.
- **macOS:** `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I` → `SSID` field.

#### `get_signal_strength(interface)` → percentage 0-100 or empty

- **Linux fallback chain:**
  1. `/proc/net/wireless` — kernel link quality (field 3, always percentage).
  2. `iw dev $IFACE link` — parse signal dBm.
  3. `iwconfig $IFACE` — parse `Signal level=` dBm or `Link Quality` ratio.
  4. `nmcli -t -f IN-USE,SIGNAL dev wifi list` — find connected AP, get SIGNAL.
- **macOS:** `airport -I` → `agrCtlRSSI`, convert dBm → percentage: `2 × (dBm + 100)`.
- **5-level mapping:**

| Level | Range | Nerd Font Icon |
|-------|-------|---------------|
| 0 | No signal / disconnected | `nf-md-wifi_strength_off` (`󰤯`) |
| 1 | 1-20% | `nf-md-wifi_strength_1` (`󰤟`) |
| 2 | 21-40% | `nf-md-wifi_strength_2` (`󰤢`) |
| 3 | 41-60% | `nf-md-wifi_strength_3` (`󰤥`) |
| 4 | 61-80% | `nf-md-wifi_strength_4` (`󰤨`) |
| 5 | 81-100% | `nf-md-wifi_strength_4` (`󰤨`) |

#### `get_public_ip()`, `get_country_code()` → values or empty

- Cache file: `/tmp/tokyo-night-tmux-ip-cache.sh`
- Cache contents:
  ```bash
  PUBLIC_IP="203.0.113.42"
  COUNTRY_CODE="US"
  CACHE_TIME="1680000000"
  CACHED_IFACE="wlan0"
  CACHED_SSID="MyWiFi"
  ```
- **Refetch triggers:**
  1. Cache file doesn't exist.
  2. Cache is older than `ip_refresh_rate` seconds.
  3. Interface changed (`CACHED_IFACE` mismatch).
  4. SSID changed (`CACHED_SSID` mismatch) — catches AP roaming.
- **API:** `curl -s http://ip-api.com/json/?fields=status,countryCode,query` (no API key needed, no JQ required).
- **Parsing:** grep/sed on the JSON response — status + countryCode + IP.
- **Country flag emoji:** Convert two-letter countryCode (e.g. "US") to regional indicator symbols. Each ASCII letter A-Z maps to a Regional Indicator Symbol (U+1F1E6 for A through U+1F1FF for Z). Implementation uses `printf` with `\U` hex escape for the supplementary plane:
  ```bash
  flag() {
    local country="$1"
    local a=0x1F1E6
    local c1=$(printf '%x' $(( a + $(printf '%d' "'${country:0:1}") - 65 )))
    local c2=$(printf '%x' $(( a + $(printf '%d' "'${country:1:1}") - 65 )))
    printf "\U$c1\U$c2"
  }
  ```
  Notes: requires bash ≥ 4.2 (already a dependency of the plugin). The `\U` escape in `printf` handles Unicode outside the BMP on bash 4.2+.
- **Error handling:** If curl fails, response has `"status":"fail"`, or parsing fails — silently skip public IP + country. Local IP still shows.

#### `get_active_dns(interface)` → IP string or empty

- **Linux fallback chain:**
  1. `resolvectl status $IFACE` — parse `Current DNS Server`.
  2. `/etc/resolv.conf` — first `nameserver` line that isn't `127.0.0.53` (systemd stub) or `127.0.0.1` (dnsmasq stub).
  3. `nmcli dev show $IFACE` — `IP4.DNS[1]`.
- **macOS:** `scutil --dns` — parse non-local nameserver entries.

### IP display logic

| `show_ip` value | What appears |
|----------------|--------------|
| `0` | No IP shown |
| `local` | Local IP only (LAN icon) |
| `public` | Public IP only (globe icon) |
| `1` | Both (LAN icon + local IP, globe icon + public IP) |

### Status bar examples

**Single status line (existing behavior, no reordering):**
```
~ 0:zsh*                    ░  󰁹 100%  ~/.dotfiles  ░ 󰁕 0.0KB/s 󰁝 0.0KB/s 󰤩  ▒  main  ▒  󰥔 2026-05-22 ❬ 14:30
```

**Reordered single line (path + git only on right):**
```
~ 0:zsh*                                              󰉋 ~/.dotfiles  ▒  main
```

**Two status lines (network details on line 2):**
```
~ 0:zsh*                                              󰉋 ~/.dotfiles  ▒  main
󰤨 MyWiFi    󰤬       󰅟 203.0.113.42 🇺🇸    󰑚 1.1.1.1
```

## File Changes

### Modified files

| File | Changes |
|------|---------|
| `tokyo-night.tmux` | Add `build_widget_string()` function, dynamic `status-right` construction, `status-format[1]` setup |
| `src/netspeed.sh` | Add SSID, signal, public IP, country, DNS output elements. Parse new config options. |
| `lib/netspeed.sh` | Add `get_ssid()`, `get_signal_strength()`, `get_public_ip()`, `get_country_flag()`, `get_active_dns()`, cache read/write helpers |
| `test/netspeed.bats` | No changes (new functions target external APIs and system state — tested via integration, see Testing section) |

### New files

| File | Purpose |
|------|---------|
| *(none)* | All changes are additions to existing files |

## Testing

### Unit tests

- **`get_signal_strength()`:** Test dBm-to-percentage conversion, `/proc/net/wireless` parsing, fallback chain behavior with mocked inputs.
- **`readable_format()`:** Already tested (no changes).
- **`country_flag()`:** Test letter-to-emoji conversion for known country codes (US, DE, JP).
- **`parse_ip_api_response()`:** Test with mock valid/error responses.
- **Cache management:** Test cache staleness, forced-refresh triggers, cache file I/O.

### Integration tests

- **Public IP:** Not tested in CI (requires external API). Manual verification.
- **SSID/signal:** Not tested in CI (requires WiFi hardware). Manual verification. The library functions are tested with mocked data.

### Backward compatibility tests

- Existing `show_ip=0` and `show_ip=1` configs continue to work with old behavior.
- `show_right_widgets` unset preserves current hardcoded order.
- `show_second_status=0` is a no-op (single status line).

## Tmux Version Compatibility

- **Second status line** requires tmux ≥ 3.2. If `show_second_status=1` and tmux < 3.2, the option is silently ignored (no error).
- **Widget reordering** works on all tmux versions (uses existing `status-right` and `status-format[1]` APIs).
- Tmux version check: `tmux -V | cut -d' ' -f2 | cut -d'.' -f1,2` and compare.

## Backward Compatibility

| Change | Breakage | Mitigation |
|--------|---------|------------|
| New widget names in list options | None (new feature) | — |
| `show_ip` extends to `local`/`public`/`1` | None. Existing `0` and `1` values are handled identically by the script. | The `1` value now maps to the same code path as the new `local` value, then adds public if available. |
| `show_right_widgets` unset | None. Falls through to hardcoded `status-right`. | Documented default behavior. |
| `show_second_status` default `0` | None. Single status line. | No change to existing users. |
