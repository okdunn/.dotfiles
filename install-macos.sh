#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

STOW_ONLY=false
[[ "${1:-}" == "--stow-only" ]] && STOW_ONLY=true

if [[ "$STOW_ONLY" != "true" ]]; then
  if ! xcode-select -p &>/dev/null; then
    log "Installing Xcode Command Line Tools..."
    xcode-select --install
    log "Re-run this script after Xcode CLT installation completes."
    exit 0
  fi

  if ! require_cmd brew; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  log "Installing packages via Brewfile..."
  brew bundle install --file="$DOTFILES_DIR/Brewfile"

  if [[ ! -d "$HOME/.antidote" ]]; then
    log "Installing Antidote..."
    git clone https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
fi

stow_packages "zsh-macos"

if [[ "$SHELL" != "$(command -v zsh)" ]]; then
  log "Changing shell to zsh..."
  chsh -s "$(command -v zsh)"
fi

log "Done!"
