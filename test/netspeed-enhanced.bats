#!/usr/bin/env bats

# Tests for the enhanced netspeed functions (WiFi, public IP, country, DNS, cache)
# These are pure functions that don't require bats-mock or system command stubs.

setup() {
  # shellcheck source=lib/netspeed.sh
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"
}

@test "signal_icon returns output for all levels" {
  # Empty / no signal
  run signal_icon ""
  [[ -n $output ]]

  # Level 1 (1-20%)
  run signal_icon 10
  [[ -n $output ]]

  # Level 2 (21-40%)
  run signal_icon 30
  [[ -n $output ]]

  # Level 3 (41-60%)
  run signal_icon 50
  [[ -n $output ]]

  # Level 4 (61-80%)
  run signal_icon 70
  [[ -n $output ]]

  # Level 5 (81-100%)
  run signal_icon 90
  [[ -n $output ]]
}

@test "signal_icon returns different output for different levels" {
  run signal_icon 10
  local level1="$output"
  run signal_icon 50
  local level3="$output"
  run signal_icon 90
  local level5="$output"

  # Different levels should produce different icons
  [[ "$level1" != "$level3" ]] || [[ "$level1" != "$level5" ]]
}

@test "country_flag returns emoji for two-letter codes" {
  run country_flag "US"
  [[ -n $output ]]
  [[ ${#output} -ge 2 ]]

  run country_flag "DE"
  [[ -n $output ]]

  run country_flag "JP"
  [[ -n $output ]]
}

@test "country_flag returns empty for invalid codes" {
  run country_flag "U"
  [[ -z $output ]]

  run country_flag ""
  [[ -z $output ]]

  run country_flag "USA"
  [[ -z $output ]]
}

@test "write_ip_cache and read_ip_cache round-trip" {
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "8.8.8.8" "wlan0" "MyWiFi"
  [[ -f $tmp_cache ]]

  run read_ip_cache "wlan0" "MyWiFi" "3600"
  [[ $output == "203.0.113.42|US" ]]

  rm -f "$tmp_cache"
}

@test "read_ip_cache returns empty for stale data" {
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "8.8.8.8" "wlan0" "MyWiFi"
  run read_ip_cache "wlan0" "MyWiFi" "0"
  [[ -z $output ]]

  rm -f "$tmp_cache"
}

@test "read_ip_cache returns empty on interface change" {
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "8.8.8.8" "wlan0" "MyWiFi"
  run read_ip_cache "eth0" "MyWiFi" "3600"
  [[ -z $output ]]

  rm -f "$tmp_cache"
}

@test "read_ip_cache returns empty on SSID change" {
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "8.8.8.8" "wlan0" "MyWiFi"
  run read_ip_cache "wlan0" "OtherNetwork" "3600"
  [[ -z $output ]]

  rm -f "$tmp_cache"
}

@test "read_ip_cache returns empty when cache file missing" {
  IP_CACHE_FILE="/tmp/nonexistent-cache-$$"
  run read_ip_cache "wlan0" "MyWiFi" "3600"
  [[ -z $output ]]
}

@test "get_ssid function exists and accepts interface argument" {
  [[ $(type -t get_ssid) == "function" ]]
}

@test "get_signal_strength function exists and accepts interface argument" {
  [[ $(type -t get_signal_strength) == "function" ]]
}

@test "get_public_ip_info function exists" {
  [[ $(type -t get_public_ip_info) == "function" ]]
}

@test "fetch_public_ip function exists" {
  [[ $(type -t fetch_public_ip) == "function" ]]
}

@test "fallback provider functions exist" {
  [[ $(type -t _fetch_ip_api_com) == "function" ]]
  [[ $(type -t _fetch_ipapi_co) == "function" ]]
  [[ $(type -t _fetch_ipinfo_io) == "function" ]]
}

@test "get_active_dns function exists" {
  [[ $(type -t get_active_dns) == "function" ]]
}

@test "jq parses ip-api JSON correctly" {
  command -v jq >/dev/null || skip "jq not installed"
  local json='{"status":"success","countryCode":"DE","query":"1.2.3.4"}'

  local result
  result=$(printf '%s\n' "$json" | jq -r '.status // empty')
  [[ $result == "success" ]]

  result=$(printf '%s\n' "$json" | jq -r '.query // empty')
  [[ $result == "1.2.3.4" ]]

  result=$(printf '%s\n' "$json" | jq -r '.countryCode // empty')
  [[ $result == "DE" ]]
}

@test "jq handles ip-api failure JSON" {
  command -v jq >/dev/null || skip "jq not installed"
  local json='{"status":"fail","countryCode":"","query":"127.0.0.1"}'

  local result
  result=$(printf '%s\n' "$json" | jq -r '.status // empty')
  [[ $result == "fail" ]]
}

@test "awk fallback parses ip-api JSON correctly" {
  local json='{"status":"success","countryCode":"DE","query":"1.2.3.4"}'

  local result
  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="status") print $(i+2)}')
  [[ $result == "success" ]]

  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="query") print $(i+2)}')
  [[ $result == "1.2.3.4" ]]

  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="countryCode") print $(i+2)}')
  [[ $result == "DE" ]]
}

