#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

STOW_ONLY=false
[[ "${1:-}" == "--stow-only" ]] && STOW_ONLY=true

APT_PACKAGES=(
  build-essential curl git wget unzip stow
  zsh ripgrep fd-find bat
)

if [[ "$STOW_ONLY" != "true" ]]; then
  log "Updating apt and installing packages..."
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt install -y "${APT_PACKAGES[@]}"

  if ! require_cmd mise; then
    log "Installing mise..."
    curl https://mise.run | sh
  fi

  if [[ ! -d "$HOME/.antidote" ]]; then
    log "Installing Antidote..."
    git clone https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi

  if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    log "Installing JetBrains Mono Nerd Font..."
    FONT_VERSION=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" \
      | grep -Po '"tag_name": *"\K[^"]*')
    [[ -n "$FONT_VERSION" ]] || { log "Failed to fetch nerd-fonts version"; exit 1; }
    curl -Lo "$HOME/JetBrainsMono.tar.xz" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.tar.xz"
    mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    tar xf "$HOME/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    fc-cache -f
    rm -f "$HOME/JetBrainsMono.tar.xz"
  fi

  if ! require_cmd tldr; then
    log "Installing tealdeer (tldr)..."
    TEALDEER_VERSION=$(curl -s "https://api.github.com/repos/dbrgn/tealdeer/releases/latest" \
      | grep -Po '"tag_name": *"v\K[^"]*')
    [[ -n "$TEALDEER_VERSION" ]] || { log "Failed to fetch tealdeer version from GitHub API"; exit 1; }
    curl -Lo "$HOME/tldr" \
      "https://github.com/dbrgn/tealdeer/releases/download/v${TEALDEER_VERSION}/tealdeer-linux-x86_64-musl"
    sudo install "$HOME/tldr" -D -t /usr/local/bin/
    rm -f "$HOME/tldr"
  fi

  if ! require_cmd thefuck; then
    log "Installing thefuck..."
    if ! require_cmd pipx; then
      sudo apt install -y pipx
    fi
    pipx install thefuck
  fi

  if ! require_cmd cht.sh; then
    log "Installing cht.sh..."
    curl -s https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cht.sh > /dev/null
    sudo chmod +x /usr/local/bin/cht.sh
  fi
fi

stow_packages "zsh-debian"

log "Running mise install..."
mise install

if ! require_cmd claude; then
  log "Installing Claude Code..."
  mise exec node@lts -- npm install -g @anthropic-ai/claude-code
fi

log "Installing Neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

if [[ "$SHELL" != "$(command -v zsh)" ]]; then
  log "Changing shell to zsh..."
  chsh -s "$(command -v zsh)"
fi

log "Done!"
