#!/usr/bin/env bash
#<------------------------------Netinfo widget for TMUX------------------------------------->
# Shows network information: SSID, signal, private IP, public IP, DNS, country flag.
# Controlled by NETINFO_SHOW env var (empty = all, or one of: ssid|signal|privateip|publicip|dns)
#<------------------------------------------------------------------------------------------>

# Determine which mode we're in
SHOW_MODE="${NETINFO_SHOW:-netinfo}"

# Check if enabled — checks show_<mode> then widget_enabled_<mode>
ENABLED=$(tmux show-option -gv "@tokyo-night-tmux_show_${SHOW_MODE}" 2>/dev/null)
[[ "${ENABLED}" == "0" ]] && exit 0
[[ ${ENABLED} -ne 1 ]] && ENABLED=$(tmux show-option -gv "@tokyo-night-tmux_widget_enabled_${SHOW_MODE}" 2>/dev/null)
[[ ${ENABLED} -ne 1 ]] && exit 0

# Imports
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source "$ROOT_DIR/src/themes.sh"
source "$ROOT_DIR/lib/netspeed.sh"

# Configuration
INTERFACE=$(tmux show-option -gv @tokyo-night-tmux_netspeed_iface 2>/dev/null)
SHOW_IP=$(tmux show-option -gv @tokyo-night-tmux_netinfo_showip 2>/dev/null)
SHOW_IP="${SHOW_IP:-local}"
SHOW_FLAG=$(tmux show-option -gv @tokyo-night-tmux_netinfo_show_flag 2>/dev/null)
SHOW_FLAG="${SHOW_FLAG:-1}"
SHOW_DNS=$(tmux show-option -gv @tokyo-night-tmux_netinfo_show_dns 2>/dev/null)
SHOW_DNS="${SHOW_DNS:-1}"
IP_REFRESH_RATE=$(tmux show-option -gv @tokyo-night-tmux_netinfo_ip_refresh_rate 2>/dev/null)
IP_REFRESH_RATE=${IP_REFRESH_RATE:-300}
SIGNAL_REFRESH_RATE=$(tmux show-option -gv @tokyo-night-tmux_netinfo_signal_refresh_rate 2>/dev/null)
SIGNAL_REFRESH_RATE=${SIGNAL_REFRESH_RATE:-10}

# Determine interface if not set
if [[ -z $INTERFACE ]]; then
  INTERFACE=$(find_interface)
  [[ -z $INTERFACE ]] && exit 1
  tmux set-option -g @tokyo-night-tmux_netspeed_iface "$INTERFACE"
fi

# Detect interface type and IPv4
if [[ ${INTERFACE} == "en0" ]] || [[ -d /sys/class/net/${INTERFACE}/wireless ]]; then
  IFACE_TYPE="wifi"
else
  IFACE_TYPE="wired"
fi

if IPV4_ADDR=$(interface_ipv4 "$INTERFACE"); then
  IFACE_STATUS="up"
else
  IFACE_STATUS="down"
fi

[[ $IFACE_STATUS == "down" ]] && exit 0

# SSID and signal (WiFi only)
SSID=""
SIGNAL_PCT=""
if [[ $IFACE_TYPE == "wifi" ]]; then
  cached=$(read_signal_cache "$INTERFACE" "$SIGNAL_REFRESH_RATE")
  if [[ -n $cached ]]; then
    SSID="${cached%|*}"
    SIGNAL_PCT="${cached#*|}"
    [[ "$SIGNAL_PCT" == "$SSID" ]] && SIGNAL_PCT=""
  else
    SSID=$(get_ssid "$INTERFACE")
    SIGNAL_PCT=$(get_signal_strength "$INTERFACE")
    write_signal_cache "$SSID" "$SIGNAL_PCT" "$INTERFACE"
  fi
fi

# Public IP, country, DNS (any interface, cached)
PUBLIC_IP=""
COUNTRY_CODE=""
ACTIVE_DNS=""
public_info=$(get_public_ip_info "$INTERFACE" "$SSID" "$IP_REFRESH_RATE")
if [[ -n $public_info ]]; then
  PUBLIC_IP="${public_info%|*}"
  COUNTRY_CODE="${public_info#*|}"
fi
ACTIVE_DNS=$(get_cached_dns "$INTERFACE" "$SSID" "$IP_REFRESH_RATE")

