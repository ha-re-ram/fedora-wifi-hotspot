#!/usr/bin/env bash

HOTSPOT_RUNTIME_DIR="${HOTSPOT_RUNTIME_DIR:-/run/fedora-wifi-hotspot}"
HOTSPOT_ROUTE_STATE="$HOTSPOT_RUNTIME_DIR/routing.env"

HOTSPOT_ROUTE_PRIORITY=""


detect_default_route_interface() {
    ip -4 route show default 2>/dev/null |
        awk '{
            for (i = 1; i <= NF; i++)
                if ($i == "dev") {
                    print $(i + 1)
                    exit
                }
        }'
}


detect_default_gateway() {
    ip -4 route show default 2>/dev/null |
        awk '{
            for (i = 1; i <= NF; i++)
                if ($i == "via") {
                    print $(i + 1)
                    exit
                }
        }'
}


detect_source_ip() {
    local interface="$1"

    ip -4 route get 8.8.8.8 oif "$interface" 2>/dev/null |
        awk '{
            for (i = 1; i <= NF; i++)
                if ($i == "src") {
                    print $(i + 1)
                    exit
                }
        }'
}


is_wifi_interface() {
    local interface="$1"

    [ -d "/sys/class/net/$interface/wireless" ]
}


detect_wifi_upstream() {
    local interface

    interface="$(detect_default_route_interface)"

    if [ -n "$interface" ] && is_wifi_interface "$interface"; then
        echo "$interface"
        return 0
    fi

    return 1
}


verify_upstream_connection() {
    local interface="$1"

    iw dev "$interface" link 2>/dev/null |
        grep -q "Connected"
}


get_upstream_frequency() {
    local interface="$1"

    iw dev "$interface" info 2>/dev/null |
        awk '/channel/ {
            gsub(/[()]/, "", $3)
            print $3
            exit
        }'
}


get_upstream_channel() {
    local interface="$1"

    iw dev "$interface" info 2>/dev/null |
        awk '/channel/ {
            print $2
            exit
        }'
}


get_upstream_ssid() {
    local interface="$1"

    iw dev "$interface" link 2>/dev/null |
        awk -F': ' '/SSID:/ {
            print $2
            exit
        }'
}


print_network_diagnostics() {
    local default_interface
    local gateway
    local source_ip
    local wifi_interface
    local frequency
    local channel
    local ssid

    echo
    echo "=========================================="
    echo "       Upstream Network Detection"
    echo "=========================================="
    echo

    default_interface="$(detect_default_route_interface)"
    gateway="$(detect_default_gateway)"

    echo "Default interface : ${default_interface:-none}"
    echo "Default gateway   : ${gateway:-none}"

    if [ -n "$default_interface" ]; then
        source_ip="$(detect_source_ip "$default_interface")"
        echo "Source IPv4       : ${source_ip:-unknown}"
    fi

    wifi_interface="$(detect_wifi_upstream || true)"

    if [ -z "$wifi_interface" ]; then
        echo
        echo "[✗] Current Internet route is not using Wi-Fi."
        return 1
    fi

    ssid="$(get_upstream_ssid "$wifi_interface")"
    frequency="$(get_upstream_frequency "$wifi_interface")"
    channel="$(get_upstream_channel "$wifi_interface")"

    echo
    echo "[✓] Wi-Fi upstream: $wifi_interface"
    echo "[✓] SSID:           ${ssid:-unknown}"
    echo "[✓] Frequency:      ${frequency:-unknown} MHz"
    echo "[✓] Channel:        ${channel:-unknown}"
    echo
}


find_free_rule_priority() {
    local priority

    for priority in $(seq 10000 10999); do
        if ! ip rule show 2>/dev/null | grep -q "^${priority}:"; then
            echo "$priority"
            return 0
        fi
    done

    return 1
}


save_routing_state() {
    local priority="$1"

    mkdir -p "$HOTSPOT_RUNTIME_DIR"

    cat > "$HOTSPOT_ROUTE_STATE" <<EOF2
HOTSPOT_ROUTE_PRIORITY="$priority"
EOF2
}


load_routing_state() {
    if [ -f "$HOTSPOT_ROUTE_STATE" ]; then
        source "$HOTSPOT_ROUTE_STATE"
        return 0
    fi

    return 1
}


setup_hotspot_routing() {
    local ap="$1"
    local upstream="$2"
    local gateway="$3"
    local subnet="$4"

    local priority

    echo "[*] Configuring hotspot routing..."

    priority="$(find_free_rule_priority)"

    if [ -z "$priority" ]; then
        echo "[✗] No free routing-rule priority available."
        return 1
    fi

    ip rule add \
        from "$subnet" \
        priority "$priority" \
        lookup main || {
            echo "[✗] Failed to create hotspot policy rule."
            return 1
        }

    HOTSPOT_ROUTE_PRIORITY="$priority"

    save_routing_state "$priority"

    echo "[✓] Rule priority: $priority"
    echo "[✓] Hotspot traffic will use the main routing table."
    echo "[✓] Upstream interface: $upstream"
    echo "[✓] Upstream gateway: $gateway"

    return 0
}


verify_hotspot_route() {
    local ap="$1"
    local upstream="$2"
    local test_ip="$3"

    local result

    result="$(
        ip -4 route get 8.8.8.8 \
            from "$test_ip" \
            iif "$ap" \
            2>/dev/null || true
    )"

    if [ -z "$result" ]; then
        echo "[✗] No route exists for hotspot traffic."
        return 1
    fi

    if ! echo "$result" | grep -q "dev $upstream"; then
        echo "[✗] Hotspot traffic is not routed through $upstream."
        echo
        echo "Route:"
        echo "    $result"
        return 1
    fi

    echo "[✓] Hotspot traffic routes through $upstream."
    echo
    echo "    $result"

    return 0
}


cleanup_hotspot_routing() {
    local subnet="$1"
    local priority=""

    load_routing_state || true

    priority="${HOTSPOT_ROUTE_PRIORITY:-}"

    if [ -n "$priority" ]; then
        ip rule del \
            from "$subnet" \
            priority "$priority" \
            2>/dev/null || true
    fi

    rm -f "$HOTSPOT_ROUTE_STATE"

    HOTSPOT_ROUTE_PRIORITY=""

    echo "[✓] Hotspot routing removed."
}
