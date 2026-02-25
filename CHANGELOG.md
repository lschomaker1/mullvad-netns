# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [0.1.0] - 2026-02-25

### Added

- `mullvad-netns` CLI for namespace-based Mullvad WireGuard split tunneling
- `mullvad-netns-gui` Ruby/GTK3 GUI for tunnel control and app launching
- `install.sh` installer script for local installs and curl-based installs
- Public-facing `README.md` with functionality, requirements, installation, and usage docs
- `index.html` static landing page for `mullvad-netns.schoma.kr`
- Cloudflare Tunnel-hosted distribution endpoint support (`mullvad-netns.schoma.kr`)

### Changed

- Removed personalized GUI default config paths and replaced them with generic Mullvad/WireGuard path discovery