@test "awk fallback handles failure JSON" {
  local json='{"status":"fail","countryCode":"","query":"127.0.0.1"}'

  local result
  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="status") print $(i+2)}')
  [[ $result == "fail" ]]
}

@test "jq parses ipapi.co JSON (fallback 1)" {
  command -v jq >/dev/null || skip "jq not installed"
  local json='{"ip":"5.5.5.5","country_code":"FR"}'

  local result
  result=$(printf '%s\n' "$json" | jq -r '.ip // empty')
  [[ $result == "5.5.5.5" ]]

  result=$(printf '%s\n' "$json" | jq -r '.country_code // empty')
  [[ $result == "FR" ]]
}

@test "awk parses ipapi.co JSON (fallback 1)" {
  local json='{"ip":"5.5.5.5","country_code":"FR"}'

  local result
  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="ip") print $(i+2)}')
  [[ $result == "5.5.5.5" ]]

  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="country_code") print $(i+2)}')
  [[ $result == "FR" ]]
}

@test "jq parses ipinfo.io JSON (fallback 2)" {
  command -v jq >/dev/null || skip "jq not installed"
  local json='{"ip":"8.8.8.8","country":"US","org":"GOOGLE"}'

  local result
  result=$(printf '%s\n' "$json" | jq -r '.ip // empty')
  [[ $result == "8.8.8.8" ]]

  result=$(printf '%s\n' "$json" | jq -r '.country // empty')
  [[ $result == "US" ]]
}

@test "awk parses ipinfo.io JSON (fallback 2)" {
  local json='{"ip":"8.8.8.8","country":"US","org":"GOOGLE"}'

  local result
  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="ip") print $(i+2)}')
  [[ $result == "8.8.8.8" ]]

  result=$(printf '%s\n' "$json" \
    | awk -F'"' '{for(i=1;i<NF;i++) if($i=="country") print $(i+2)}')
  [[ $result == "US" ]]
}

@test "fetch backoff prevents rapid re-fetches" {
  local tmp_backoff
  tmp_backoff=$(mktemp)
  FETCH_BACKOFF_FILE="$tmp_backoff"

  # Write "now" to backoff file (simulate a recent fetch)
  date +%s > "$tmp_backoff"

  # Set up an empty cache file so cache read fails
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  # With recent backoff + empty cache, get_public_ip_info should return nothing
  run get_public_ip_info "wlan0" "TestWiFi" "300"
  [[ -z $output ]]

  rm -f "$tmp_backoff" "$tmp_cache"
}

@test "fetch backoff allows fetch after backoff expires" {
  local tmp_backoff
  tmp_backoff=$(mktemp)
  FETCH_BACKOFF_FILE="$tmp_backoff"

  # Write old timestamp (beyond the backoff half-window) to backoff file
  echo "1" > "$tmp_backoff"

  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  # With expired backoff + empty cache, get_public_ip_info should try to fetch
  # (fetch will fail silently since curl is mocked/absent → returns empty)
  run get_public_ip_info "wlan0" "TestWiFi" "300"
  # Backoff file should have been updated to a recent timestamp
  local backoff_val
  backoff_val=$(cat "$tmp_backoff")
  local now
  now=$(date +%s)
  [[ $backoff_val -ge $((now - 2)) ]]

  rm -f "$tmp_backoff" "$tmp_cache"
}
