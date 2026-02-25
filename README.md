# mullvad-netns

Run only selected apps/commands through a Mullvad WireGuard tunnel using a Linux network namespace, without changing your host system's default routes.

This repo includes:

- `mullvad-netns` (CLI helper)
- `mullvad-netns-gui` (Ruby/GTK3 GUI)
- `install.sh` (local or curl-piped installer)

## What It Does

`mullvad-netns` creates a dedicated network namespace and runs WireGuard inside that namespace only. Your host stays on its normal network, and only commands you launch with `mullvad-netns exec` go through Mullvad.

Core behavior:

- Creates a network namespace (default `mvpn`)
- Creates a veth pair between host and namespace
- Sets up host NAT via `nftables` for the namespace subnet
- Brings up a Mullvad WireGuard config inside the namespace (`wg-quick`)
- Optionally applies a namespace-only killswitch to prevent leaks if WG goes down
- Optionally preserves LAN access from VPN-routed apps (`ALLOW_LAN=1`, default)
- Provides `repair`, `status`, `down`, and `teardown` commands

The GUI provides a simple control panel for:

- Bringing the tunnel up/down/repair/teardown
- Picking a Mullvad `.conf` file
- Running or launching desktop apps inside the VPN namespace
- Capturing output from commands

## Requirements

## OS

- Linux (tested conceptually on modern distributions with `iproute2`, `nftables`, and `wireguard-tools`)

## CLI runtime requirements

- `bash`
- `ip` (from `iproute2`)
- `nft` (from `nftables`)
- `wg-quick` and `wg` (from `wireguard-tools`)
- `sudo`
- `getent` (normally present on glibc-based systems)

You must run `up`, `exec`, `repair`, `down`, and `teardown` as root (typically via `sudo`).

## GUI requirements (optional)

- `ruby`
- `ruby-gtk3`

Ubuntu/Debian example:

```bash
sudo apt-get update
sudo apt-get install -y ruby ruby-gtk3 iproute2 nftables wireguard-tools sudo
```

## Installation

## Option 1: Install from `mullvad-netns.schoma.kr` via curl

```bash
curl -fsSL https://mullvad-netns.schoma.kr/install.sh | \
  REPO_RAW_BASE="https://mullvad-netns.schoma.kr" bash
```

## Option 2: Install from GitHub with `curl`

```bash

curl -fsSL https://raw.githubusercontent.com/lschomaker1/mullvad-netns/main/install.sh | \
  REPO_RAW_BASE="https://raw.githubusercontent.com/lschomaker1/mullvad-netns" bash
```

This installs:

- `mullvad-netns`
- `mullvad-netns-gui` (unless `--skip-gui` is passed to `install.sh`)

## install.sh options

```bash
./install.sh --help
./install.sh --bin-dir /usr/local/bin
./install.sh --skip-gui
./install.sh --raw-base https://raw.githubusercontent.com/lschomaker1/mullvad-netns/main
```

## Usage (CLI)

## 1. Export a Mullvad WireGuard config

Download/export a Mullvad WireGuard `.conf` file from Mullvad and save it locally.

## 2. Bring up the namespace + tunnel

```bash
sudo mullvad-netns up --config /path/to/mullvad.conf
```

Optional flags:

- `--user USER` sets which user to use for an immediate command launched with `up ... -- CMD...`

Example (bring up and immediately run a command):

```bash
sudo mullvad-netns up --config /path/to/mullvad.conf -- curl -4 ifconfig.me/ip
```

## 3. Run commands inside the VPN namespace

```bash
sudo mullvad-netns exec -- curl -4 ifconfig.me/ip
```

Run as a specific user:

```bash
sudo mullvad-netns exec --user "$USER" -- firefox
```

If GUI apps fail to connect to your desktop session, preserve desktop/session env vars through `sudo`:

```bash
sudo --preserve-env=DISPLAY,XAUTHORITY,WAYLAND_DISPLAY,DBUS_SESSION_BUS_ADDRESS,XDG_RUNTIME_DIR,PULSE_SERVER,SSH_AUTH_SOCK \
  mullvad-netns exec --user "$USER" -- firefox
```

