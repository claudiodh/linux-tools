#!/bin/bash

# Raspberry Pi Router Script (Bookworm compatible)
# WAN: eth0 | LAN: eth1 | Wi-Fi AP: RPI-WIFI

set -e

echo "🔄 Updating system..."
sudo apt update
sudo apt full-upgrade -y

echo "📦 Installing required packages..."
sudo apt install -y network-manager iptables-persistent

echo "🚀 Enabling NetworkManager..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# =============== Configure WAN (eth0) ===============
echo "🌐 Configuring eth0 as WAN (DHCP)"
nmcli con delete eth0-wan 2>/dev/null || true
nmcli con add type ethernet ifname eth0 con-name eth0-wan
nmcli con modify eth0-wan ipv4.method auto
nmcli con up eth0-wan

# =============== Configure LAN (eth1) ===============
echo "📡 Configuring eth1 as LAN (static + DHCP)"
nmcli con delete eth1-lan 2>/dev/null || true
nmcli con add type ethernet ifname eth1 con-name eth1-lan
nmcli con modify eth1-lan ipv4.addresses 192.168.50.1/24
nmcli con modify eth1-lan ipv4.method manual
nmcli con modify eth1-lan ipv4.never-default yes
nmcli con modify eth1-lan ipv4.dhcp-server yes
nmcli con modify eth1-lan ipv4.dhcp-ranges "192.168.50.10 192.168.50.100"
nmcli con up eth1-lan

# =============== Configure Wi-Fi Hotspot ===============
echo "📶 Setting up Wi-Fi Access Point"
nmcli radio wifi on
nmcli con delete rpi-hotspot 2>/dev/null || true
nmcli dev wifi hotspot ifname wlan0 ssid RPI-WIFI password online123
nmcli con modify Hotspot connection.autoconnect yes
nmcli con modify Hotspot ipv4.method shared
nmcli con up Hotspot

# =============== Enable IP Forwarding and NAT ===============
echo "🔁 Enabling NAT and IP forwarding"
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save

echo "✅ Setup complete! RPI is now a router with Wi-Fi hotspot."
