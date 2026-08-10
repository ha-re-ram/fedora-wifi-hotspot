#!/usr/bin/env bash

# ============================================================
# Fedora Wi-Fi Hotspot
# Hardware / Network Detection
# ============================================================

detect_wifi_interface() {

    nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null |
        awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }'
}


detect_phy() {

    local interface="$1"

    iw dev "$interface" info 2>/dev/null |
        awk '/wiphy/ { print "phy" $2; exit }'
}


detect_driver() {

    local interface="$1"

    udevadm info \
        --query=property \
        --path="/sys/class/net/$interface" 2>/dev/null |
        awk -F= '$1 == "ID_NET_DRIVER" { print $2; exit }'
}


detect_ssid() {

    local interface="$1"

    iw dev "$interface" link 2>/dev/null |
        awk -F': ' '/SSID:/ { print $2; exit }'
}


detect_frequency() {

    local interface="$1"

    iw dev "$interface" info 2>/dev/null |
        awk '/channel/ {
            gsub(/[()]/, "", $3)
            print $3
            exit
        }'
}


detect_channel() {

    local interface="$1"

    iw dev "$interface" info 2>/dev/null |
        awk '/channel/ {
            print $2
            exit
        }'
}


supports_ap() {

    local phy="$1"

    iw phy "$phy" info 2>/dev/null |
        awk '
            /Supported interface modes:/ {
                in_modes=1
                next
            }

            in_modes && /^\s*\* AP$/ {
                found=1
            }

            in_modes && /^Band/ {
                exit
            }

            END {
                if (found)
                    exit 0
                else
                    exit 1
            }
        '
}


supports_managed() {

    local phy="$1"

    iw phy "$phy" info 2>/dev/null |
        awk '
            /Supported interface modes:/ {
                in_modes=1
                next
            }

            in_modes && /^\s*\* managed$/ {
                found=1
            }

            in_modes && /^Band/ {
                exit
            }

            END {
                if (found)
                    exit 0
                else
                    exit 1
            }
        '
}


supports_concurrent_sta_ap() {

    local phy="$1"

    iw phy "$phy" info 2>/dev/null |
        awk '
            /valid interface combinations:/ {
                in_combinations=1
                next
            }

            /HT Capability overrides:/ {
                exit
            }

            in_combinations &&
            index($0, "#{ managed }") &&
            index($0, "#{ AP") {
                found=1
            }

            END {
                if (found)
                    exit 0
                else
                    exit 1
            }
        '
}


get_concurrency_info() {

    local phy="$1"

    iw phy "$phy" info 2>/dev/null |
        awk '
            /valid interface combinations:/ {
                in_combinations=1
                next
            }

            /HT Capability overrides:/ {
                exit
            }

            in_combinations {
                print
            }
        '
}


get_max_concurrent_channels() {

    local phy="$1"

    iw phy "$phy" info 2>/dev/null |
        awk '
            /valid interface combinations:/ {
                in_combinations=1
                next
            }

            /HT Capability overrides:/ {
                exit
            }

            in_combinations && /#channels <=/ {
                if (match($0, /#channels <= [0-9]+/)) {
                    value = substr($0, RSTART, RLENGTH)
                    gsub(/[^0-9]/, "", value)

                    if (value > max)
                        max = value
                }
            }

            END {
                if (max > 0)
                    print max
                else
                    print 0
            }
        '
}


print_diagnostics() {

    echo
    echo "=========================================="
    echo "       Fedora Wi-Fi Hotspot"
    echo "          Hardware Detection"
    echo "=========================================="
    echo

    local interface
    local phy
    local driver
    local ssid
    local frequency
    local channel

    interface="$(detect_wifi_interface)"

    if [ -z "$interface" ]; then
        echo "[✗] No connected Wi-Fi interface found."
        return 1
    fi

    phy="$(detect_phy "$interface")"
    driver="$(detect_driver "$interface")"
    ssid="$(detect_ssid "$interface")"
    frequency="$(detect_frequency "$interface")"
    channel="$(detect_channel "$interface")"


    echo "Wi-Fi interface : ${interface:-unknown}"
    echo "PHY             : ${phy:-unknown}"
    echo "Driver          : ${driver:-unknown}"
    echo "SSID            : ${ssid:-unknown}"
    echo "Frequency       : ${frequency:-unknown} MHz"
    echo "Channel         : ${channel:-unknown}"
    echo


    echo "Capabilities:"
    echo


    if supports_managed "$phy"; then
        echo "[✓] Managed/client mode"
    else
        echo "[✗] Managed/client mode"
    fi


    if supports_ap "$phy"; then
        echo "[✓] Access Point mode"
    else
        echo "[✗] Access Point mode"
    fi


    if supports_concurrent_sta_ap "$phy"; then

    echo "[✓] Concurrent client + AP"

    local max_channels
    max_channels="$(get_max_concurrent_channels "$phy")"

    if [ -n "$max_channels" ] && [ "$max_channels" -gt 0 ]; then
        echo "[✓] Maximum concurrent channels: $max_channels"
    else
        echo "[?] Maximum concurrent channels: unknown"
    fi

    echo
    echo "Supported concurrency combinations:"
    get_concurrency_info "$phy" |
        sed 's/^[[:space:]]*//' |
        sed 's/^/    /'

else

    echo "[✗] Concurrent client + AP"
    echo
    echo "The Wi-Fi hardware/driver does not advertise"
    echo "a simultaneous client + AP configuration."

fi


echo
}
