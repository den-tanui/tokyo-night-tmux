#!/usr/bin/env bash

# Get network transmit data
function get_bytes() {
  local interface="$1"
  if [[ "$(uname)" == "Linux" ]]; then
    awk -v interface="$interface" '$1 == interface ":" {print $2, $10}' /proc/net/dev
  elif [[ "$(uname)" == "Darwin" ]]; then
    netstat -ib | awk -v interface="$interface" '/^'"${interface}"'/ {print $7, $10}' | head -n1
  else
    # Unsupported operating system
    exit 1
  fi
}

# Convert into readable format
function readable_format() {
  local bytes=$1
  local secs=${2:-1}

  if [[ $bytes -lt 1048576 ]]; then
    echo "$(bc -l <<<"scale=1; $bytes / 1024 / $secs")KB/s"
  else
    echo "$(bc -l <<<"scale=1; $bytes / 1048576 / $secs")MB/s"
  fi
}

# Auto-determine interface
function find_interface() {
  local interface
  if [[ $(uname) == "Linux" ]]; then
    interface=$(awk '$2 == 00000000 {print $1}' /proc/net/route)
  elif [[ $(uname) == "Darwin" ]]; then
    interface=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
    # If VPN, fallback to en0
    [[ ${interface:0:4} == "utun" ]] && interface="en0"
  fi
  echo "$interface"
}

# Detect interface IPv4 and status
function interface_ipv4() {
  local interface="$1"
  local ipv4_addr
  local status="up" # Default assumption
  if [[ $(uname) == "Darwin" ]]; then
    # Check for an IPv4 on macOS
    ipv4_addr=$(ipconfig getifaddr "$interface")
    [[ -z $ipv4_addr ]] && status="down"
  elif [[ $(uname) == "Linux" ]]; then
    # Use 'ip' command to check for IPv4 address
    if command -v ip >/dev/null 2>&1; then
      ipv4_addr=$(ip addr show dev "$interface" 2>/dev/null | grep "inet\b" | awk '{sub("/.*", "", $2); print $2}')
      [[ -z $ipv4_addr ]] && status="down"
    # Use 'ifconfig' command to check for IPv4 address
    elif command -v ifconfig >/dev/null 2>&1; then
      ipv4_addr=$(ifconfig "$interface" 2>/dev/null | grep "inet\b" | awk '{print $2}')
      [[ -z $ipv4_addr ]] && status="down"
    # Fallback to operstate on Linux
    elif [[ $(cat "/sys/class/net/$interface/operstate" 2>/dev/null) != "up" ]]; then
      status="down"
    fi
  fi
  echo "$ipv4_addr"
  [[ $status == "up" ]] && return 0 || return 1
}

# Get WiFi SSID (empty if wired or no WiFi)
function get_ssid() {
  local interface="$1"
  if [[ "$(uname)" == "Linux" ]]; then
    [[ ! -d "/sys/class/net/${interface}/wireless" ]] && return
    command -v iwgetid >/dev/null || return
    iwgetid -r 2>/dev/null
  elif [[ "$(uname)" == "Darwin" ]]; then
    /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null |
      awk -F': ' '/^ *SSID/{print $2}'
  fi
}

# Get WiFi signal strength as percentage 0-100 (empty if wired)
function get_signal_strength() {
  local interface="$1"
  local signal=""

  if [[ "$(uname)" == "Linux" ]]; then
    [[ ! -d "/sys/class/net/${interface}/wireless" ]] && return

    # Chain: iw → iwconfig → /proc/net/wireless → nmcli
    # iw and iwconfig return dBm → properly converted to percentage.
    # /proc/net/wireless returns a driver-specific raw quality (not %), so it's a lower priority fallback.
    if command -v iw >/dev/null; then
      local dbm
      dbm=$(iw dev "$interface" link 2>/dev/null | grep -o 'signal: [-0-9]*' | cut -d' ' -f2)
      if [[ -n $dbm ]]; then
        signal=$((2 * (dbm + 100)))
        signal=$((signal > 100 ? 100 : signal))
        signal=$((signal < 0 ? 0 : signal))
      fi
    fi
    if [[ -z $signal ]] && command -v iwconfig >/dev/null; then
      local dbm
      dbm=$(iwconfig "$interface" 2>/dev/null | grep -o 'Signal level=[-0-9]*' | cut -d= -f2)
      if [[ -n $dbm ]]; then
        signal=$((2 * (dbm + 100)))
        signal=$((signal > 100 ? 100 : signal))
        signal=$((signal < 0 ? 0 : signal))
      fi
    fi
    if [[ -z $signal ]] && [[ -r /proc/net/wireless ]]; then
      signal=$(awk -v iface="${interface}:" '$1 == iface {gsub(/\./,"",$3); print $3}' /proc/net/wireless)
    fi
    if [[ -z $signal ]] && command -v nmcli >/dev/null; then
      signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list 2>/dev/null | grep '^*' | cut -d: -f2)
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    local rssi
    rssi=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null |
      awk -F': ' '/agrCtlRSSI/{print $2}')
    if [[ -n $rssi ]]; then
      signal=$((2 * (rssi + 100)))
      signal=$((signal > 100 ? 100 : signal))
      signal=$((signal < 0 ? 0 : signal))
    fi
  fi

  echo "$signal"
}

