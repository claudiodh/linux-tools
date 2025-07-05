#!/usr/bin/env bash

# Script to set up Raspberry Pi as a Wi‑Fi AP (SSID: RPI-WIFI, WPA2-PSK: online123)
# Assumes wlan0 exists and NetworkManager is installed

set -euo pipefail

# 1) Remove any old profile named RPI-WIFI
echo "Removing existing RPI-WIFI profile (if any)..."
sudo nmcli connection delete RPI-WIFI 2>/dev/null || true

# 2) Create the hotspot connection profile
echo "Creating hotspot profile RPI-WIFI..."
sudo nmcli connection add type wifi \
  ifname wlan0 \
  con-name RPI-WIFI \
  ssid "RPI-WIFI" \
  autoconnect yes

# 3) Configure AP mode, band, NAT sharing, and WPA2 security
echo "Configuring AP mode, band, NAT and security..."
sudo nmcli connection modify RPI-WIFI \
  802-11-wireless.mode ap \
  802-11-wireless.band bg \
  ipv4.method shared \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "online123"

# 4) Activate the hotspot
echo "Activating hotspot..."
sudo nmcli connection up RPI-WIFI

# 5) Final status
echo
nmcli connection show RPI-WIFI | grep -E '802-11-wireless.mode|ipv4.method'
iw dev wlan0 info | grep type

echo
printf "Hotspot 'RPI-WIFI' is up and running.\n"
