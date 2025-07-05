#!/usr/bin/env bash

# Script to set up Raspberry Pi as a router & Wi-Fi AP (Bookworm on Pi3)
# WAN: eth0 (DHCP), LAN: eth1 (shared NAT), AP: SSID RPI-WIFI, WPA2-PSK online123
# Includes system upgrade, package install, regulatory domain, persistent settings, and boot-proof NM connections

set -euo pipefail

# 1) Update, upgrade system and install dependencies
echo "Updating and upgrading system; installing dependencies..."
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y apache2 php libapache2-mod-php tcpdump bridge-utils wireless-tools

# 2) Set Wi-Fi regulatory domain to Canada
echo "Setting regulatory domain to CA..."
sudo iw reg set CA

# 3) Persist IPv4 forwarding across reboots
echo "Persisting IPv4 forwarding in /etc/sysctl.conf..."
sudo sed -i 's/^#\(net\.ipv4\.ip_forward=1\)/\1/' /etc/sysctl.conf
sudo bash -c "sudo sysctl -p"

# 4) Configure WAN on eth0 (DHCP)
echo "Removing old WAN-eth0 profile (if exists)..."
sudo nmcli connection delete WAN-eth0 2>/dev/null || echo "No WAN-eth0 profile found; skipping"

echo "Configuring WAN on eth0..."
sudo nmcli connection add type ethernet ifname eth0 con-name WAN-eth0 ipv4.method auto autoconnect yes
sudo nmcli connection up WAN-eth0 || true

# 5) Configure LAN on eth1 (NAT shared)
echo "Removing old LAN-eth1 profile (if exists)..."
sudo nmcli connection delete LAN-eth1 2>/dev/null || echo "No LAN-eth1 profile found; skipping"

echo "Configuring LAN on eth1..."
sudo nmcli connection add type ethernet ifname eth1 con-name LAN-eth1 ipv4.method shared autoconnect yes
sudo nmcli connection up LAN-eth1 || true

# 6) Remove any old Wi-Fi profile named RPI-WIFI
echo "Removing existing RPI-WIFI profile (if exists)..."
sudo nmcli connection delete RPI-WIFI 2>/dev/null || echo "No RPI-WIFI profile found; skipping"

# 7) Create hotspot profile
echo "Creating hotspot RPI-WIFI..."
sudo nmcli connection add type wifi ifname wlan0 con-name RPI-WIFI ssid "RPI-WIFI" autoconnect yes

# 8) Configure AP mode, band, NAT sharing, and WPA2 security
echo "Configuring AP mode, band, NAT and security..."
sudo nmcli connection modify RPI-WIFI \
  802-11-wireless.mode ap \
  802-11-wireless.band bg \
  ipv4.method shared \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "online123"

# 9) Activate the hotspot
echo "Activating hotspot..."
sudo nmcli connection up RPI-WIFI

# 10) Status check
echo -e "\nFinal status:"
nmcli connection show WAN-eth0 LAN-eth1 RPI-WIFI | grep -E 'NAME|ipv4.method|802-11-wireless.mode'
iw dev wlan0 info | grep type
ip addr show eth0 | grep inet
ip addr show eth1 | grep inet

echo -e "\nSetup complete and boot-proof: all connections will auto-connect on reboot."