# Map signal percentage to Nerd Font WiFi icon
function signal_icon() {
  local pct=$1
  if [[ -z $pct ]] || [[ $pct -eq 0 ]]; then
    printf "\U000f05aa" # nf-md-wifi_off
  elif [[ $pct -le 20 ]]; then
    printf "\U000f05af" # nf-md-wifi_strength_1
  elif [[ $pct -le 40 ]]; then
    printf "\U000f05ac" # nf-md-wifi_strength_2
  elif [[ $pct -le 60 ]]; then
    printf "\U000f05ad" # nf-md-wifi_strength_3
  elif [[ $pct -le 80 ]]; then
    printf "\U000f05ae" # nf-md-wifi_strength_4
  else
    printf "\U000f05ae" # nf-md-wifi_strength_4 (also for 81-100%)
  fi
}

# Cache file for public IP data
IP_CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/tokyo-night-tmux-ip-cache.sh"

# Read cached public IP data, returns "IP|COUNTRY" or empty if stale/missing
function read_ip_cache() {
  local iface="$1"
  local ssid="$2"
  local refresh_rate="${3:-300}"
  local cache_time cache_iface cache_ssid

  [[ ! -f $IP_CACHE_FILE ]] && return

  source "$IP_CACHE_FILE"
  local now
  now=$(date +%s)

  # Stale check
  if [[ $((now - CACHE_TIME)) -ge $refresh_rate ]]; then
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

# Write public IP data to cache file
function write_ip_cache() {
  local ip="$1"
  local code="$2"
  local dns="$3"
  local iface="$4"
  local ssid="$5"
  local now
  now=$(date +%s)
  cat >"$IP_CACHE_FILE" <<-EOF
PUBLIC_IP="$ip"
COUNTRY_CODE="$code"
ACTIVE_DNS="$dns"
CACHE_TIME="$now"
CACHED_IFACE="$iface"
CACHED_SSID="$ssid"
EOF
}

SIGNAL_CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/tokyo-night-tmux-signal-cache.sh"

# Read cached WiFi signal data, returns "SSID|SIGNAL_PCT" or empty if stale/missing
function read_signal_cache() {
  local iface="$1"
  local refresh_rate="${2:-300}"
  local cache_time cache_iface

  [[ ! -f $SIGNAL_CACHE_FILE ]] && return

  source "$SIGNAL_CACHE_FILE"
  local now
  now=$(date +%s)

  # Stale check
  if [[ $((now - CACHE_TIME)) -ge $refresh_rate ]]; then
    return
  fi
  # Interface changed
  if [[ -n $iface ]] && [[ "$CACHED_IFACE" != "$iface" ]]; then
    return
  fi

  echo "$CACHED_SSID|$CACHED_SIGNAL_PCT"
}

# Write WiFi signal data to cache file
function write_signal_cache() {
  local ssid="$1"
  local signal_pct="$2"
  local iface="$3"
  local now
  now=$(date +%s)
  cat >"$SIGNAL_CACHE_FILE" <<-EOF
CACHED_SSID="$ssid"
CACHED_SIGNAL_PCT="$signal_pct"
CACHE_TIME="$now"
CACHED_IFACE="$iface"
EOF
}

# Backoff file: prevents all tmux panes from hitting the API simultaneously
FETCH_BACKOFF_FILE="${XDG_RUNTIME_DIR:-/tmp}/tokyo-night-tmux-ip-backoff"

# Fetch public IP and country — tries providers in order, returns first success
function fetch_public_ip() {
  command -v curl >/dev/null || return

  # Ordered fallback chain: each returns "ip|country" or empty
  local result
  result=$(_fetch_ip_api_com) && printf '%s\n' "$result" && return
  result=$(_fetch_ipapi_co) && printf '%s\n' "$result" && return
  result=$(_fetch_ipinfo_io) && printf '%s\n' "$result" && return
}

# Provider: ip-api.com (45 req/min free, no key)
function _fetch_ip_api_com() {
  local response
  response=$(curl -s --max-time 5 "http://ip-api.com/json/?fields=status,countryCode,query" 2>/dev/null) || return
  [[ ${response:0:1} != "{" ]] && return

  local status ip country
  if command -v jq >/dev/null; then
    status=$(printf '%s\n' "$response" | jq -r '.status // empty')
    [[ "$status" != "success" ]] && return
    ip=$(printf '%s\n' "$response" | jq -r '.query // empty')
    country=$(printf '%s\n' "$response" | jq -r '.countryCode // empty')
  else
    status=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="status") print $(i+2)}')
    [[ "$status" != "success" ]] && return
    ip=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="query") print $(i+2)}')
    country=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="countryCode") print $(i+2)}')
  fi
  [[ -z $ip ]] && return
  printf '%s|%s\n' "$ip" "$country"
}

