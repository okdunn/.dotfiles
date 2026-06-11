#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

STOW_ONLY=false
[[ "${1:-}" == "--stow-only" ]] && STOW_ONLY=true

NVIM_VERSION="release-0.11"

APT_PACKAGES=(
  build-essential curl git wget unzip stow
  zsh fzf ripgrep fd-find bat
  ninja-build gettext cmake
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

  if ! require_cmd eza; then
    log "Installing eza..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
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

  if ! require_cmd zoxide; then
    log "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  fi

  if ! require_cmd atuin; then
    log "Installing atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
  fi

  if ! require_cmd lazygit; then
    log "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
      | grep -Po '"tag_name": *"v\K[^"]*')
    [[ -n "$LAZYGIT_VERSION" ]] || { log "Failed to fetch lazygit version from GitHub API"; exit 1; }
    curl -Lo "$HOME/lazygit.tar.gz" \
      "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf "$HOME/lazygit.tar.gz" -C "$HOME" lazygit
    sudo install "$HOME/lazygit" -D -t /usr/local/bin/
    rm -f "$HOME/lazygit" "$HOME/lazygit.tar.gz"
  fi

  if ! require_cmd delta; then
    log "Installing delta..."
    DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" \
      | grep -Po '"tag_name": *"\K[^"]*')
    [[ -n "$DELTA_VERSION" ]] || { log "Failed to fetch delta version from GitHub API"; exit 1; }
    curl -Lo "$HOME/delta.tar.gz" \
      "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-musl.tar.gz"
    tar xf "$HOME/delta.tar.gz" --wildcards '*/delta' --strip-components=1 -C "$HOME"
    sudo install "$HOME/delta" -D -t /usr/local/bin/
    rm -f "$HOME/delta" "$HOME/delta.tar.gz"
  fi

  if ! require_cmd gh; then
    log "Installing gh-cli..."
    out=$(mktemp)
    wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
    rm -f "$out"
  fi

  if ! require_cmd nvim; then
    log "Building Neovim ${NVIM_VERSION}..."
    git clone https://github.com/neovim/neovim.git "$HOME/.nvim-src"
    (
      cd "$HOME/.nvim-src"
      git checkout "$NVIM_VERSION"
      make CMAKE_BUILD_TYPE=RelWithDebInfo
      sudo make install
    )
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

  if ! require_cmd lazydocker; then
    log "Installing lazydocker..."
    LAZYDOCKER_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" \
      | grep -Po '"tag_name": *"v\K[^"]*')
    [[ -n "$LAZYDOCKER_VERSION" ]] || { log "Failed to fetch lazydocker version from GitHub API"; exit 1; }
    curl -Lo "$HOME/lazydocker.tar.gz" \
      "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz"
    tar xf "$HOME/lazydocker.tar.gz" -C "$HOME" lazydocker
    sudo install "$HOME/lazydocker" -D -t /usr/local/bin/
    rm -f "$HOME/lazydocker" "$HOME/lazydocker.tar.gz"
  fi

  if ! require_cmd claude; then
    log "Installing Claude Code..."
    mise exec node@lts -- npm install -g @anthropic-ai/claude-code
  fi

  if ! require_cmd cht.sh; then
    log "Installing cht.sh..."
    curl -s https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cht.sh > /dev/null
    sudo chmod +x /usr/local/bin/cht.sh
  fi
fi

stow_packages "zsh-debian"

log "Installing Neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

if [[ "$SHELL" != "$(command -v zsh)" ]]; then
  log "Changing shell to zsh..."
  chsh -s "$(command -v zsh)"
fi

log "Done!"
