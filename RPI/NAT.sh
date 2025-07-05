#!/usr/bin/env bash

# Raspberry Pi 3 (Bookworm) NAT router and Wi-Fi AP setup using nmcli
# WAN: eth0 (DHCP), LAN: eth1 (NAT), Wi-Fi AP: SSID RPI-WIFI, password online123

set -euo pipefail

# System update and upgrade
echo "Updating package lists..."
sudo apt update -y

echo "Upgrading installed packages..."
sudo apt full-upgrade -y

echo
# Configure WAN (eth0) with DHCP
echo "Setting up WAN on eth0 (DHCP)..."
sudo nmcli connection add \
  type ethernet ifname eth0 con-name WAN-eth0 ipv4.method auto autoconnect yes
sudo nmcli connection up WAN-eth0

echo
# Configure LAN (eth1) with IPv4 sharing (NAT)
echo "Setting up LAN on eth1 (IPv4 shared)..."
sudo nmcli connection add \
  type ethernet ifname eth1 con-name LAN-eth1 ipv4.method shared autoconnect yes
sudo nmcli connection up LAN-eth1

echo
# Configure Wi-Fi Access Point
SSID="RPI-WIFI"
PASSWORD="online123"
echo "Setting up Wi-Fi AP ($SSID)..."
sudo nmcli connection add \
  type wifi ifname wlan0 con-name AP-$SSID ssid $SSID autoconnect yes
sudo nmcli connection modify AP-$SSID \
  802-11-wireless.mode ap \
  802-11-wireless.band bg \
  ipv4.method shared \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "$PASSWORD"
sudo nmcli connection up AP-$SSID

echo
# Ensure all connections are active
echo "Ensuring all connections are up..."
sudo nmcli connection up WAN-eth0 || true
sudo nmcli connection up LAN-eth1 || true
sudo nmcli connection up AP-$SSID || true

echo
# Display active connections and IP addresses
echo "Active connections:"
sudo nmcli connection show --active

echo
# Display devices and IPv4 addresses
echo "Device IPs:"
sudo nmcli device show | grep -E 'GENERAL.DEVICE|IP4.ADDRESS' | sed 'N;s/\n/ -> /'

echo
# Done
echo "Setup complete: NAT router and AP are running."
