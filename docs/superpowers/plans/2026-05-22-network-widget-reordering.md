# Network Widget Reordering & Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement widget reordering, second status line, and enhanced network info features.

**Architecture:** Three sequential branches from `next`, each adding one feature layer. Branch 1 adds `build_widget_string()` and `show_right_widgets` to `tokyo-night.tmux`. Branch 2 adds `show_second_status` + `status-format[1]` support. Branch 3 adds SSID/signal/public-IP/DNS functions to `lib/netspeed.sh` and extends `src/netspeed.sh` output.

**Tech Stack:** Bash 4.2+, tmux ≥ 3.2 (for second status line), Nerd Fonts v3+ (glyphs)

---

## Branch Strategy

All branches fork from `next` and target `next` for PRs:

```
next
├── feature/widget-reordering          # Branch 1
├── feature/second-status-line         # Branch 2 (depends on 1)
└── feature/enhanced-netspeed          # Branch 3 (independent of 1,2)
```

Merge order: Branch 1 → Branch 2 → Branch 3 (or Branch 1 + 3 in parallel, then 2).

---

### Task 1: Create `feature/widget-reordering` branch

**Files:**
- Create: `feature/widget-reordering` branch from `next`
- Modify: `tokyo-night.tmux`

- [ ] **Step 1: Checkout `next` and create branch**

```bash
git fetch origin next
git checkout -b feature/widget-reordering origin/next
```

- [ ] **Step 2: Read current `tokyo-night.tmux` to understand the entrypoint**

The file currently hardcodes `status-right` on line 80:
```bash
tmux set -g status-right "$battery_status$current_path$cmus_status$netspeed$git_status$wb_git_status$date_and_time"
```

This needs to become dynamic based on `@tokyo-night-tmux_show_right_widgets`.

- [ ] **Step 3: Add `build_widget_string()` function to `tokyo-night.tmux`**

Insert after the `window_space` line (line 55) and before the widget assignment section:

```bash
# Build a status string from a comma-separated widget list option
# Usage: build_widget_string <option_suffix>
#   e.g. build_widget_string "show_right_widgets" reads @tokyo-night-tmux_show_right_widgets
build_widget_string() {
  local option_name="@tokyo-night-tmux_$1"
  local list
  list=$(echo "$TMUX_VARS" | grep "${option_name}" | cut -d" " -f2)
  [[ -z $list ]] && return

  local result=""
  local saved_ifs="$IFS"
  IFS=','
  for item in $list; do
    item="$(echo "$item" | xargs)"  # trim whitespace
    if [[ $item == "#("* ]] || [[ $item == "#{"* ]]; then
      # Passthrough — user-supplied tmux command / format variable
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
  IFS="$saved_ifs"
  echo "$result"
}
```

- [ ] **Step 4: Replace hardcoded `status-right` with dynamic construction**

Replace line 80:
```bash
tmux set -g status-right "$battery_status$current_path$cmus_status$netspeed$git_status$wb_git_status$date_and_time"
```

With:
```bash
# Widget reordering: if show_right_widgets is set, use it; otherwise default order
RIGHT_WIDGETS=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_right_widgets' | cut -d" " -f2)
if [[ -n $RIGHT_WIDGETS ]]; then
  tmux set -g status-right "$(build_widget_string "show_right_widgets")"
else
  tmux set -g status-right "$battery_status$current_path$cmus_status$netspeed$git_status$wb_git_status$date_and_time"
fi
```

- [ ] **Step 5: Run pre-commit checks**

```bash
pre-commit run --all-files
```
Expected: shfmt and codespell pass cleanly.

- [ ] **Step 6: Commit**

```bash
git add tokyo-night.tmux
git commit -m "feat: add widget reordering via show_right_widgets option"
```

```bash
git log --oneline -3
```
Expected: shows the new commit.

---

### Task 2: Create `feature/second-status-line` branch

**Files:**
- Create: `feature/second-status-line` branch from `feature/widget-reordering`
- Modify: `tokyo-night.tmux`

