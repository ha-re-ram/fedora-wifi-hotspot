#!/usr/bin/env bash

set -e

INSTALL_DIR="/usr/local/lib/fedora-wifi-hotspot"
BIN="/usr/local/sbin/wifi-hotspot"

echo
echo "=========================================="
echo "     Fedora Wi-Fi Hotspot Uninstaller"
echo "=========================================="
echo

if [ "$EUID" -ne 0 ]; then
    echo "[✗] Please run with sudo."
    echo
    echo "    sudo ./uninstall.sh"
    exit 1
fi

if [ -x "$BIN" ]; then
    echo "[*] Stopping hotspot..."
    "$BIN" stop >/dev/null 2>&1 || true
fi

echo "[*] Removing application..."

rm -rf "$INSTALL_DIR"
rm -f "$BIN"
rm -rf /run/fedora-wifi-hotspot
rm -f /usr/share/applications/fedora-wifi-hotspot.desktop
rm -f /etc/sudoers.d/fedora-wifi-hotspot

echo
echo "[✓] Fedora Wi-Fi Hotspot removed."
echo