# Provider: ipapi.co (generous free tier, no key)
function _fetch_ipapi_co() {
  local response
  response=$(curl -s --max-time 5 "https://ipapi.co/json/" 2>/dev/null) || return
  [[ ${response:0:1} != "{" ]] && return

  local ip country
  if command -v jq >/dev/null; then
    ip=$(printf '%s\n' "$response" | jq -r '.ip // empty')
    country=$(printf '%s\n' "$response" | jq -r '.country_code // empty')
  else
    ip=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="ip") print $(i+2)}')
    country=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="country_code") print $(i+2)}')
  fi
  [[ -z $ip ]] && return
  printf '%s|%s\n' "$ip" "$country"
}

# Provider: ipinfo.io (50k req/mo, `missingauth` but works without token)
function _fetch_ipinfo_io() {
  local response
  response=$(curl -s --max-time 5 "https://ipinfo.io/json" 2>/dev/null) || return
  [[ ${response:0:1} != "{" ]] && return

  local ip country
  if command -v jq >/dev/null; then
    ip=$(printf '%s\n' "$response" | jq -r '.ip // empty')
    country=$(printf '%s\n' "$response" | jq -r '.country // empty')
  else
    ip=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="ip") print $(i+2)}')
    country=$(printf '%s\n' "$response" | awk -F'"' '{for(i=1;i<NF;i++) if($i=="country") print $(i+2)}')
  fi
  [[ -z $ip ]] && return
  printf '%s|%s\n' "$ip" "$country"
}

# Get public IP and country (with caching + rate-limit backoff)
function get_public_ip_info() {
  local iface="$1"
  local ssid="$2"
  local refresh_rate="${3:-300}"

  local cached
  cached=$(read_ip_cache "$iface" "$ssid" "$refresh_rate")
  if [[ -n $cached ]]; then
    printf '%s\n' "$cached"
    return
  fi

  # Rate-limit backoff: if another pane already fetched recently, reuse silence
  local backoff_half=$((refresh_rate / 2))
  ((backoff_half < 30)) && backoff_half=30
  if [[ -f $FETCH_BACKOFF_FILE ]]; then
    local backoff_time
    backoff_time=$(cat "$FETCH_BACKOFF_FILE" 2>/dev/null)
    local now
    now=$(date +%s)
    if [[ $((now - backoff_time)) -lt $backoff_half ]]; then
      return
    fi
  fi

  # Signal that we're attempting a fetch (atomic-ish for bash)
  date +%s >"$FETCH_BACKOFF_FILE"

  local fresh
  fresh=$(fetch_public_ip)
  if [[ -n $fresh ]]; then
    local ip="${fresh%|*}"
    local code="${fresh#*|}"
    local dns=""
    dns=$(get_active_dns "$iface")
    write_ip_cache "$ip" "$code" "$dns" "$iface" "$ssid"
    printf '%s\n' "$fresh"
  fi
}

# Get cached DNS server (reads from shared IP/DNS cache)
function get_cached_dns() {
  local iface="$1"
  local ssid="$2"
  local refresh_rate="${3:-300}"

  local cached
  cached=$(read_ip_cache "$iface" "$ssid" "$refresh_rate")
  [[ -z $cached ]] && return

  # Cache is fresh — source to get ACTIVE_DNS
  [[ -f $IP_CACHE_FILE ]] && source "$IP_CACHE_FILE"
  echo "$ACTIVE_DNS"
}

# Convert two-letter country code to flag emoji
function country_flag() {
  local code="$1"
  [[ ${#code} -ne 2 ]] && return
  local base=0x1F1E6
  local c1 c2
  c1=$(printf '%x' $((base + $(printf '%d' "'${code:0:1}") - 65)))
  c2=$(printf '%x' $((base + $(printf '%d' "'${code:1:1}") - 65)))
  printf "\U$c1\U$c2"
}

# Get active DNS server IP
function get_active_dns() {
  local interface="$1"
  local dns=""

  if [[ "$(uname)" == "Linux" ]]; then
    # resolvectl (systemd-resolved)
    if command -v resolvectl >/dev/null; then
      dns=$(resolvectl status "$interface" 2>/dev/null | grep 'Current DNS Server' | awk '{print $NF}')
    fi
    # /etc/resolv.conf (skip local stubs)
    if [[ -z $dns ]] && [[ -r /etc/resolv.conf ]]; then
      dns=$(awk '/^nameserver/ && $2 !~ /^127\./ {print $2; exit}' /etc/resolv.conf)
    fi
    # nmcli
    if [[ -z $dns ]] && command -v nmcli >/dev/null; then
      dns=$(nmcli dev show "$interface" 2>/dev/null | grep 'IP4.DNS\[' | awk '{print $2}' | head -1)
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    dns=$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]\]/ && $3 !~ /^127\./ && $3 !~ /^fe80/ {print $3; exit}')
  fi

  echo "$dns"
}
