#!/usr/bin/env python3
"""
Python script to configure a transparent bridge with Ethernet WAN, Ethernet LAN (if present),
and a Wi-Fi Access Point on a Raspberry Pi using NetworkManager (nmcli).
"""
import subprocess
import sys
import getpass
import shutil

def run(cmd, check=True):
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and result.returncode != 0:
        print(f"[ERROR] Command failed ({result.returncode}): {result.stderr.strip()}")
        sys.exit(result.returncode)
    return result.stdout.strip()

def ask(prompt):
    return input(prompt)

def ask_password(prompt):
    return getpass.getpass(prompt)

def detect_interfaces():
    out = run("nmcli device status | awk '$2==\"ethernet\"{print $1}'", check=False)
    eth = [line for line in out.splitlines() if line]
    out = run("nmcli device status | awk '$2==\"wifi\"{print $1; exit}'", check=False)
    wifi = out.strip()
    if not eth:
        print("[ERROR] No Ethernet interface found. Exiting.")
        sys.exit(1)
    eth0 = eth[0]
    eth1 = eth[1] if len(eth) > 1 else None
    if not eth1:
        print(f"[WARN] Only one Ethernet detected ({eth0}). Secondary slave will be skipped.")
    return eth0, eth1, wifi

def validate_password(pw):
    if len(pw) < 8:
        print("Password must be at least 8 characters.")
        return False
    if not any(c.isupper() for c in pw):
        print("Password must include at least one uppercase letter.")
        return False
    if not any(c.isdigit() for c in pw):
        print("Password must include at least one digit.")
        return False
    return True

def main():
    # Check prerequisites
    if not shutil.which("nmcli"):
        print("[ERROR] nmcli not found. Install NetworkManager first.")
        sys.exit(1)

    # Ask for sudo user to grant passwordless nmcli
    sudo_user = ask("Enter the username to allow nmcli without sudo password: ")

    # System update and install required packages
    run("sudo apt update && sudo apt full-upgrade -y")
    pkgs = ["network-manager", "bridge-utils", "dnsmasq", "hostapd", "iproute2", "apache2", "libapache2-mod-php"]
    run("sudo apt install -y " + " ".join(pkgs))

    # Cleanup existing connections (except loopback)
    run("nmcli -t -f NAME,TYPE con show | grep -v loopback | awk -F: '{print $1}' | xargs -r sudo nmcli con delete", check=False)

    # Stop and disable dhcpcd
    run("sudo systemctl stop dhcpcd", check=False)
    run("sudo systemctl disable dhcpcd", check=False)

    # Enable and start NetworkManager
    run("sudo systemctl enable NetworkManager")
    run("sudo systemctl start NetworkManager")

    # Detect interfaces
    eth0, eth1, wifi_iface = detect_interfaces()

    # Create bridge and attach Ethernet interfaces
    run("sudo nmcli con add type bridge ifname br0 con-name br0 autoconnect yes")
    run(f"sudo nmcli con add type ethernet ifname {eth0} con-name br0-eth0 master br0 autoconnect yes")
    if eth1:
        run(f"sudo nmcli con add type ethernet ifname {eth1} con-name br0-eth1 master br0 autoconnect yes")
    # Configure DHCP on bridge
    run("sudo nmcli con modify br0 ipv4.method auto ipv6.method ignore")
    # Bring up bridge and slaves
    run("sudo nmcli con up br0")
    run("sudo nmcli con up br0-eth0")
    if eth1:
        run("sudo nmcli con up br0-eth1")

    # Configure Wi-Fi Access Point
    print("\n=== Wi-Fi Access Point Configuration ===")
    ssid = ask("Enter desired WiFi SSID: ")
    while True:
        pw1 = ask_password("Enter WiFi password (min 8 chars, incl. uppercase and digits): ")
        pw2 = ask_password("Confirm password: ")
        if pw1 != pw2:
            print("Passwords do not match. Try again.")
            continue
        if not validate_password(pw1):
            continue
        break
    print(f"SSID configured: {ssid}")

    # Create and configure hotspot
    run(f"sudo nmcli con add type wifi ifname {wifi_iface} con-name hotspot ssid '{ssid}' mode ap")
    run("sudo nmcli con modify hotspot 802-11-wireless.mode ap")
    run("sudo nmcli con modify hotspot wifi-sec.key-mgmt wpa-psk")
    run(f"sudo nmcli con modify hotspot wifi-sec.psk '{pw1}'")
    run("sudo nmcli con modify hotspot connection.master br0 connection.slave-type bridge")
    run("sudo nmcli con modify hotspot ipv4.method disabled")
    run("sudo nmcli con modify hotspot ipv6.method ignore")
    run("sudo nmcli con modify hotspot connection.autoconnect yes")
    run("sudo nmcli con up hotspot")

    # Ensure bridge and Wi-Fi are up
    run("sudo nmcli con up br0", check=False)
    run(f"sudo nmcli device connect {wifi_iface}", check=False)

    # Grant passwordless nmcli for user
    run(f"echo \"{sudo_user} ALL=(ALL) NOPASSWD: /usr/bin/nmcli\" | sudo tee /etc/sudoers.d/nmcli")

    # Final status
    print("\n=== Setup Complete: Connections Status ===")
    run("nmcli con show", check=False)
    run("nmcli device status", check=False)
    run("ip a show br0", check=False)

    # Reboot prompt
    if ask("Reboot now? (y/n): ").lower() == 'y':
        run("sudo reboot")

if __name__ == "__main__":
    main()