- [ ] **Step 1: Branch from widget-reordering**

```bash
git checkout -b feature/second-status-line feature/widget-reordering
```

- [ ] **Step 2: Add second status line block to `tokyo-night.tmux`**

Add at the end of the file (after the `window-status-separator` line):

```bash
#+--- Second Status Line ---+
SECOND_STATUS=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_second_status' | cut -d" " -f2)
if [[ ${SECOND_STATUS} -eq 1 ]]; then
  # Verify tmux version >= 3.2 for status-format[1] support
  TMUX_VERSION=$(tmux -V | cut -d' ' -f2 | cut -d'.' -f1,2)
  if [[ $(echo "$TMUX_VERSION >= 3.2" | bc) -eq 1 ]]; then
    tmux set -g status 2

    SECOND_LEFT=$(build_widget_string "show_second_left_widgets")
    SECOND_RIGHT=$(build_widget_string "show_second_right_widgets")

    if [[ -n $SECOND_LEFT ]] || [[ -n $SECOND_RIGHT ]]; then
      tmux set -g status-format[1] "${RESET}#[align=left]${SECOND_LEFT}#[align=right]${SECOND_RIGHT}"
    fi
  fi
fi
```

- [ ] **Step 3: Run pre-commit checks**

```bash
pre-commit run --all-files
```

- [ ] **Step 4: Commit**

```bash
git add tokyo-night.tmux
git commit -m "feat: add second status line with left/right widget lists"
```

---

### Task 3: Create `feature/enhanced-netspeed` branch

**Files:**
- Create: `feature/enhanced-netspeed` branch from `next`
- Modify: `lib/netspeed.sh`
- Modify: `src/netspeed.sh`

- [ ] **Step 1: Branch from `next`**

```bash
git checkout -b feature/enhanced-netspeed origin/next
```

- [ ] **Step 2: Add WiFi detection functions to `lib/netspeed.sh`**

Append to the end of `lib/netspeed.sh`:

```bash
# Get WiFi SSID (empty if wired)
function get_ssid() {
  local interface="$1"
  if [[ "$(uname)" == "Linux" ]]; then
    # Only wireless interfaces have a wireless subdirectory
    if [[ ! -d "/sys/class/net/${interface}/wireless" ]]; then
      return
    fi
    iwgetid -r 2>/dev/null
  elif [[ "$(uname)" == "Darwin" ]]; then
    /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | \
      awk -F': ' '/^ *SSID/{print $2}'
  fi
}

# Get WiFi signal strength as percentage 0-100 (empty if wired)
function get_signal_strength() {
  local interface="$1"
  local signal=""

  if [[ "$(uname)" == "Linux" ]]; then
    if [[ ! -d "/sys/class/net/${interface}/wireless" ]]; then
      return
    fi
    # Fallback chain: /proc/net/wireless → iw → iwconfig → nmcli
    if [[ -r /proc/net/wireless ]]; then
      signal=$(awk -v iface="${interface}:" '$1 == iface {gsub(/\./,"",$3); print $3}' /proc/net/wireless)
    fi
    if [[ -z $signal ]] && command -v iw >/dev/null; then
      signal=$(iw dev "$interface" link 2>/dev/null | grep -o 'signal: [-0-9]*' | cut -d' ' -f2)
      if [[ -n $signal ]]; then
        signal=$(( 2 * (signal + 100) ))
        signal=$(( signal > 100 ? 100 : signal ))
        signal=$(( signal < 0 ? 0 : signal ))
      fi
    fi
    if [[ -z $signal ]] && command -v iwconfig >/dev/null; then
      signal=$(iwconfig "$interface" 2>/dev/null | grep -o 'Signal level=[-0-9]*' | cut -d= -f2)
      if [[ -n $signal ]]; then
        signal=$(( 2 * (signal + 100) ))
        signal=$(( signal > 100 ? 100 : signal ))
        signal=$(( signal < 0 ? 0 : signal ))
      fi
    fi
    if [[ -z $signal ]] && command -v nmcli >/dev/null; then
      signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list 2>/dev/null | grep '^*' | cut -d: -f2)
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    local rssi
    rssi=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | \
      awk -F': ' '/agrCtlRSSI/{print $2}')
    if [[ -n $rssi ]]; then
      signal=$(( 2 * (rssi + 100) ))
      signal=$(( signal > 100 ? 100 : signal ))
      signal=$(( signal < 0 ? 0 : signal ))
    fi
  fi
  echo "$signal"
}

# Map signal percentage to Nerd Font WiFi icon
function signal_icon() {
  local pct=$1
  local icon
  if [[ -z $pct ]] || [[ $pct -eq 0 ]]; then
    icon="\U000f05aa"  # nf-md-wifi_off
  elif [[ $pct -le 20 ]]; then
    icon="\U000f05af"  # nf-md-wifi_strength_1
  elif [[ $pct -le 40 ]]; then
    icon="\U000f05ac"  # nf-md-wifi_strength_2
  elif [[ $pct -le 60 ]]; then
    icon="\U000f05ad"  # nf-md-wifi_strength_3
  elif [[ $pct -le 80 ]]; then
    icon="\U000f05ae"  # nf-md-wifi_strength_4
  else
    icon="\U000f05ab"  # nf-md-wifi_strength_4 (or strongest)
  fi
  echo -e "$icon"
}
```

