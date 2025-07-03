#!/bin/bash
set -e

echo "Setting up Raspberry Pi as a transparent bridge + WiFi hotspot..."

##########################################################
# STEP 0: CLEAN EXISTING CONNECTIONS (except loopback)
# --------------------------------------------
# This ensures no old or conflicting connections break
# our new bridge. We skip loopback to avoid system issues.
##########################################################

echo "Cleaning old NetworkManager connections..."
nmcli -t -f NAME,TYPE con show | grep -v ':loopback' | cut -d: -f1 | while read -r name; do
  echo "Deleting connection: $name"
  sudo nmcli con delete "$name"
done

##########################################################
# STEP 1: ENSURE NETWORKMANAGER IS ENABLED
# --------------------------------------------
# We disable dhcpcd because it conflicts with NetworkManager
# and can interfere with bridge/AP configurations.
##########################################################

echo "Enabling NetworkManager and disabling dhcpcd..."
sudo systemctl stop dhcpcd
sudo systemctl disable dhcpcd
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

##########################################################
# STEP 2: INSTALL REQUIRED PACKAGES
# --------------------------------------------
# These tools are required to manage networks and enable AP mode.
# - bridge-utils: for bridging interfaces
# - hostapd: required for Wi-Fi AP functionality
# - dnsmasq: (optional, not used here, but common in AP setups)
# - iproute2: for ip/bridge commands
##########################################################

echo "Installing required network packages.../"
sudo apt update
sudo apt install -y network-manager bridge-utils dnsmasq hostapd iproute2

##########################################################
# STEP 3: CREATE A BRIDGE AND ATTACH ETHERNET INTERFACES
# --------------------------------------------
# - br0 acts as a virtual switch between eth0 (WAN input)
#   and eth1 (LAN output).
# - Devices connected to eth1 will get IPs from the same
#   router that eth0 is connected to.
##########################################################

echo "Creating bridge 'br0' and adding eth0 + eth1 to it..."
sudo nmcli con add type bridge ifname br0 con-name br0 autoconnect yes
sudo nmcli con add type ethernet ifname eth0 master br0 con-name br0-eth0 autoconnect yes
sudo nmcli con add type ethernet ifname eth1 master br0 con-name br0-eth1 autoconnect yes
sudo nmcli con modify br0 ipv4.method auto ipv6.method ignore
sudo nmcli con up br0

##########################################################
# STEP 4: CONFIGURE WIFI ACCESS POINT BRIDGED TO br0
# --------------------------------------------
# - wlan0 is configured in AP (Access Point) mode.
# - It is bridged to br0 so clients receive IPs from the same router.
# - No NAT or local DHCP is configured; the router handles everything.
# - WPA2 with a pre-shared key is used for security.
##########################################################

echo "Creating WiFi Access Point (SSID: RPI-WIFI)..."
sudo nmcli con add type wifi ifname wlan0 con-name hotspot ssid RPI-WIFI mode ap
sudo nmcli con modify hotspot 802-11-wireless.mode ap
sudo nmcli con modify hotspot wifi-sec.key-mgmt wpa-psk
sudo nmcli con modify hotspot wifi-sec.psk "Online123"
sudo nmcli con modify hotspot connection.master br0 connection.slave-type bridge

# IP method disabled since IP handling is managed by the bridge
# and upstream router (through eth0)
echo "Disabling IP configuration for wlan0..."
sudo nmcli con modify hotspot ipv4.method disabled
sudo nmcli con modify hotspot ipv6.method ignore

# Activate connections
echo "Bringing up bridge and hotspot..."
sudo nmcli con up br0
sudo nmcli con up hotspot

##########################################################
# STEP 5: VERIFICATION AND FINAL STATUS
##########################################################

echo "Final status:"
nmcli con show
nmcli device status
ip a show br0
bridge link

echo "🎉 Raspberry Pi is now broadcasting 'RPI-WIFI' as a bridged hotspot!"
