#!/usr/bin/env bash
#<------------------------------Netspeed widget for TMUX------------------------------------>
# author : @tribhuwan-kumar
# email : freakybytes@duck.com
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
# Show IP address (0=off, local=local only, public=public only, 1|both=both)
SHOW_IP=$(tmux show-option -gv @tokyo-night-tmux_netspeed_showip 2>/dev/null)
SHOW_IP="${SHOW_IP:-local}"
# Time between refresh
TIME_DIFF=$(tmux show-option -gv @tokyo-night-tmux_netspeed_refresh 2>/dev/null)
TIME_DIFF=${TIME_DIFF:-1}
# Public IP refresh rate in seconds (default: 5 minutes)
IP_REFRESH_RATE=$(tmux show-option -gv @tokyo-night-tmux_netspeed_ip_refresh_rate 2>/dev/null)
IP_REFRESH_RATE=${IP_REFRESH_RATE:-300}
# SSID and signal refresh rate in seconds (default: 10)
SIGNAL_REFRESH_RATE=$(tmux show-option -gv @tokyo-night-tmux_netspeed_signal_refresh_rate 2>/dev/null)
SIGNAL_REFRESH_RATE=${SIGNAL_REFRESH_RATE:-10}
# Show country flag
SHOW_COUNTRY=$(tmux show-option -gv @tokyo-night-tmux_netspeed_show_country 2>/dev/null)
SHOW_COUNTRY="${SHOW_COUNTRY:-1}"
# Show active DNS server
SHOW_DNS=$(tmux show-option -gv @tokyo-night-tmux_netspeed_show_dns 2>/dev/null)
SHOW_DNS="${SHOW_DNS:-1}"

# Full mode override: show all info when displayed on the second status line
if [[ ${TOKYO_NETSPEED_FULL} -eq 1 ]]; then
  SHOW_IP="both"
  SHOW_COUNTRY=1
  SHOW_DNS=1
fi

# Icons
declare -A NET_ICONS
NET_ICONS[wifi_up]="#[fg=${THEME[foreground]}]\U000f05a9"   # nf-md-wifi
NET_ICONS[wifi_down]="#[fg=${THEME[red]}]\U000f05aa"        # nf-md-wifi_off
NET_ICONS[wired_up]="#[fg=${THEME[foreground]}]\U000f0318"  # nf-md-lan_connect
NET_ICONS[wired_down]="#[fg=${THEME[red]}]\U000f0319"       # nf-md-lan_disconnect
NET_ICONS[traffic_tx]="#[fg=${THEME[bblue]}]\U000f06f6"     # nf-md-upload_network
NET_ICONS[traffic_rx]="#[fg=${THEME[bgreen]}]\U000f06f4"    # nf-md-download_network
NET_ICONS[ip]="#[fg=${THEME[foreground]}]\U000f0a5f"        # nf-md-ip
NET_ICONS[public_ip]="#[fg=${THEME[foreground]}]\U000f0589" # nf-md-earth (globe = public IP)
NET_ICONS[dns]="#[fg=${THEME[foreground]}]\U000f0e14"       # nf-md-dns

# Determine interface if not set
if [[ -z $INTERFACE ]]; then
  INTERFACE=$(find_interface)
  [[ -z $INTERFACE ]] && exit 1
  # Update tmux option for this session
  tmux set-option -g @tokyo-night-tmux_netspeed_iface "$INTERFACE"
fi

# Echo network speed
read -r RX1 TX1 < <(get_bytes "$INTERFACE")
sleep "$TIME_DIFF"
read -r RX2 TX2 < <(get_bytes "$INTERFACE")

RX_DIFF=$((RX2 - RX1))
TX_DIFF=$((TX2 - TX1))

RX_SPEED="#[fg=${THEME[foreground]}]$(readable_format "$RX_DIFF" "$TIME_DIFF")"
TX_SPEED="#[fg=${THEME[foreground]}]$(readable_format "$TX_DIFF" "$TIME_DIFF")"

# Interface icon
if [[ ${INTERFACE} == "en0" ]] || [[ -d /sys/class/net/${INTERFACE}/wireless ]]; then
  IFACE_TYPE="wifi"
else
  IFACE_TYPE="wired"
fi

# Detect interface IPv4 and state
if IPV4_ADDR=$(interface_ipv4 "$INTERFACE"); then
  IFACE_STATUS="up"
else
  IFACE_STATUS="down"
fi