## 4. Check status / repair / shutdown

```bash
mullvad-netns status
sudo mullvad-netns repair
sudo mullvad-netns down
sudo mullvad-netns teardown
```

`down` stops WireGuard but keeps the namespace/veth in place.

`teardown` removes the namespace, veth pair, nftables rules, and generated runtime files.

`repair` reasserts namespace routes, refreshes per-netns DNS, and rebuilds the killswitch (if enabled) without changing host default routes.

## CLI Commands

```text
mullvad-netns up   --config /path/to/mullvad.conf [--user USER] [--] CMD...
mullvad-netns exec [--user USER] -- CMD...
mullvad-netns repair
mullvad-netns down
mullvad-netns teardown
mullvad-netns status
```

## Environment Variables (Advanced)

These are optional overrides if you want to change namespace/interface names or behavior.

- `NS_NAME` (default `mvpn`)
- `WG_IFACE` (default `mvwg0`)
- `VETH_HOST` (default `mvpn0`)
- `VETH_NS` (default `mvpn1`)
- `NS_CIDR` (default `10.200.200.0/24`)
- `HOST_VETH_IP` (default `10.200.200.1/24`)
- `NS_VETH_IP` (default `10.200.200.2/24`)
- `NS_GW_IP` (default `10.200.200.1`)
- `ALLOW_LAN` (default `1`)
- `KILLSWITCH` (default `1`)
- `RUN_DIR` (default `/run/mullvad-netns`)
- `ETC_NETNS_DIR` (default `/etc/netns`)
- `HOST_NFT_TABLE` (default `mvpn_netns`)
- `NS_NFT_TABLE` (default `mvpn_killswitch`)

Examples:

```bash
sudo ALLOW_LAN=0 mullvad-netns up --config /path/to/mullvad.conf
sudo KILLSWITCH=0 mullvad-netns up --config /path/to/mullvad.conf
sudo NS_NAME=myvpn WG_IFACE=wgmullvad mullvad-netns up --config /path/to/mullvad.conf
```

## GUI Usage

Start the GUI:

```bash
mullvad-netns-gui
```

What it does:

- **Tunnel tab**: pick a config directory/file, toggle LAN access and killswitch, then `Up/Down/Repair/Teardown/Status`
- **Run tab**: search installed desktop applications, fill the command field from a `.desktop` entry, and run/launch inside the namespace
- Adds a separate Chrome/Chromium profile path automatically (recommended) to avoid reusing an already-running non-VPN browser process

Important GUI note:

- The GUI currently uses `sudo -n` (non-interactive sudo). That means passwordless sudo must already work for the commands it runs, or the GUI will show an error.

## How It Avoids Host-Wide Side Effects

When importing your Mullvad `.conf`, the script sanitizes it before calling `wg-quick` inside the namespace:

- Strips `DNS=`
- Strips `Table=`
- Strips `PreUp`, `PostUp`, `PreDown`, `PostDown` hooks

Then it writes DNS only for the namespace via `/etc/netns/<NS_NAME>/resolv.conf`, so your host DNS configuration is not modified.

## LAN Access and Leak Protection

Default behavior:

- `ALLOW_LAN=1`: namespace apps can still reach host on-link IPv4 networks (LAN, Docker bridges, etc.)
- `KILLSWITCH=1`: a namespace-local nftables output policy drops non-WireGuard traffic to prevent leaks

To force all namespace traffic through the tunnel (no LAN access from VPN-routed apps):

```bash
sudo ALLOW_LAN=0 mullvad-netns up --config /path/to/mullvad.conf
```

## Troubleshooting

## `mullvad-netns status` works but apps have no internet

Run:

```bash
sudo mullvad-netns repair
```

This restores the namespace route layout and per-netns DNS in common failure cases.

## Chrome/Chromium opens outside the VPN

Chrome-like browsers often reuse an existing process. Use a separate profile:

```bash
sudo mullvad-netns exec --user "$USER" -- google-chrome-stable --user-data-dir="$HOME/.config/google-chrome-mvpn"
```

The GUI has an "Isolate Chrome/Chromium profile" option for this.

