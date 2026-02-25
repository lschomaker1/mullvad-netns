#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
REPO_RAW_BASE="${REPO_RAW_BASE:-}"
INSTALL_GUI=1

usage() {
  cat <<'EOF'
Install mullvad-netns and mullvad-netns-gui.

Usage:
  ./install.sh [--bin-dir DIR] [--raw-base URL] [--skip-gui]

Modes:
  - Local mode: if run from a cloned repo directory containing the scripts.
  - Download mode: if piped from curl; requires REPO_RAW_BASE or --raw-base.

Examples:
  ./install.sh
  BIN_DIR="$HOME/.local/bin" ./install.sh
  curl -fsSL https://mullvad-netns.schoma.kr/install.sh | \
    REPO_RAW_BASE="https://mullvad-netns.schoma.kr" bash
  curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | \
    REPO_RAW_BASE="https://raw.githubusercontent.com/<USER>/<REPO>/main" bash
EOF
}

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      BIN_DIR="${2:-}"
      shift 2
      ;;
    --raw-base)
      REPO_RAW_BASE="${2:-}"
      shift 2
      ;;
    --skip-gui)
      INSTALL_GUI=0
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$BIN_DIR" ]] || die "--bin-dir cannot be empty"
need_cmd install
need_cmd mktemp

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

copy_local_if_present() {
  local src_dir="$1"
  [[ -n "$src_dir" ]] || return 1
  [[ -f "$src_dir/mullvad-netns" ]] || return 1
  cp "$src_dir/mullvad-netns" "$tmpdir/mullvad-netns"
  if [[ "$INSTALL_GUI" -eq 1 ]]; then
    [[ -f "$src_dir/mullvad-netns-gui" ]] || die "mullvad-netns-gui not found in $src_dir"
    cp "$src_dir/mullvad-netns-gui" "$tmpdir/mullvad-netns-gui"
  fi
  return 0
}

download_mode() {
  [[ -n "$REPO_RAW_BASE" ]] || die "download mode requires REPO_RAW_BASE or --raw-base"
  need_cmd curl
  curl -fsSL "${REPO_RAW_BASE%/}/mullvad-netns" -o "$tmpdir/mullvad-netns"
  if [[ "$INSTALL_GUI" -eq 1 ]]; then
    curl -fsSL "${REPO_RAW_BASE%/}/mullvad-netns-gui" -o "$tmpdir/mullvad-netns-gui"
  fi
}

if ! copy_local_if_present "$PWD"; then
  if ! copy_local_if_present "$SCRIPT_DIR"; then
    download_mode
  fi
fi

chmod 0755 "$tmpdir/mullvad-netns"
if [[ "$INSTALL_GUI" -eq 1 ]]; then
  chmod 0755 "$tmpdir/mullvad-netns-gui"
fi

sudo_cmd=()
if [[ "$EUID" -ne 0 && ! -w "$BIN_DIR" ]]; then
  need_cmd sudo
  sudo_cmd=(sudo)
fi

"${sudo_cmd[@]}" mkdir -p "$BIN_DIR"
"${sudo_cmd[@]}" install -m 0755 "$tmpdir/mullvad-netns" "$BIN_DIR/mullvad-netns"
if [[ "$INSTALL_GUI" -eq 1 ]]; then
  "${sudo_cmd[@]}" install -m 0755 "$tmpdir/mullvad-netns-gui" "$BIN_DIR/mullvad-netns-gui"
fi

log "Installed:"
log "  $BIN_DIR/mullvad-netns"
if [[ "$INSTALL_GUI" -eq 1 ]]; then
  log "  $BIN_DIR/mullvad-netns-gui"
fi

cat <<EOF

Next steps:
  1. Ensure dependencies are installed (ip, nft, wg-quick, sudo; plus ruby + ruby-gtk3 for GUI).
  2. Run: mullvad-netns status
  3. Bring up a tunnel:
     sudo mullvad-netns up --config /path/to/mullvad.conf

EOF
