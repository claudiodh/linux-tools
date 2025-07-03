#!/bin/bash

# Enable debug output
set -x

set +e  # Allow script to continue even if a command fails

# Function to run a command safely and show real-time errors
safe_run() {
  local description="$1"
  shift
  echo "Running: $description..."
  # Execute command directly so errors report to stdout/stderr
  "$@"
  local code=$?
  if [ $code -ne 0 ]; then
    echo "[ERROR] Failed to: $description (exit code $code)"
    return $code
  fi
  return 0
}

# Detect interfaces dynamically with fallback
ETH_INTERFACES=( $(nmcli device status | awk '$2=="ethernet" {print $1}') )
WIFI_INTERFACE=$(nmcli device status | awk '$2=="wifi" {print $1; exit}')

if [ ${#ETH_INTERFACES[@]} -lt 1 ]; then
  echo "[ERROR] No ethernet interface found. Cannot proceed."
  exit 1
fi

ETH0=${ETH_INTERFACES[0]}
if [ ${#ETH_INTERFACES[@]} -ge 2 ]; then
  ETH1=${ETH_INTERFACES[1]}
else
  ETH1=""
  echo "[WARN] Only one ethernet detected ($ETH0). Skipping secondary slave."
fi

# ASK FOR USERNAME TO SET SUDOERS RULE
read -rp "Enter the username you want to allow nmcli without password: " SUDOUSER

# SYSTEM UPDATE
safe_run "update and upgrade system packages" sudo apt update && sudo apt full-upgrade -y

# INSTALL REQUIRED PACKAGES
safe_run "install required packages" sudo apt install -y network-manager bridge-utils dnsmasq hostapd iproute2 apache2 libapache2-mod-php


# REMOVE ALL EXISTING CONNECTION PROFILES (except loopback)
echo "Purging all existing NetworkManager connections..."
nmcli -t -f NAME,TYPE con show \
  | grep -v 'loopback' \
  | cut -d: -f1 \
  | while read -r con; do
    echo "Deleting connection profile: $con"
    sudo nmcli con delete "$con" 2>/dev/null || true
    sleep 0.1
  done


# Attempt to stop dhcpcd but ignore any errors
safe_run "stop dhcpcd" sudo systemctl stop dhcpcd || true

# Attempt to disable dhcpcd but ignore any errors
safe_run "disable dhcpcd" sudo systemctl disable dhcpcd || true


safe_run "enable NetworkManager" sudo systemctl enable NetworkManager
safe_run "start NetworkManager" sudo systemctl start NetworkManager

# CREATE BRIDGE AND ATTACH ETH INTERFACES
safe_run "add bridge interface br0" sudo nmcli con add type bridge ifname br0 con-name br0 autoconnect yes
safe_run "add $ETH0 to bridge" sudo nmcli con add type ethernet ifname "$ETH0" con-name br0-eth0 master br0
safe_run "enable autoconnect for br0-eth0" sudo nmcli con modify br0-eth0 connection.autoconnect yes
if [ -n "$ETH1" ]; then
  safe_run "add $ETH1 to bridge" sudo nmcli con add type ethernet ifname "$ETH1" con-name br0-eth1 master br0
  safe_run "enable autoconnect for br0-eth1" sudo nmcli con modify br0-eth1 connection.autoconnect yes
fi
safe_run "configure br0 for DHCP" sudo nmcli con modify br0 ipv4.method auto ipv6.method ignore
safe_run "bring up br0" sudo nmcli con up br0
safe_run "bring up br0-eth0" sudo nmcli con up br0-eth0
if [ -n "$ETH1" ]; then
  safe_run "bring up br0-eth1" sudo nmcli con up br0-eth1
fi

# ASK FOR SSID
read -rp "Enter desired WiFi SSID: " SSID
while true; do
  read -rsp "Enter WiFi password (min 8 chars, incl. uppercase, letters and numbers): " pass1
  echo
  read -rsp "Confirm password: " pass2
  echo

  if [[ "$pass1" != "$pass2" ]]; then
    echo "Passwords do not match. Try again."
    continue
  fi
  if [[ ${#pass1} -lt 8 ]]; then
    echo "Password must be at least 8 characters."
    continue
  fi
  if ! [[ "$pass1" =~ [A-Z] ]]; then
    echo "Password must include at least one uppercase letter."
    continue
  fi
  if ! [[ "$pass1" =~ [a-zA-Z] && "$pass1" =~ [0-9] ]]; then
    echo "Password must include both letters and numbers."
    continue
  fi
  break
done

# CONFIRM SSID AND PASSWORD
echo "WiFi SSID: $SSID"
echo "WiFi password: ***********${pass1: -3}"
read -rp "Apply these settings? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Setup canceled."
  exit 1
fi

# CONFIGURE HOTSPOT
safe_run "create hotspot connection" sudo nmcli con add type wifi ifname "$WIFI_INTERFACE" con-name hotspot ssid "$SSID" mode ap
safe_run "confirm AP mode" sudo nmcli con modify hotspot 802-11-wireless.mode ap
safe_run "set WPA2 key mgmt" sudo nmcli con modify hotspot wifi-sec.key-mgmt wpa-psk
safe_run "set WPA2 password" sudo nmcli con modify hotspot wifi-sec.psk "$pass1"
safe_run "bridge $WIFI_INTERFACE to br0" sudo nmcli con modify hotspot connection.master br0 connection.slave-type bridge
safe_run "disable IP config on $WIFI_INTERFACE" sudo nmcli con modify hotspot ipv4.method disabled
safe_run "disable IPv6 on $WIFI_INTERFACE" sudo nmcli con modify hotspot ipv6.method ignore
safe_run "set hotspot to autoconnect" sudo nmcli con modify hotspot connection.autoconnect yes
safe_run "ensure br0 gets IP via DHCP" sudo nmcli con modify br0 ipv4.method auto
safe_run "bring up hotspot" sudo nmcli con up hotspot

# FINAL VERIFICATION
nmcli con show
nmcli device status
ip a show br0
bridge link

# ADD SUDOERS RULE FOR NMCLI
echo "Adding passwordless sudo permission for nmcli for user: $SUDOUSER"
echo "$SUDOUSER ALL=(ALL) NOPASSWD: /usr/bin/nmcli" | sudo tee /etc/sudoers.d/nmcli > /dev/null

# REBOOT PROMPT
echo "Setup complete. Raspberry Pi is now broadcasting '$SSID'."
read -rp "Do you want to reboot now? (y/n): " reboot_confirm
if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "Y" ]]; then
  echo "Rebooting..."
  sudo reboot
else
  echo "Reboot skipped. You may need to reboot manually later."
fi
