#!/usr/bin/env bash

set -e

# ============================================================
# Fedora Wi-Fi Hotspot
# Installer
# ============================================================

INSTALL_DIR="/usr/local/lib/fedora-wifi-hotspot"
BIN="/usr/local/sbin/wifi-hotspot"

echo
echo "=========================================="
echo "     Fedora Wi-Fi Hotspot Installer"
echo "=========================================="
echo

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo "[✗] Please run the installer with sudo."
    echo
    echo "    sudo ./install.sh"
    exit 1
fi

# ------------------------------------------------------------
# Fedora check
# ------------------------------------------------------------

if [ ! -f /etc/fedora-release ]; then
    echo "[✗] This installer is intended for Fedora."
    exit 1
fi

echo "[✓] Fedora detected."

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

PACKAGES=(
    NetworkManager
    iproute
    iptables
    iw
    hostapd
    dnsmasq
)

echo "[*] Checking required packages..."

dnf install -y "${PACKAGES[@]}"

echo "[✓] Required packages installed."

# ------------------------------------------------------------
# Stop any running instance
# ------------------------------------------------------------

if command -v wifi-hotspot >/dev/null 2>&1; then
    echo "[*] Stopping existing hotspot instance..."
    wifi-hotspot stop >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# Create installation directory
# ------------------------------------------------------------

echo "[*] Installing application..."

mkdir -p "$INSTALL_DIR/lib"

# ------------------------------------------------------------
# Copy application
# ------------------------------------------------------------

cp wifi-hotspot "$INSTALL_DIR/wifi-hotspot"
cp wifi-hotspot-gui "$INSTALL_DIR/wifi-hotspot-gui"
cp lib/*.sh "$INSTALL_DIR/lib/"

chmod +x "$INSTALL_DIR/wifi-hotspot"
chmod +x "$INSTALL_DIR/wifi-hotspot-gui"
chmod +x "$INSTALL_DIR/lib/"*.sh

# ------------------------------------------------------------
# Install launcher & Desktop File
# ------------------------------------------------------------

cat > "$BIN" <<'EOF'
#!/usr/bin/env bash

exec /usr/local/lib/fedora-wifi-hotspot/wifi-hotspot "$@"
EOF

chmod +x "$BIN"

cat > /usr/share/applications/fedora-wifi-hotspot.desktop <<EOF
[Desktop Entry]
Name=Fedora Wi-Fi Hotspot
Comment=Create and manage a Wi-Fi Hotspot
Exec=$INSTALL_DIR/wifi-hotspot-gui
Icon=network-wireless-symbolic
Terminal=false
Type=Application
Categories=Settings;Network;
Keywords=wifi;hotspot;network;
StartupNotify=true
EOF

# Grant passwordless sudo to wheel group for the backend script
echo "%wheel ALL=(root) NOPASSWD: $INSTALL_DIR/wifi-hotspot" > /etc/sudoers.d/fedora-wifi-hotspot
chmod 440 /etc/sudoers.d/fedora-wifi-hotspot


# ------------------------------------------------------------
# Verify installation
# ------------------------------------------------------------

echo "[*] Verifying installation..."

bash -n "$INSTALL_DIR/wifi-hotspot"

for script in "$INSTALL_DIR/lib/"*.sh; do
    bash -n "$script"
done

if [ ! -x "$BIN" ]; then
    echo "[✗] Failed to install wifi-hotspot command."
    exit 1
fi

if ! "$BIN" --help >/dev/null 2>&1; then
    echo "[✗] Installed command failed verification."
    exit 1
fi

echo "[✓] Installation verified."

# ------------------------------------------------------------
# Complete
# ------------------------------------------------------------

echo
echo "=========================================="
echo "       Installation Complete"
echo "=========================================="
echo
echo "Run:"
echo
echo "    wifi-hotspot diagnose"
echo
echo "Then start your hotspot:"
echo
echo '    wifi-hotspot start --ssid "My Hotspot" --password "MyPassword123"'
echo
echo "Stop:"
echo
echo "    wifi-hotspot stop"
echo
echo "Status:"
echo
echo "    wifi-hotspot status"
echo

