#!/bin/bash
# fix-wifi.sh — Fix RTL8821CS (BL-M8821) WiFi on Indiedroid Nova
# Tested on: Debian 12 Bookworm / Kernel 6.1.0-1023-rockchip
# Also applicable to Ubuntu 24.04 Noble on the same hardware
#
# Problem: WiFi shows "unavailable" in NetworkManager due to:
#   1. SDIO timing bug — driver loads before bus is ready (known issue)
#   2. Missing wpasupplicant — NM can't manage WiFi without it (the part nobody caught)
#
# Reference: https://github.com/Joshua-Riek/ubuntu-rockchip/issues/1007
# Author: TrevTron

set -e

echo "=== Indiedroid Nova WiFi Fix ==="
echo ""

# Step 1: Install required packages
echo "[1/3] Installing firmware and WiFi packages..."
sudo apt-get update -qq
sudo apt-get install -y firmware-realtek wpasupplicant wireless-regdb iw rfkill

# Step 2: Create systemd service for driver reload workaround
echo "[2/3] Creating fix-wifi systemd service..."
sudo tee /etc/systemd/system/fix-wifi.service > /dev/null << 'EOF'
[Unit]
Description=Reload RTL8821CS WiFi driver (workaround for SDIO timing bug)
After=network-pre.target
Before=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'rmmod rtw88_8821cs rtw88_8821c rtw88_sdio rtw88_core 2>/dev/null; sleep 2; modprobe rtw88_8821cs'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fix-wifi.service

# Step 3: Prompt for reboot
echo "[3/3] Done!"
echo ""
echo "Reboot to apply the fix:"
echo "  sudo reboot"
echo ""
echo "After reboot, connect to WiFi:"
echo "  nmcli dev wifi list"
echo "  sudo nmcli dev wifi connect \"YourSSID\" password \"YourPassword\""
echo ""
echo "Chip info:"
echo "  Module: BL-M8821 (Realtek RTL8821CS)"
echo "  SDIO ID: 024C:C821"
echo "  Driver: rtw88_8821cs"
echo "  Firmware: rtw8821c_fw.bin"