SEP="#[dim]│#[nodim] "

# ── Output ──────────────────────────────────────────────────────
MODE="$SHOW_MODE"

if [[ $MODE == "netinfo" ]]; then
  # Monolithic: show everything that's enabled
  OUTPUT="${RESET}░ "

  # Identity group: DNS + IPs
  HAS_IDENTITY=0
  if [[ ${SHOW_DNS} -eq 1 ]] && [[ -n $ACTIVE_DNS ]]; then
    OUTPUT+="#[fg=${THEME[foreground]}]\U000f0e14#[dim] $ACTIVE_DNS "
    HAS_IDENTITY=1
  fi

  IP_STR=""
  case "$SHOW_IP" in
    0) ;;
    local)
      if [[ -n $IPV4_ADDR ]]; then
        IP_STR="#[fg=${THEME[foreground]}]\U000f0a5f#[dim] $IPV4_ADDR "
      fi
      ;;
    public)
      if [[ -n $PUBLIC_IP ]]; then
        IP_STR="#[fg=${THEME[foreground]}]\U000f0589#[dim] $PUBLIC_IP "
        if [[ ${SHOW_FLAG} -eq 1 ]] && [[ -n $COUNTRY_CODE ]]; then
          IP_STR+="$(country_flag "$COUNTRY_CODE") "
        fi
      fi
      ;;
    1 | both)
      if [[ -n $IPV4_ADDR ]]; then
        IP_STR="#[fg=${THEME[foreground]}]\U000f0a5f#[dim] $IPV4_ADDR "
      fi
      if [[ -n $PUBLIC_IP ]]; then
        IP_STR+="#[fg=${THEME[foreground]}]\U000f0589#[dim] $PUBLIC_IP "
        if [[ ${SHOW_FLAG} -eq 1 ]] && [[ -n $COUNTRY_CODE ]]; then
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

  # Connection: signal + SSID
  if [[ -n $SSID ]]; then
    [[ $HAS_IDENTITY -eq 1 ]] && OUTPUT+="$SEP"
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
      OUTPUT+="#[fg=${THEME[foreground]}]\U000f05a9 "
    fi
    OUTPUT+="${SSID} "
  fi

  echo -e "$OUTPUT"

elif [[ $MODE == "dns" ]]; then
  [[ -n $ACTIVE_DNS ]] && echo "${RESET}░ #[fg=${THEME[foreground]}]\U000f0e14#[dim] $ACTIVE_DNS "

elif [[ $MODE == "privateip" ]]; then
  [[ -n $IPV4_ADDR ]] && echo "${RESET}░ #[fg=${THEME[foreground]}]\U000f0a5f#[dim] $IPV4_ADDR "

elif [[ $MODE == "publicip" ]]; then
  if [[ -n $PUBLIC_IP ]]; then
    OUT="${RESET}░ #[fg=${THEME[foreground]}]\U000f0589#[dim] $PUBLIC_IP"
    [[ ${SHOW_FLAG} -eq 1 ]] && [[ -n $COUNTRY_CODE ]] && OUT+=" $(country_flag "$COUNTRY_CODE")"
    echo -e "$OUT "
  fi

elif [[ $MODE == "ssid" ]]; then
  if [[ -n $SSID ]]; then
    if [[ -n $SIGNAL_PCT ]]; then
      if [[ $SIGNAL_PCT -le 30 ]]; then
        color="${THEME[red]}"
      elif [[ $SIGNAL_PCT -le 65 ]]; then
        color="${THEME[yellow]}"
      else
        color="${THEME[green]}"
      fi
      echo "${RESET}░ #[fg=${color}]${SIGNAL_PCT}% #[fg=${THEME[foreground]}]${SSID} "
    else
      echo "${RESET}░ #[fg=${THEME[foreground]}]\U000f05a9 ${SSID} "
    fi
  fi

elif [[ $MODE == "signal" ]]; then
  if [[ -n $SIGNAL_PCT ]]; then
    if [[ $SIGNAL_PCT -le 30 ]]; then
      color="${THEME[red]}"
    elif [[ $SIGNAL_PCT -le 65 ]]; then
      color="${THEME[yellow]}"
    else
      color="${THEME[green]}"
    fi
    echo "${RESET}░ #[fg=${color}]${SIGNAL_PCT}% "
  fi
fi