- [ ] **Step 3: Add public IP, country flag, and DNS functions to `lib/netspeed.sh`**

Append to the end of `lib/netspeed.sh`:

```bash
# Cache file for public IP data
IP_CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/tokyo-night-tmux-ip-cache.sh"

# Read cached public IP data, returns empty if stale or missing
function read_ip_cache() {
  local iface="$1"
  local ssid="$2"
  local refresh_rate="${3:-300}"
  local cache_time cache_iface cache_ssid

  if [[ ! -f $IP_CACHE_FILE ]]; then
    return
  fi
  source "$IP_CACHE_FILE"
  local now
  now=$(date +%s)
  # Stale check
  if [[ $((now - CACHE_TIME)) -gt $refresh_rate ]]; then
    return
  fi
  # Interface changed
  if [[ -n $iface ]] && [[ "$CACHED_IFACE" != "$iface" ]]; then
    return
  fi
  # SSID changed (AP roaming)
  if [[ -n $ssid ]] && [[ "$CACHED_SSID" != "$ssid" ]]; then
    return
  fi
  echo "$PUBLIC_IP|$COUNTRY_CODE"
}

# Write public IP data to cache
function write_ip_cache() {
  local ip="$1"
  local code="$2"
  local iface="$3"
  local ssid="$4"
  local now
  now=$(date +%s)
  cat > "$IP_CACHE_FILE" <<-EOF
PUBLIC_IP="$ip"
COUNTRY_CODE="$code"
CACHE_TIME="$now"
CACHED_IFACE="$iface"
CACHED_SSID="$ssid"
EOF
}

# Fetch public IP and country code from ip-api.com
function fetch_public_ip() {
  if ! command -v curl >/dev/null; then
    return
  fi
  local response
  response=$(curl -s --max-time 5 "http://ip-api.com/json/?fields=status,countryCode,query" 2>/dev/null)
  local status
  status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  if [[ "$status" != "success" ]]; then
    return
  fi
  local ip country
  ip=$(echo "$response" | grep -o '"query":"[^"]*"' | cut -d'"' -f4)
  country=$(echo "$response" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4)
  echo "$ip|$country"
}

# Get public IP and country (with caching)
function get_public_ip_info() {
  local iface="$1"
  local ssid="$2"
  local refresh_rate="${3:-300}"

  local cached
  cached=$(read_ip_cache "$iface" "$ssid" "$refresh_rate")
  if [[ -n $cached ]]; then
    echo "$cached"
    return
  fi

  local fresh
  fresh=$(fetch_public_ip)
  if [[ -n $fresh ]]; then
    local ip="${fresh%|*}"
    local code="${fresh#*|}"
    write_ip_cache "$ip" "$code" "$iface" "$ssid"
    echo "$fresh"
  fi
}

# Convert country code to flag emoji
function country_flag() {
  local code="$1"
  [[ ${#code} -ne 2 ]] && return
  local base=0x1F1E6
  local c1 c2
  c1=$(printf '%x' $(( base + $(printf '%d' "'${code:0:1}") - 65 )))
  c2=$(printf '%x' $(( base + $(printf '%d' "'${code:1:1}") - 65 )))
  printf "\U$c1\U$c2"
}

# Get active DNS server IP
function get_active_dns() {
  local interface="$1"
  local dns=""

  if [[ "$(uname)" == "Linux" ]]; then
    # Method 1: resolvectl (systemd-resolved)
    if command -v resolvectl >/dev/null; then
      dns=$(resolvectl status "$interface" 2>/dev/null | grep 'Current DNS Server' | awk '{print $NF}')
    fi
    # Method 2: /etc/resolv.conf (skip local stubs)
    if [[ -z $dns ]] && [[ -r /etc/resolv.conf ]]; then
      dns=$(awk '/^nameserver/ && $2 !~ /^127\./ {print $2; exit}' /etc/resolv.conf)
    fi
    # Method 3: nmcli
    if [[ -z $dns ]] && command -v nmcli >/dev/null; then
      dns=$(nmcli dev show "$interface" 2>/dev/null | grep 'IP4.DNS\[' | awk '{print $2}' | head -1)
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    dns=$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]\]/ && $3 !~ /^127\./ && $3 !~ /^fe80/ {print $3; exit}')
  fi

  echo "$dns"
}
```

