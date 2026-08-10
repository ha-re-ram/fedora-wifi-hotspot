# Fedora Wi-Fi Hotspot

A lightweight command-line Wi-Fi hotspot tool for Fedora Linux.

`fedora-wifi-hotspot` lets a Fedora system share its existing Wi-Fi connection through a software access point using the same wireless adapter, when the adapter and Linux driver support concurrent client + AP operation.

## Features

- Automatic Wi-Fi interface, PHY, driver, channel, frequency, and upstream network detection
- Access Point and concurrent client + AP capability detection
- Virtual AP interface creation with NetworkManager-aware setup
- WPA2 access point through `hostapd`
- DHCP through `dnsmasq`
- IPv4 forwarding, NAT, firewall, and hotspot routing
- Automatic cleanup on stop and failure
- Interactive or command-line SSID/password configuration
- Hardware diagnostics and hotspot status reporting
- System-wide installation and uninstallation
- Automatic privilege elevation

## Requirements

### Operating system

- Fedora Linux

### Required packages

The installer checks and installs:

- NetworkManager
- iproute
- iptables-nft
- iw
- hostapd
- dnsmasq

### Wireless hardware

The wireless adapter and Linux driver must support:

- Managed/client mode
- Access Point mode
- Concurrent client + AP operation

Not every Wi-Fi adapter supports this configuration.

---

# Installation

Clone the repository:

```bash
git clone https://github.com/shubhamcoder260/fedora-wifi-hotspot.git
cd fedora-wifi-hotspot
sudo ./install.sh
```

The installer verifies Fedora, installs missing dependencies, installs the application system-wide, and verifies the installation.

After installation, `wifi-hotspot` is available from any directory.

---

# Quick Start

## 1. Diagnose your hardware

```bash
wifi-hotspot diagnose
```

A compatible system should report:

```text
[✓] Managed/client mode
[✓] Access Point mode
[✓] Concurrent client + AP
```

## 2. Start the hotspot

Interactive mode:

```bash
wifi-hotspot start
```

You will be asked for:

```text
Hotspot name:
Hotspot password:
```

The password must contain 8 to 63 characters.

Or specify them directly:

```bash
wifi-hotspot start --ssid "My Hotspot" --password "MyPassword123"
```

## 3. Connect your devices

Connect your phone, laptop, tablet, or other Wi-Fi device to the selected SSID.

The hotspot automatically provides DHCP addressing and routes client traffic through the host's existing Wi-Fi connection.

## 4. Check status

```bash
wifi-hotspot status
```

Example:

```text
[✓] AP interface: ap0
[✓] hostapd: running
[✓] dnsmasq: running
[✓] IPv4 forwarding: enabled
[✓] Hotspot firewall/NAT: active
[✓] Policy routing: configured
[✓] Connected clients: 1
```

## 5. Stop the hotspot

```bash
wifi-hotspot stop
```

This removes the AP interface, routing configuration, firewall/NAT rules, and hotspot services.

---

# Commands

| Command | Description |
|---|---|
| `wifi-hotspot start` | Start the hotspot |
| `wifi-hotspot stop` | Stop the hotspot |
| `wifi-hotspot status` | Show hotspot status |
| `wifi-hotspot diagnose` | Detect Wi-Fi hardware and network capabilities |
| `wifi-hotspot help` | Show command help |

## Start options

```text
--ssid NAME
    Set the hotspot name.

--password PASSWORD
    Set the WPA2 password.
    Minimum: 8 characters.
    Maximum: 63 characters.
```

Example:

```bash
wifi-hotspot start --ssid "Fedora-Test" --password "FedoraTest123"
```

---

# How It Works

The project keeps the existing Wi-Fi connection active while creating a software access point on the same wireless PHY when supported.

```text
                         Internet
                            │
                    Existing Wi-Fi
                            │
                         wlp1s0
                            │
                            ▼
                ┌─────────────────────┐
                │    Fedora Host      │
                │                     │
                │  Routing            │
                │  IPv4 forwarding    │
                │  NAT / firewall     │
                └──────────┬──────────┘
                           │
                          ap0
                           │
                       hostapd
                           │
                    Wi-Fi Access Point
                           │
                    ┌──────┴──────┐
                    │             │
                  Phone         Laptop
```

