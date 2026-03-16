#!/usr/bin/env bash
set -euo pipefail

# sonde installer
# Usage: curl -sSf https://raw.githubusercontent.com/sonde-dev/sonde/main/install.sh | bash

REPO="sonde-dev/sonde"
BINARY="sonde"
INSTALL_DIR="${SONDE_INSTALL_DIR:-$HOME/.local/bin}"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
error() { printf "\033[1;31merror:\033[0m %s\n" "$1" >&2; exit 1; }

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin) os="apple-darwin" ;;
    Linux)  os="unknown-linux-gnu" ;;
    *)      error "Unsupported OS: $os" ;;
  esac

  case "$arch" in
    x86_64|amd64)  arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *)             error "Unsupported architecture: $arch" ;;
  esac

  echo "${arch}-${os}"
}

main() {
  info "Detecting platform..."
  local platform
  platform="$(detect_platform)"
  info "Platform: $platform"

  # Check if cargo is available for source install
  if command -v cargo &>/dev/null; then
    info "Cargo found — installing from source for best compatibility"
    cargo install --git "https://github.com/${REPO}" --locked
    info "Installed sonde via cargo install"
    return
  fi

  # Binary install
  local latest_tag
  latest_tag="$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
  [ -z "$latest_tag" ] && error "Could not determine latest release"

  local url="https://github.com/${REPO}/releases/download/${latest_tag}/sonde-${platform}.tar.gz"
  info "Downloading sonde ${latest_tag} for ${platform}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -sSfL "$url" -o "$tmpdir/sonde.tar.gz" || error "Download failed. Release may not exist for $platform yet."
  tar -xzf "$tmpdir/sonde.tar.gz" -C "$tmpdir"

  mkdir -p "$INSTALL_DIR"
  mv "$tmpdir/$BINARY" "$INSTALL_DIR/$BINARY"
  chmod +x "$INSTALL_DIR/$BINARY"

  info "Installed to $INSTALL_DIR/$BINARY"

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    info "Add $INSTALL_DIR to your PATH:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
  fi

  info "Configure Claude Code statusline:"
  echo "  Add to ~/.claude/settings.json:"
  echo '  { "statusLine": { "command": "sonde" } }'
}

main "$@"
