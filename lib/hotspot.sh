#!/usr/bin/env bash

# ============================================================
# Fedora Wi-Fi Hotspot
# AP lifecycle
# ============================================================

HOTSPOT_CONFIG_DIR="${HOTSPOT_CONFIG_DIR:-/run/fedora-wifi-hotspot}"

HOSTAPD_CONF="$HOTSPOT_CONFIG_DIR/hostapd.conf"
DNSMASQ_CONF="$HOTSPOT_CONFIG_DIR/dnsmasq.conf"

HOSTAPD_PID="$HOTSPOT_CONFIG_DIR/hostapd.pid"
DNSMASQ_PID="$HOTSPOT_CONFIG_DIR/dnsmasq.pid"


# ============================================================
# AP INTERFACE
# ============================================================

create_ap_interface() {

    local phy="$1"
    local ap="$2"

    if iw dev "$ap" info >/dev/null 2>&1; then
        echo "[✓] AP interface already exists: $ap"
    else
        echo "[*] Creating AP interface: $ap"

        if ! iw phy "$phy" interface add "$ap" type __ap; then
            echo "[✗] Failed to create AP interface."
            return 1
        fi

        echo "[✓] AP interface created."
    fi

    # Prevent NetworkManager from managing the AP interface.
    nmcli device set "$ap" managed no 2>/dev/null || true

    # Interface must be down before changing its wireless type.
    ip link set "$ap" down 2>/dev/null || true

    # Assign a random locally administered MAC address to avoid conflicts
    # ("RTNETLINK answers: Name not unique on network") with the upstream interface.
    local mac
    mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    ip link set dev "$ap" address "$mac" 2>/dev/null || true

    # Explicitly force AP mode.
    if ! iw dev "$ap" set type __ap; then
        echo "[✗] Failed to set $ap to AP mode."
        return 1
    fi

    # Verify AP mode.
    if ! iw dev "$ap" info | grep -q "type AP"; then
        echo "[✗] $ap is not in AP mode."
        return 1
    fi

    echo "[✓] AP interface is in AP mode."

    return 0
}


remove_ap_interface() {

    local ap="$1"

    if iw dev "$ap" info >/dev/null 2>&1; then
        echo "[*] Removing AP interface: $ap"
        iw dev "$ap" del
    fi
}


configure_ap_interface() {

    local ap="$1"
    local address="$2"

    # Remove any previous addresses.
    ip addr flush dev "$ap"

    # Assign hotspot gateway address.
    if ! ip addr add "$address" dev "$ap"; then
        echo "[✗] Failed to assign $address to $ap."
        return 1
    fi

    # Bring interface up.
    if ! ip link set "$ap" up; then
        echo "[✗] Failed to bring $ap up."
        return 1
    fi

    echo "[✓] AP interface configured: $address"

    return 0
}


# ============================================================
# HOSTAPD CONFIGURATION
# ============================================================

generate_hostapd_config() {

    local ap="$1"
    local ssid="$2"
    local password="$3"
    local hw_mode="$4"
    local channel="$5"

    local country
    country="$(iw reg get 2>/dev/null | grep ^country | awk '{print $2}' | sed 's/://' | head -n1)"
    [ -z "$country" ] || [ "$country" = "00" ] && country="US"

    mkdir -p "$HOTSPOT_CONFIG_DIR"

    cat > "$HOSTAPD_CONF" <<EOF2
interface=$ap
driver=nl80211

ssid=$ssid
hw_mode=$hw_mode
channel=$channel

ieee80211d=1
ieee80211h=1
country_code=$country

auth_algs=1

wpa=2
wpa_passphrase=$password
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF2

    echo "[✓] hostapd configuration created."

    return 0
}


# ============================================================
# DNSMASQ CONFIGURATION
# ============================================================

generate_dnsmasq_config() {

    local ap="$1"
    local gateway="$2"
    local start_ip="$3"
    local end_ip="$4"
    local subnet_mask="$5"

    mkdir -p "$HOTSPOT_CONFIG_DIR"

    cat > "$DNSMASQ_CONF" <<EOF2
interface=$ap
bind-dynamic
port=0

dhcp-range=$start_ip,$end_ip,$subnet_mask,12h

dhcp-option=3,$gateway
dhcp-option=6,1.1.1.1,8.8.8.8
EOF2

    echo "[✓] dnsmasq configuration created."

    return 0
}


# ============================================================
# HOSTAPD
# ============================================================

start_hostapd() {

    if [ -f "$HOSTAPD_PID" ] &&
       kill -0 "$(cat "$HOSTAPD_PID" 2>/dev/null)" 2>/dev/null
    then
        echo "[✓] hostapd already running."
        return 0
    fi

    rm -f "$HOSTAPD_PID"

    if ! hostapd -B \
        -P "$HOSTAPD_PID" \
        "$HOSTAPD_CONF"
    then
        echo "[✗] hostapd failed to start."
        return 1
    fi

    echo "[✓] hostapd started."

    return 0
}


# ============================================================
# DNSMASQ
# ============================================================

start_dnsmasq() {

    local ap
    local dnsmasq_pid

    ap="$(awk -F= '/^interface=/ {print $2; exit}' "$DNSMASQ_CONF")"

    if [ -z "$ap" ]; then
        echo "[✗] Could not determine dnsmasq interface."
        return 1
    fi

    if [ -f "$DNSMASQ_PID" ] &&
       kill -0 "$(cat "$DNSMASQ_PID" 2>/dev/null)" 2>/dev/null
    then
        echo "[✓] dnsmasq already running."
        return 0
    fi

    rm -f "$DNSMASQ_PID"

    # Verify that the AP interface exists.
    if ! iw dev "$ap" info >/dev/null 2>&1; then
        echo "[✗] AP interface $ap does not exist."
        return 1
    fi

    echo "[*] Starting dnsmasq on $ap..."

    dnsmasq \
        --conf-file="$DNSMASQ_CONF" \
        --no-daemon \
        --pid-file="$DNSMASQ_PID" >/dev/null 2>&1 &

    dnsmasq_pid=$!

    # Give dnsmasq a moment to initialize.
    sleep 0.5

    # Check whether the process is still alive.
    if ! kill -0 "$dnsmasq_pid" 2>/dev/null; then
        echo "[✗] dnsmasq failed to start."
        wait "$dnsmasq_pid" 2>/dev/null || true
        rm -f "$DNSMASQ_PID"
        return 1
    fi

    # Store the actual process PID.
    echo "$dnsmasq_pid" > "$DNSMASQ_PID"

    echo "[✓] dnsmasq started."

    return 0
}


# ============================================================
# PROCESS MANAGEMENT
# ============================================================

stop_process() {

    local pidfile="$1"
    local name="$2"

    if [ ! -f "$pidfile" ]; then
        return 0
    fi

    local pid

    pid="$(cat "$pidfile" 2>/dev/null || true)"

    if [ -n "$pid" ] &&
       kill -0 "$pid" 2>/dev/null
    then

        echo "[*] Stopping $name..."

        kill "$pid" 2>/dev/null || true

        for _ in 1 2 3 4 5; do

            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi

            sleep 1
        done
    fi

    rm -f "$pidfile"
}


stop_hostapd() {

    stop_process "$HOSTAPD_PID" "hostapd"
}


stop_dnsmasq() {

    stop_process "$DNSMASQ_PID" "dnsmasq"
}