## Wireless detection

The application detects:

- Wi-Fi interface
- PHY
- Wireless driver
- Current SSID
- Current frequency
- Current channel
- AP support
- Concurrent client + AP support
- Channel concurrency capabilities
- Upstream gateway
- Source IPv4 address

## AP interface

A virtual interface named `ap0` is created from the wireless PHY, placed into AP mode, and assigned:

```text
10.42.0.1/24
```

This becomes the hotspot gateway.

## hostapd

`hostapd` manages the wireless access point, including SSID broadcasting, WPA2 authentication, AP operation, and channel configuration.

## dnsmasq

`dnsmasq` provides DHCP service.

Default DHCP range:

```text
10.42.0.10 - 10.42.0.100
```

Hotspot gateway:

```text
10.42.0.1
```

DNS servers advertised to clients:

```text
1.1.1.1
8.8.8.8
```

## Forwarding, NAT, and routing

IPv4 forwarding allows client traffic to pass through the Fedora host. NAT allows clients to use the host's upstream Wi-Fi connection, while routing directs hotspot traffic through the active upstream interface.

---

# Hardware Compatibility

This project depends on the wireless adapter and Linux driver.

A compatible diagnostic result should contain:

```text
[✓] Managed/client mode
[✓] Access Point mode
[✓] Concurrent client + AP
```

However, advertised capabilities do not guarantee that every channel, channel width, or driver configuration will work.

## Unsupported concurrent mode

For example:

```text
[✓] Managed/client mode
[✓] Access Point mode
[✗] Concurrent client + AP
```

means the adapter/driver does not advertise the required simultaneous configuration.

Possible alternatives:

- Use a second Wi-Fi adapter
- Use hardware with concurrent client + AP support
- Use another compatible driver, if available
- Use a dedicated access point

---

# Channel Compatibility

Wireless drivers can impose restrictions on simultaneous station and AP operation.

A driver may report:

```text
#channels <= 1
```

or:

```text
#channels <= 2
```

It may also report restrictions such as:

```text
STA/AP BI must match
```

or restrictions on channel widths.

The current implementation uses the upstream Wi-Fi channel for the AP to improve compatibility with adapters that require station and AP operation to share a channel.

Exact behavior depends on the wireless chipset and Linux driver.

---

# Privileges

The installed command automatically requests root privileges when required.

Normal usage can therefore be:

```bash
wifi-hotspot start
```

instead of:

```bash
sudo wifi-hotspot start
```

The same applies to:

```bash
wifi-hotspot stop
wifi-hotspot status
wifi-hotspot diagnose
```

---

# Troubleshooting

## Diagnose first

```bash
wifi-hotspot diagnose
```

Check for:

```text
[✓] Access Point mode
[✓] Concurrent client + AP
```

If concurrent AP support is unavailable, the same physical adapter may not be able to remain connected to upstream Wi-Fi while providing the hotspot.

## Check status

```bash
wifi-hotspot status
```

This reports:

- AP interface state
- hostapd state
- dnsmasq state
- IPv4 forwarding
- NAT/firewall state
- routing state
- connected clients

## Clean up a failed start

```bash
wifi-hotspot stop
```

Then:

```bash
iw dev
```

Normally `ap0` should not exist after a clean stop.

You can also check:

```bash
ip link show ap0
```

## Inspect wireless interfaces

```bash
iw dev
```

During operation you may see:

```text
Interface ap0
    type AP

Interface wlp1s0
    type managed
```

After stopping the hotspot, `ap0` should normally disappear.

---

# Security

The hotspot uses WPA2-PSK through `hostapd`.

Passwords must contain:

- At least 8 characters
- At most 63 characters

Do not publish real hotspot passwords, Wi-Fi credentials, API keys, SSH private keys, or other sensitive information in issues, logs, screenshots, or pull requests.

---

# Installation Details

The installer places the application under:

```text
/usr/local/lib/fedora-wifi-hotspot/
```