- [ ] **Step 4: Extend `src/netspeed.sh` with new output elements and config parsing**

Read the current `src/netspeed.sh` first, then modify:

Replace lines 16-22 (existing config reads) to add the new options:

```bash
# Get network interface
INTERFACE=$(tmux show-option -gv @tokyo-night-tmux_netspeed_iface 2>/dev/null)
# Show IP address
SHOW_IP=$(tmux show-option -gv @tokyo-night-tmux_netspeed_showip 2>/dev/null)
SHOW_IP="${SHOW_IP:-local}"  # default to local (backward compat: 1 = local)
# Time between refresh
TIME_DIFF=$(tmux show-option -gv @tokyo-night-tmux_netspeed_refresh 2>/dev/null)
TIME_DIFF=${TIME_DIFF:-1}
# Public IP refresh rate
IP_REFRESH_RATE=$(tmux show-option -gv @tokyo-night-tmux_netspeed_ip_refresh_rate 2>/dev/null)
IP_REFRESH_RATE=${IP_REFRESH_RATE:-300}
# Show country flag
SHOW_COUNTRY=$(tmux show-option -gv @tokyo-night-tmux_netspeed_show_country 2>/dev/null)
SHOW_COUNTRY="${SHOW_COUNTRY:-1}"
# Show DNS
SHOW_DNS=$(tmux show-option -gv @tokyo-night-tmux_netspeed_show_dns 2>/dev/null)
SHOW_DNS="${SHOW_DNS:-0}"
```

Add new icons after the existing `NET_ICONS` block:

```bash
NET_ICONS[signal]="#[fg=${THEME[foreground]}]"
NET_ICONS[public_ip]="#[fg=${THEME[foreground]}]\U000f0a5f"   # nf-md-earth
NET_ICONS[dns]="#[fg=${THEME[foreground]}]\U000f0e14"         # nf-md-dns
```

After the interface detection block (line 40, "Determine interface if not set"), add WiFi detection:

```bash
# Detect SSID and signal strength (WiFi only)
SSID=""
SIGNAL_PCT=""
if [[ ${INTERFACE} == "en0" ]] || [[ -d /sys/class/net/${INTERFACE}/wireless ]]; then
  SSID=$(get_ssid "$INTERFACE")
  SIGNAL_PCT=$(get_signal_strength "$INTERFACE")
fi
```

After the existing `IFACE_STATUS` detection (line 65), add public IP and DNS:

