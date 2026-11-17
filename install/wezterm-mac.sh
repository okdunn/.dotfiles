#!/usr/bin/env bash
# Install JetBrains Mono Nerd Font and the Catppuccin Mocha OLED WezTerm config on macOS.
# WezTerm itself must be installed separately (https://wezterm.org).
# Runs standalone (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-mac.sh | bash
# Rerun to update the config. A different existing config is backed up first.
set -euo pipefail

# Everything runs from main, called on the last line: under `curl | bash` a download cut
# off part-way then runs nothing instead of half the steps
main() {
  WEZTERM_LUA_URL="${WEZTERM_LUA_URL:-https://raw.githubusercontent.com/okdunn/.dotfiles/main/wezterm/.config/wezterm/wezterm.lua}"
  WEZTERM_APP="${WEZTERM_APP:-/Applications/WezTerm.app}"
  # The file WezTerm will actually load: $WEZTERM_CONFIG_FILE, then an existing
  # $XDG_CONFIG_HOME/wezterm/wezterm.lua, then ~/.config/wezterm/wezterm.lua (which also
  # takes precedence over a ~/.wezterm.lua)
  if [[ -n "${WEZTERM_CONFIG_FILE:-}" ]]; then
    CONFIG="$WEZTERM_CONFIG_FILE"
  elif [[ -n "${XDG_CONFIG_HOME:-}" && -f "$XDG_CONFIG_HOME/wezterm/wezterm.lua" ]]; then
    CONFIG="$XDG_CONFIG_HOME/wezterm/wezterm.lua"
  else
    CONFIG="$HOME/.config/wezterm/wezterm.lua"
  fi

  log() { printf '\033[0;32m==>\033[0m %s\n' "$1"; }
  warn() { printf '\033[0;33m==> WARN:\033[0m %s\n' "$1" >&2; }
  die() { printf '\033[0;31m==> ERROR:\033[0m %s\n' "$1" >&2; exit 1; }

  command -v brew >/dev/null ||
    die "Homebrew not found. Install it from https://brew.sh, then rerun this script."

  # WezTerm itself isn't installed here (its releases are too unstable to pull in
  # unattended); the font and config still go in, ready for when it is
  if brew list --cask wezterm >/dev/null 2>&1 || [[ -d "$WEZTERM_APP" ]]; then
    log "WezTerm found"
  else
    warn "WezTerm not found. Install it from https://wezterm.org/install/macos.html; the config below is ready for it."
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
    return
  fi
  if [[ -e "$CONFIG" ]]; then
    backup="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    mv "$CONFIG" "$backup"
    log "Backed up your existing config to $backup"
  fi
  mv "$tmp" "$CONFIG"
  log "WezTerm config installed at $CONFIG. Restart WezTerm to apply it."
}

main "$@"
