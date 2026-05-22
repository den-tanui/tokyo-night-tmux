#!/usr/bin/env bats

setup() {
  if [[ $(uname) == "Darwin" ]]; then
    HOMEBREW_PREFIX=$(brew --prefix)
    load "${HOMEBREW_PREFIX}/lib/bats-mock/stub.bash"
  elif [[ -f /usr/lib/bats-mock/stub.bash ]]; then
    # System-wide install (Alpine CI, etc.)
    load /usr/lib/bats-mock/stub.bash
  else
    # Project-local install (Arch Linux, dev machines)
    load "${BATS_TEST_DIRNAME}/helpers/bats-mock/stub.bash"
  fi
  # shellcheck source=lib/netspeed.sh
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"

  # macOS stubs
  if [[ $(uname) == "Darwin" ]]; then
    stub route \
      "get default : echo -e '    gateway: 192.168.0.1\n  interface: en0\n      flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>'" \
      "get default : echo -e '    gateway: 192.168.1.1\n  interface: en1\n      flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>'" \
      "get default : echo -e '    gateway: 10.23.45.67\n  interface: utun4\n      flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>'"
    stub ipconfig \
      "getifaddr en0 : echo 172.17.0.2"
    stub netstat \
      "-ib : echo -e 'en0        1500  <Link#15>   49:2f:d3:60:03:33 79545944     0 67521187295 39466094     0 14135888609     0\nen0        1500  fake-host. fe80:f::123:beef: 79545944     - 67521187295 39466094     - 14135888609     -'"
  elif [[ $(uname) == "Linux" ]]; then
    stub ip \
      "addr show dev eth0 : echo -e '18: eth0@if19: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc noqueue state UP group default\n    link/ether 49:2f:d3:60:03:33 brd ff:ff:ff:ff:ff:ff link-netnsid 0\n    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0\n       valid_lft forever preferred_lft forever\n    inet6 fe80::b576:50dc:d0a6:8d9a/64 scope link\n       valid_lft forever preferred_lft forever'"
    stub ifconfig \
      "eth0 : echo -e 'eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 65535\n        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255\n        inet6 fe80::b576:50dc:d0a6:8d9a prefixlen 64  scopeid 0x20<link>\n        ether 49:2f:d3:60:03:33  txqueuelen 0  (Ethernet)\n        RX packets 3609  bytes 11565908 (11.0 MiB)\n        RX errors 0  dropped 0  overruns 0  frame 0\n        TX packets 2716  bytes 182918 (178.6 KiB)\n        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0'"
  fi
}

teardown() {
  if [[ $(uname) == "Darwin" ]]; then
    run unstub route
    run unstub ipconfig
    run unstub netstat
  elif [[ $(uname) == "Linux" ]]; then
    run unstub ip
    run unstub ifconfig
  fi
}

@test "Test get_bytes (macOS)" {
  # Skip test if not on macOS
  if [[ $(uname) != "Darwin" ]]; then
    skip
  fi
  run get_bytes en0
  [[ $output == "67521187295 14135888609" ]]
}

@test "Test readable_format" {
  run readable_format 1024
  [[ $output == "1.0KB/s" ]]
  run readable_format 1048576
  [[ $output == "1.0MB/s" ]]
  run readable_format 34829287
  [[ $output == "33.2MB/s" ]]
}

@test "Test readable_format with delay" {
  run readable_format 34829287 1.0
  [[ $output == "33.2MB/s" ]]
  run readable_format 19578465 3
  [[ $output == "6.2MB/s" ]]
  run readable_format 29584754 2.5
  [[ $output == "11.2MB/s" ]]
}

@test "Test find_interface (macOS)" {
  # Skip test if not on macOS
  if [[ $(uname) != "Darwin" ]]; then
    skip
  fi

  # en0 wifi
  run find_interface
  [[ $output == "en0" ]]
  # en1 wired
  run find_interface
  [[ $output == "en1" ]]
  # utun4 vpn
  run find_interface
  [[ $output == "en0" ]] # should fallback to en0
}

@test "Test interface_ipv4 (Linux)" {
  # Skip test if not on Linux
  if [[ $(uname) != "Linux" ]]; then
    skip
  fi

  # Test docker local IP
  run interface_ipv4 eth0
  [[ $output == "172.17.0.2" ]]
  [[ $status == 0 ]]

  # Test non-existing interface
  run interface_ipv4 eth69
  [[ $output == "" ]]
  [[ $status == 1 ]]
}

@test "Test interface_ipv4 (macOS)" {
  # Skip test if not on Linux
  if [[ $(uname) != "Darwin" ]]; then
    skip
  fi

  # Test docker local IP
  run interface_ipv4 en0
  [[ $output == "172.17.0.2" ]]
  [[ $status == 0 ]]

  # Test non-existing interface
  run interface_ipv4 en69
  [[ $output == "" ]]
  [[ $status == 1 ]]
}

@test "Test signal_icon levels" {
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"
  # No signal / empty
  run signal_icon ""
  [[ -n $output ]]
  # Level 1
  run signal_icon 10
  [[ -n $output ]]
  # Level 2
  run signal_icon 30
  [[ -n $output ]]
  # Level 3
  run signal_icon 50
  [[ -n $output ]]
  # Level 4
  run signal_icon 70
  [[ -n $output ]]
  # Level 5
  run signal_icon 90
  [[ -n $output ]]
}

@test "Test country_flag known codes" {
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"
  # US flag
  run country_flag "US"
  [[ -n $output ]]
  # DE flag
  run country_flag "DE"
  [[ -n $output ]]
  # JP flag
  run country_flag "JP"
  [[ -n $output ]]
  # Invalid: single char
  run country_flag "U"
  [[ -z $output ]]
}

@test "Test write and read ip cache" {
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "wlan0" "MyWiFi"
  [[ -f $tmp_cache ]]

  run read_ip_cache "wlan0" "MyWiFi" "3600"
  [[ $output == "203.0.113.42|US" ]]

  rm -f "$tmp_cache"
}

@test "Test read_ip_cache returns empty for stale data" {
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "wlan0" "MyWiFi"
  # Use 0-second refresh rate to force stale
  run read_ip_cache "wlan0" "MyWiFi" "0"
  [[ -z $output ]]

  rm -f "$tmp_cache"
}

@test "Test read_ip_cache returns empty on iface change" {
  source "${BATS_TEST_DIRNAME}/../lib/netspeed.sh"
  local tmp_cache
  tmp_cache=$(mktemp)
  IP_CACHE_FILE="$tmp_cache"

  write_ip_cache "203.0.113.42" "US" "wlan0" "MyWiFi"
  # Different interface
  run read_ip_cache "eth0" "MyWiFi" "3600"
  [[ -z $output ]]

  rm -f "$tmp_cache"
}