The system-wide command is installed at:

```text
/usr/local/sbin/wifi-hotspot
```

Supporting scripts are installed under:

```text
/usr/local/lib/fedora-wifi-hotspot/lib/
```

Temporary runtime files are stored under:

```text
/run/fedora-wifi-hotspot/
```

---

# Uninstallation

From the cloned repository:

```bash
sudo ./uninstall.sh
```

The uninstaller:

1. Stops an active hotspot.
2. Removes the installed application.
3. Removes the system-wide `wifi-hotspot` command.
4. Removes runtime hotspot state.

The cloned Git repository itself is not removed.

---

# Project Structure

```text
fedora-wifi-hotspot/
│
├── wifi-hotspot
├── install.sh
├── uninstall.sh
│
├── lib/
│   ├── detect.sh
│   ├── network.sh
│   ├── firewall.sh
│   └── hotspot.sh
│
├── README.md
├── LICENSE
└── .gitignore
```

### `wifi-hotspot`

Main command-line interface for argument parsing, interactive input, validation, command dispatch, privilege elevation, and hotspot lifecycle.

### `lib/detect.sh`

Hardware and Wi-Fi capability detection.

### `lib/network.sh`

Upstream network detection, gateway/source address detection, hotspot routing, policy routing, and route cleanup.

### `lib/firewall.sh`

IPv4 forwarding, firewall rules, NAT, and firewall cleanup.

### `lib/hotspot.sh`

AP interface creation/configuration, hostapd and dnsmasq configuration, service lifecycle, and AP cleanup.

### `install.sh`

Fedora detection, dependency installation, system-wide installation, and verification.

### `uninstall.sh`

System-wide application removal.

---

# Development

Clone the repository:

```bash
git clone https://github.com/shubhamcoder260/fedora-wifi-hotspot.git
cd fedora-wifi-hotspot
```

Run diagnostics directly from the source tree:

```bash
sudo ./wifi-hotspot diagnose
```

Test a hotspot:

```bash
sudo ./wifi-hotspot start --ssid "Fedora-Test" --password "FedoraTest123"
```

Stop it:

```bash
sudo ./wifi-hotspot stop
```

## Shell syntax checks

```bash
bash -n wifi-hotspot
bash -n lib/detect.sh
bash -n lib/network.sh
bash -n lib/firewall.sh
bash -n lib/hotspot.sh
bash -n install.sh
bash -n uninstall.sh
```

Each command should return exit code `0`.

---

# Project Status

**Current release: v0.1.0**

The current release has been tested for:

- Automatic upstream Wi-Fi detection
- Concurrent client + AP operation
- Virtual AP interface creation
- NetworkManager interaction
- hostapd
- dnsmasq
- DHCP
- IPv4 forwarding
- NAT
- Hotspot client connectivity
- Status reporting
- Clean shutdown
- Automatic cleanup
- System-wide installation
- System-wide uninstallation
- Interactive configuration
- Command-line configuration
- Hardware diagnostics

Testing across additional Fedora systems, wireless chipsets, and driver combinations is ongoing.

This is an early release and does not guarantee compatibility with every Fedora wireless adapter.

---

# Roadmap

Potential future improvements:

- Broader wireless chipset testing
- Driver-specific compatibility handling
- Improved error recovery
- More robust firewall backend handling
- IPv6 support
- Configurable DHCP ranges
- Configuration file support
- Additional Fedora version testing
- Fedora RPM packaging
- COPR distribution
- Automated integration testing
- Expanded hardware compatibility reporting
- More detailed diagnostics

---

# Contributing

Contributions, bug reports, hardware compatibility reports, and improvements are welcome.

When reporting a hardware compatibility issue, include:

```bash
wifi-hotspot diagnose
```

and, if the hotspot was started:

```bash
wifi-hotspot status
```

Useful additional information:

```bash
iw dev
ip -4 route
```

Do not include passwords, private credentials, API keys, SSH private keys, or other sensitive information.

---

# License

This project is licensed under the terms provided in [LICENSE](LICENSE).

---

# Repository

https://github.com/shubhamcoder260/fedora-wifi-hotspot
