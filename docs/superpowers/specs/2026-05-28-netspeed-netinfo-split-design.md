# netspeed / netinfo Split Design

Split the monolithic networks widget into two independent widgets: `netspeed` (pure RX/TX traffic) and `netinfo` (network information), with individual netinfo sub-items composable in status bar order lists.

## Motivation

The current `netspeed.sh` combines traffic speed with network information (SSID, IPs, DNS, country flag). Users who only want speed or only want info have to enable the whole widget and disable sub-features individually. Moving to composable sub-items in the reorder system gives users full control.

## Architecture

### Files

| File | Change | Description |
|------|--------|-------------|
| `src/netspeed.sh` | Rewrite | Strip to pure RX/TX speed |
| `src/netinfo.sh` | New | Network information widget |
| `lib/netspeed.sh` | Modify | Add DNS caching alongside IP cache |
| `tokyo-night.tmux` | Modify | Add netinfo-related variables |
| `lib/widget-reorder.sh` | Modify | Add netinfo sub-item case entries |
| `test/netinfo.bats` | New | Tests for netinfo widget |

### `src/netspeed.sh` — rewritten

Pure traffic speed only:

```
░ ▾ 1.2MB/s ▴ 0.3MB/s
```

- Uses `get_bytes()`, `readable_format()`, `find_interface()` from `lib/netspeed.sh`
- No SSID, no signal, no IP display, no DNS, no country flag, no interface name
- The `interface_ipv4()` call is kept only for up/down detection (not displayed)
- Icons: `▾` (nf-md-download_network) and `▴` (nf-md-upload_network)

**Options:**
- `@tokyo-night-tmux_netspeed_iface` — shared interface (auto-detect if unset)
- `@tokyo-night-tmux_netspeed_refresh` — speed sample interval (default: 1)

### `src/netinfo.sh` — new single script

Controlled by `NETINFO_SHOW` env var. Always fetches all info (with caching) but outputs only the requested component.

**When `NETINFO_SHOW` is unset/empty (monolithic `netinfo`):**
Shows all items together, ordered as: DNS → private IP → public IP + flag → signal + SSID

**When `NETINFO_SHOW` is set to a single component:**
Outputs only that component, with appropriate tmux formatting (color, icon, etc.)

| `NETINFO_SHOW` | Output |
|----------------|--------|
| (unset) | All items together |
| `dns` | ` 8.8.8.8` |
| `privateip` | ` 192.168.1.42` |
| `publicip` | ` 1.2.3.4 🇺🇸` |
| `ssid` | Wi-Fi icon + SSID name |
| `signal` | `85%` color-coded |

**Options** (all under `netinfo_` prefix):

| Option | Default | Description |
|--------|---------|-------------|
| `@tokyo-night-tmux_netinfo_showip` | `local` | IP visibility: `0`/off, `local`, `public`, `both` |
| `@tokyo-night-tmux_netinfo_show_flag` | `1` | Country flag after public IP |
| `@tokyo-night-tmux_netinfo_ip_refresh_rate` | `300` | Public IP + DNS cache TTL (seconds) |
| `@tokyo-night-tmux_netinfo_signal_refresh_rate` | `10` | Signal strength cache TTL (seconds) |
| `@tokyo-night-tmux_netinfo_show_dns` | `1` | Show DNS server (opt-out) |

### DNS caching (requirement #4)

Add `ACTIVE_DNS` to the existing `tokyo-night-tmux-ip-cache.sh` cache file. When public IP data is fetched and written to cache, also run `get_active_dns()` and store it. Both expire at the same `ip_refresh_rate`.

- Extends `write_ip_cache()` / `read_ip_cache()` to include DNS
- DNS is refreshed exactly when IP is refreshed — never independently

### Widget variables in `tokyo-night.tmux`

```
netspeed="#($SCRIPTS_PATH/netspeed.sh)"
netinfo="#($SCRIPTS_PATH/netinfo.sh)"
netinfo_ssid="#(NETINFO_SHOW=ssid $SCRIPTS_PATH/netinfo.sh)"
netinfo_signal="#(NETINFO_SHOW=signal $SCRIPTS_PATH/netinfo.sh)"
netinfo_privateip="#(NETINFO_SHOW=privateip $SCRIPTS_PATH/netinfo.sh)"
netinfo_publicip="#(NETINFO_SHOW=publicip $SCRIPTS_PATH/netinfo.sh)"
netinfo_dns="#(NETINFO_SHOW=dns $SCRIPTS_PATH/netinfo.sh)"
```

- `netspeed_full` — removed. Second status line default uses `netinfo` instead (all network info, same scope as the old `netspeed_full`).
- `netspeed` — kept and rewritten to speed-only

### Re-order case entries in `lib/widget-reorder.sh`

Add to `WIDGET_NAMES` and `build_widget_string()`:

```
netspeed  → $netspeed            # pure speed
netinfo   → $netinfo             # all network info
ssid      → $netinfo_ssid
signal    → $netinfo_signal
privateip → $netinfo_privateip
publicip  → $netinfo_publicip
dns       → $netinfo_dns
```

Each sets its `widget_enabled_*` flag and gets `reset_widget_enabled()` treatment.

### Opt-out model

All sub-features default to enabled when the widget is listed. Users explicitly disable with:
```
set -g @tokyo-night-tmux_netinfo_show_dns 0
set -g @tokyo-night-tmux_netinfo_show_flag 0
```

This matches the existing philosophy: listed = active unless set to 0.

## Usage examples

```tmux
# Main bar: just speed
set -g @tokyo-night-tmux_show_right_widgets "netspeed"

# Second bar: compose individual info items
set -g @tokyo-night-tmux_show_second_right_widgets "dns,publicip,ssid,signal"

# Or monolithic netinfo for everything
set -g @tokyo-night-tmux_show_second_right_widgets "netinfo"

# Mixed with other widgets
set -g @tokyo-night-tmux_show_right_widgets "git,wbg,dns,privateip,netspeed"
```

## Migration from current configs

Existing configs using `show_right_widgets` with `netspeed` will continue to work:
- `netspeed` in the order list now shows speed only (no IP/DNS/SSID)
- Users who want the old combined behavior should replace `netspeed` with `netinfo` in their order list
- The `netspeed_showip`, `netspeed_show_dns`, `netspeed_show_country` options are deprecated in favor of `netinfo_*` options
- The `netspeed_ip_refresh_rate` and `netspeed_signal_refresh_rate` migrate to `netinfo_*` equivalents

## Testing

- `test/netinfo.bats` — tests `src/netinfo.sh` with mocked:
  - `NETINFO_SHOW` env var selection
  - Cache hit/miss for IP + DNS
  - Each output component format
- `test/netspeed.bats` — update existing tests to match stripped output
