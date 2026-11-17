#!/usr/bin/env bash
# Install WezTerm, JetBrains Mono Nerd Font and the Catppuccin Mocha OLED config on macOS.
# Runs standalone (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-mac.sh | bash
# Rerun to update the config. A different existing config is backed up first.
set -euo pipefail

WEZTERM_LUA_URL="${WEZTERM_LUA_URL:-https://raw.githubusercontent.com/okdunn/.dotfiles/main/wezterm/.config/wezterm/wezterm.lua}"
WEZTERM_APP="${WEZTERM_APP:-/Applications/WezTerm.app}"
CONFIG="$HOME/.config/wezterm/wezterm.lua"

log() { printf '\033[0;32m==>\033[0m %s\n' "$1"; }
die() { printf '\033[0;31m==> ERROR:\033[0m %s\n' "$1" >&2; exit 1; }

command -v brew >/dev/null ||
  die "Homebrew not found. Install it from https://brew.sh, then rerun this script."

# A WezTerm installed from the website isn't known to brew, so check the app too
if brew list --cask wezterm >/dev/null 2>&1 || [[ -d "$WEZTERM_APP" ]]; then
  log "WezTerm already installed"
else
  log "Installing WezTerm..."
  brew install --cask wezterm
fi

if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
  log "JetBrains Mono Nerd Font already installed"
else
  log "Installing JetBrains Mono Nerd Font..."
  brew install --cask font-jetbrains-mono-nerd-font
fi

# Download first, so a failed fetch never touches the existing config
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$WEZTERM_LUA_URL" -o "$tmp" || die "Could not download $WEZTERM_LUA_URL"

mkdir -p "${CONFIG%/*}"
if [[ -f "$CONFIG" ]] && cmp -s "$tmp" "$CONFIG"; then
  log "WezTerm config already up to date"
  exit 0
fi
if [[ -e "$CONFIG" ]]; then
  backup="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$CONFIG" "$backup"
  log "Backed up your existing config to $backup"
fi
mv "$tmp" "$CONFIG"
log "WezTerm config installed at $CONFIG. Restart WezTerm to apply it."
