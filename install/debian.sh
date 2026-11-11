#!/usr/bin/env bash
# Usage: debian.sh [--stow-only] [--desktop] [--langs]
#   --stow-only  only (re)link dotfiles; skip apt and tool installs
#   --desktop    also install the Nerd Font and stow wezterm (skip on headless servers)
#   --langs      also install language toolchains (go, rust, java, dotnet, ruby, lua)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=install/common.sh
source "$SCRIPT_DIR/common.sh"

STOW_ONLY=false
DESKTOP=false
LANGS=false
for arg in "$@"; do
  case "$arg" in
    --stow-only) STOW_ONLY=true ;;
    --desktop)   DESKTOP=true ;;
    --langs)     LANGS=true ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Tools installed below (mise, claude) land here
export PATH="$HOME/.local/bin:$PATH"

APT_PACKAGES=(
  build-essential curl git wget unzip stow
  zsh ripgrep fd-find bat
  chafa tealdeer htop ncdu
)
$DESKTOP && APT_PACKAGES+=(fontconfig)

install_nerd_font() {
  if fc-list | grep -qi "JetBrainsMono Nerd Font"; then return; fi
  log "Installing JetBrains Mono Nerd Font..."
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  tar xf "$tmp/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  fc-cache -f
  rm -rf "$tmp"
}

if [[ "$STOW_ONLY" != "true" ]]; then
  log "Installing apt packages..."
  sudo apt-get update
  sudo apt-get install -y "${APT_PACKAGES[@]}"

  # Debian ships fd/bat as fdfind/batcat
  mkdir -p "$HOME/.local/bin"
  require_cmd fd  || ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  require_cmd bat || ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"

  if ! require_cmd mise; then
    log "Installing mise..."
    curl -fsSL https://mise.run | sh
  fi

  if [[ ! -d "$HOME/.antidote" ]]; then
    log "Installing Antidote..."
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi

  if ! require_cmd cht.sh; then
    log "Installing cht.sh..."
    curl -fsSL https://cht.sh/:cht.sh -o "$HOME/.local/bin/cht.sh"
    chmod +x "$HOME/.local/bin/cht.sh"
  fi

  if ! require_cmd claude; then
    log "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
  fi

  $DESKTOP && install_nerd_font
fi

EXTRA_PACKAGES=()
$DESKTOP && EXTRA_PACKAGES+=(wezterm)
$LANGS && EXTRA_PACKAGES+=(mise-langs)
stow_packages "${EXTRA_PACKAGES[@]}"

# Register the custom bat theme (delta reads it from bat's cache too)
if require_cmd batcat || require_cmd bat; then
  "$(command -v bat || command -v batcat)" cache --build >/dev/null || warn "bat cache build failed"
fi

if $STOW_ONLY; then
  log "Done (stow only)."
  exit 0
fi

if [[ ! -f "$HOME/.gitconfig.local" && -t 0 ]]; then
  log "Creating ~/.gitconfig.local (git identity for this machine)..."
  read -rp "  git user.name:  " git_name
  read -rp "  git user.email: " git_email
  git config --file "$HOME/.gitconfig.local" user.name "$git_name"
  git config --file "$HOME/.gitconfig.local" user.email "$git_email"
fi

log "Running mise install..."
mise install
eval "$(mise activate bash --shims)"

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Installing tmux plugin manager..."
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
log "Installing tmux plugins..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "tmux plugin install failed"

log "Installing Neovim plugins..."
# restore = install the exact versions pinned in lazy-lock.json
nvim --headless "+Lazy! restore" +qa || warn "Neovim plugin install failed; run :Lazy restore manually"

zsh_path="$(command -v zsh)"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  log "Changing shell to zsh..."
  chsh -s "$zsh_path" || warn "chsh failed; run: chsh -s $zsh_path"
fi

log "Done! Open a new shell to pick up changes."
