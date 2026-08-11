#!/usr/bin/env bash

# ============================================================
# Fedora Wi-Fi Hotspot
# Firewall / NAT
# ============================================================

HOTSPOT_TABLE="fedora_wifi_hotspot"


firewall_setup() {

    local ap="$1"
    local upstream="$2"
    local subnet="$3"

    echo "[*] Configuring firewall/NAT..."

    if systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --zone=trusted --add-interface="$ap" >/dev/null 2>&1 || true
    fi

    # Remove an old copy of our own table.
    nft delete table ip "$HOTSPOT_TABLE" 2>/dev/null || true

    nft add table ip "$HOTSPOT_TABLE"

    nft add chain ip "$HOTSPOT_TABLE" forward \
        '{ type filter hook forward priority filter; policy accept; }'

    nft add chain ip "$HOTSPOT_TABLE" postrouting \
        '{ type nat hook postrouting priority srcnat; policy accept; }'

    nft add rule ip "$HOTSPOT_TABLE" forward \
        iifname "$ap" oifname "$upstream" accept

    nft add rule ip "$HOTSPOT_TABLE" forward \
        iifname "$upstream" oifname "$ap" \
        ct state related,established accept

    nft add rule ip "$HOTSPOT_TABLE" postrouting \
        oifname "$upstream" ip saddr "$subnet" masquerade

    echo "[✓] Firewall forwarding configured."
    echo "[✓] NAT configured."
}


firewall_cleanup() {

    echo "[*] Removing hotspot firewall rules..."
    
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --zone=trusted --remove-interface="ap0" >/dev/null 2>&1 || true
    fi

    nft delete table ip "$HOTSPOT_TABLE" 2>/dev/null || true

    echo "[✓] Hotspot firewall rules removed."
}


firewall_status() {

    if nft list table ip "$HOTSPOT_TABLE" >/dev/null 2>&1; then
        echo "[✓] Hotspot firewall/NAT: active"
        return 0
    fi

    echo "[✗] Hotspot firewall/NAT: inactive"
    return 1
}