# SSID and signal strength (WiFi only) — cached at IP refresh rate to avoid iw/iwconfig every second
SSID=""
SIGNAL_PCT=""
if [[ $IFACE_TYPE == "wifi" ]]; then
  cached=$(read_signal_cache "$INTERFACE" "$SIGNAL_REFRESH_RATE")
  if [[ -n $cached ]]; then
    SSID="${cached%|*}"
    SIGNAL_PCT="${cached#*|}"
    # SIGNAL_PCT might be empty string after the pipe if it was missing
    [[ "$SIGNAL_PCT" == "$SSID" ]] && SIGNAL_PCT=""
  else
    SSID=$(get_ssid "$INTERFACE")
    SIGNAL_PCT=$(get_signal_strength "$INTERFACE")
    write_signal_cache "$SSID" "$SIGNAL_PCT" "$INTERFACE"
  fi
fi

# Public IP and country (WiFi only)
PUBLIC_IP=""
COUNTRY_CODE=""
if [[ -n $SSID ]]; then
  public_info=$(get_public_ip_info "$INTERFACE" "$SSID" "$IP_REFRESH_RATE")
  if [[ -n $public_info ]]; then
    PUBLIC_IP="${public_info%|*}"
    COUNTRY_CODE="${public_info#*|}"
  fi
fi

# Active DNS server (any interface)
ACTIVE_DNS=""
if [[ ${SHOW_DNS} -eq 1 ]]; then
  ACTIVE_DNS=$(get_active_dns "$INTERFACE")
fi

NETWORK_ICON=${NET_ICONS[${IFACE_TYPE}_${IFACE_STATUS}]}
SEP="#[dim]│#[nodim] "

OUTPUT="${RESET}░ "

# ── Group 1: Identity (DNS + IPs) ────────────────────────────
HAS_IDENTITY=0

if [[ ${SHOW_DNS} -eq 1 ]] && [[ -n $ACTIVE_DNS ]]; then
  OUTPUT+="${NET_ICONS[dns]} #[dim]$ACTIVE_DNS "
  HAS_IDENTITY=1
fi

# Build IP string first so we can prepend SEP once for the whole IP block
IP_STR=""
case "$SHOW_IP" in
0) ;; # off
local)
  if [[ -n $IPV4_ADDR ]]; then
    IP_STR="${NET_ICONS[ip]} #[dim]$IPV4_ADDR "
  fi
  ;;
public)
  if [[ -n $PUBLIC_IP ]]; then
    IP_STR="${NET_ICONS[public_ip]} #[dim]$PUBLIC_IP "
    if [[ ${SHOW_COUNTRY} -eq 1 ]] && [[ -n $COUNTRY_CODE ]]; then
      IP_STR+="$(country_flag "$COUNTRY_CODE") "
    fi
  fi
  ;;
1 | both)
  if [[ -n $IPV4_ADDR ]]; then
    IP_STR="${NET_ICONS[ip]} #[dim]$IPV4_ADDR "
  fi
  if [[ -n $PUBLIC_IP ]]; then
    IP_STR+="${NET_ICONS[public_ip]} #[dim]$PUBLIC_IP "
    if [[ ${SHOW_COUNTRY} -eq 1 ]] && [[ -n $COUNTRY_CODE ]]; then
      IP_STR+="$(country_flag "$COUNTRY_CODE") "
    fi
  fi
  ;;
esac
if [[ -n $IP_STR ]]; then
  [[ $HAS_IDENTITY -eq 1 ]] && OUTPUT+="$SEP"
  OUTPUT+="$IP_STR"
  HAS_IDENTITY=1
fi

# ── Group 2: Connection (SSID or interface) ──────────────────
[[ $HAS_IDENTITY -eq 1 ]] && OUTPUT+="$SEP"
if [[ -n $SSID ]]; then
  if [[ -n $SIGNAL_PCT ]]; then
    if [[ $SIGNAL_PCT -le 30 ]]; then
      color="${THEME[red]}"
    elif [[ $SIGNAL_PCT -le 65 ]]; then
      color="${THEME[yellow]}"
    else
      color="${THEME[green]}"
    fi
    OUTPUT+="#[fg=${color}]${SIGNAL_PCT}% #[fg=${THEME[foreground]}]"
  else
    OUTPUT+="${NET_ICONS[wifi_up]} "
  fi
  OUTPUT+="${SSID} "
else
  OUTPUT+="$NETWORK_ICON #[dim]$INTERFACE "
fi

# ── Group 3: Traffic (RX + TX) at the far right ──────────────
OUTPUT+="$SEP${NET_ICONS[traffic_rx]} $RX_SPEED ${NET_ICONS[traffic_tx]} $TX_SPEED "

echo -e "$OUTPUT"