```bash
# Public IP and country
PUBLIC_IP=""
COUNTRY_CODE=""
if [[ -n $SSID ]]; then
  public_info=$(get_public_ip_info "$INTERFACE" "$SSID" "$IP_REFRESH_RATE")
  if [[ -n $public_info ]]; then
    PUBLIC_IP="${public_info%|*}"
    COUNTRY_CODE="${public_info#*|}"
  fi
fi

# Active DNS
ACTIVE_DNS=""
if [[ ${SHOW_DNS} -eq 1 ]] && [[ -n $SSID ]]; then
  ACTIVE_DNS=$(get_active_dns "$INTERFACE")
fi
```

Replace the output construction section (lines 67-74) with enhanced output:

```bash
NETWORK_ICON=${NET_ICONS[${IFACE_TYPE}_${IFACE_STATUS}]}

OUTPUT="${RESET}░ ${NET_ICONS[traffic_rx]} $RX_SPEED ${NET_ICONS[traffic_tx]} $TX_SPEED "

# WiFi-specific: signal icon + SSID (instead of raw interface name)
if [[ -n $SSID ]]; then
  if [[ -n $SIGNAL_PCT ]]; then
    OUTPUT+="${NET_ICONS[signal]}$(signal_icon "$SIGNAL_PCT") "
  fi
  OUTPUT+="${SSID} "
else
  OUTPUT+="$NETWORK_ICON #[dim]$INTERFACE "
fi

# IP display (spec: 0=off, local=local only, public=public only, 1|both=both)
case "$SHOW_IP" in
  0)  ;; # off
  local)
    if [[ -n $IPV4_ADDR ]]; then
      OUTPUT+="${NET_ICONS[ip]} #[dim]$IPV4_ADDR "
    fi
    ;;
  public)
    if [[ -n $PUBLIC_IP ]]; then
      OUTPUT+="${NET_ICONS[public_ip]} #[dim]$PUBLIC_IP "
      if [[ ${SHOW_COUNTRY} -eq 1 ]] && [[ -n $COUNTRY_CODE ]]; then
        OUTPUT+="$(country_flag "$COUNTRY_CODE") "
      fi
    fi
    ;;
  1|both)
    if [[ -n $IPV4_ADDR ]]; then
      OUTPUT+="${NET_ICONS[ip]} #[dim]$IPV4_ADDR "
    fi
    if [[ -n $PUBLIC_IP ]]; then
      OUTPUT+="${NET_ICONS[public_ip]} #[dim]$PUBLIC_IP "
      if [[ ${SHOW_COUNTRY} -eq 1 ]] && [[ -n $COUNTRY_CODE ]]; then
        OUTPUT+="$(country_flag "$COUNTRY_CODE") "
      fi
    fi
    ;;
esac

# DNS
if [[ ${SHOW_DNS} -eq 1 ]] && [[ -n $ACTIVE_DNS ]]; then
  OUTPUT+="${NET_ICONS[dns]} #[dim]$ACTIVE_DNS "
fi

# Interface name (always shown in dim, useful for troubleshooting)
OUTPUT+="#[dim]$INTERFACE "

echo -e "$OUTPUT"
```

- [ ] **Step 5: Run pre-commit checks**

```bash
pre-commit run --all-files
```

- [ ] **Step 6: Commit**

```bash
git add lib/netspeed.sh src/netspeed.sh
git commit -m "feat: add WiFi SSID, signal strength, public IP, country flag, and DNS to netspeed widget"
```

---

### Task 4: Self-review checklist

- [ ] **Spec coverage check:** Open the spec and skim each section. Every requirement should map to a task above.
- [ ] **Placeholder scan:** Search for "TBD", "TODO", "implement later" in this plan. Fix any.
- [ ] **Type consistency:** Variable names used in `tokyo-night.tmux` (e.g. `build_widget_string`) match in all three branches? Function names in `lib/netspeed.sh` (e.g. `get_ssid`, `get_signal_strength`) match between their definition and their call site in `src/netspeed.sh`?
