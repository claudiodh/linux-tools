Raspberry Pi Transparent Bridge + WiFi Hotspot Setup

This project provides a complete script to configure a Raspberry Pi (running Raspberry Pi OS Bookworm) as a transparent Ethernet bridge that also serves as a WiFi Access Point (Hotspot). The configuration allows any device connected to eth1 or the Pi’s WiFi network to receive IP addresses directly from the main router (connected to eth0) and be fully visible within the same LAN segment.

🔧 Why Use a Transparent Bridge?

A transparent bridge lets your Raspberry Pi forward packets at Layer 2 (Ethernet level) without acting as a router or modifying the IP configuration of connected devices. This is useful when:

You want to inspect, throttle, or monitor traffic transparently.

Devices behind the Pi should receive IPs from your main router (not from the Pi).

You want to use Linux networking tools like tc, iptables, or tcpdump on the Pi while staying in the same network as other devices.

This is ideal for:

Network testing setups

Filtering or quality control stations

IoT gateways with monitoring capability

⚙️ Architecture Overview

eth0 — Connected to the main router (with Internet access)

eth1 — Connected to a switch or downstream client devices

wlan0 — WiFi Access Point that also connects to the bridge

br0 — Virtual bridge interface linking all interfaces

All traffic is bridged via br0, and the main router’s DHCP server assigns IP addresses to any device using eth1 or WiFi.

✅ Features

Interactive prompts for secure SSID and WPA2 password

Validation of password strength (min 8 characters, uppercase, letters, numbers)

Automatic configuration of:

Bridge and Ethernet members

Hostapd-based WiFi hotspot

Autoconnect and persistent networking

Automatic installation of required packages (including Apache + PHP)

Automatic sudoers rule creation for nmcli

Smart error parsing to help troubleshoot common CLI issues

📜 How It Works

Cleans existing nmcli connections (except loopback) to prevent conflicts.

Disables dhcpcd, which is the default network manager on Raspberry Pi OS, and enables NetworkManager.

Installs all needed tools (network-manager, bridge-utils, dnsmasq, hostapd, apache2, libapache2-mod-php).

Creates a bridge (br0) and attaches both Ethernet interfaces to it.

Prompts the user to choose an SSID and password for the WiFi hotspot, with strong password validation.

Creates the hotspot in AP mode, bridges it to br0, disables its IP config (since DHCP will come from the router), and sets it to autoconnect.

Enables passwordless use of nmcli for the user online.

Verifies the configuration and shows key system info (bridge status, connections).

🚀 Usage

To execute the script on your Raspberry Pi:

chmod +x setup_bridge_hotspot.sh
./setup_bridge_hotspot.sh

You must run this script as a user with sudo privileges.

🧪 Verification Tools

nmcli con show — List active and inactive connections

nmcli device status — Show status of all interfaces

ip a show br0 — Display IP config for the bridge

bridge link — Show bridge members and their status

🛠️ Troubleshooting

If wlan0 doesn’t broadcast:

Check that it’s not blocked with rfkill list

Ensure your country is set correctly in /etc/hostapd/hostapd.conf

If devices don’t get an IP:

Make sure eth0 is connected to a router with DHCP enabled

Use tcpdump -i br0 to see if DHCP offers are reaching clients

🧾 Notes

This script assumes interfaces are named eth0, eth1, and wlan0. Adjust if yours are different (e.g., enx..., wlx...).

Devices connected to the Pi will share the same subnet and routing table as your router. No NAT or firewalling is done.

📄 License

MIT License
