#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install.sh [--stow-only] [--desktop] [--langs] [--reset]
  --stow-only  only (re)link dotfiles; skip apt and tool installs
  --desktop    also install the Nerd Font and stow wezterm (skip on headless servers)
  --langs      also install language toolchains (go, rust, java, dotnet, ruby, lua)
  --reset      forget the saved --desktop/--langs choice and use the base install
  -h, --help   show this help

--desktop/--langs are saved to ~/.config/dotfiles/profile and reused when a later
run (or `dot update`) passes neither of them.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=install/common.sh
source "$SCRIPT_DIR/common.sh"

STOW_ONLY=false
DESKTOP=false
LANGS=false
RESET=false
EXTRAS=()
for arg in "$@"; do
  case "$arg" in
    --stow-only) STOW_ONLY=true ;;
    --desktop)   EXTRAS+=(--desktop) ;;
    --langs)     EXTRAS+=(--langs) ;;
    --reset)     RESET=true ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

# Explicit extras replace the saved profile; none given means reuse it (unless --reset)
if ((${#EXTRAS[@]} == 0)) && ! $RESET; then
  mapfile -t EXTRAS < <(load_profile)
  ((${#EXTRAS[@]} == 0)) || log "Using saved profile: ${EXTRAS[*]}"
fi
for extra in "${EXTRAS[@]}"; do
  case "$extra" in
    --desktop) DESKTOP=true ;;
    --langs)   LANGS=true ;;
  esac
done
save_profile "${EXTRAS[@]}"

# Everything that needs input happens here, so the rest of the run is unattended.
# Rerun git-identity any time to change name/email.
require_cmd git && "$DOTFILES_DIR/scripts/bin/git-identity" --if-missing
if [[ "$STOW_ONLY" != "true" ]]; then
  log "sudo is needed for apt and to set zsh as your login shell"
  sudo -v
fi

# Tools installed below (mise, claude) land in ~/.local/bin; mise-managed tools
# (jq, nvim...) resolve via shims once installed, including on --stow-only runs
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

APT_PACKAGES=(
  build-essential curl git wget unzip stow
  zsh ripgrep fd-find bat
  chafa htop ncdu
  # rootless runtime for aoe sandboxes: container root maps to you, so repo files stay yours
  podman uidmap
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

  # Right after apt: zsh exists now and the sudo password is still cached
  zsh_path="$(command -v zsh)"
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
    log "Changing shell to zsh..."
    sudo chsh -s "$zsh_path" "$USER" || warn "chsh failed; run: chsh -s $zsh_path"
  fi

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


EXTRA_PACKAGES=() UNUSED_PACKAGES=()
if $DESKTOP; then EXTRA_PACKAGES+=(wezterm); else UNUSED_PACKAGES+=(wezterm); fi
if $LANGS; then EXTRA_PACKAGES+=(mise-langs); else UNUSED_PACKAGES+=(mise-langs); fi
unstow_packages "${UNUSED_PACKAGES[@]}"
stow_packages "${EXTRA_PACKAGES[@]}"

# Register the custom bat theme (delta reads it from bat's cache too)
if require_cmd batcat || require_cmd bat; then
  "$(command -v bat || command -v batcat)" cache --build >/dev/null || warn "bat cache build failed"
fi

# Untracked per-project/tool shell config, sourced by .zshrc
mkdir -p "$HOME/.zshrc.d"

set_btop_theme

if $STOW_ONLY; then
  setup_claude
  log "Done (stow only)."
  exit 0
fi

log "Running mise install..."
mise install
eval "$(mise activate bash --shims)"

# tealdeer ships without a page cache, so `tldr` fails until it's fetched once
if ! tldr tar >/dev/null 2>&1; then
  log "Fetching tldr pages..."
  tldr --update >/dev/null || warn "tldr --update failed; run it manually"
fi
setup_claude
ensure_aoe_sandbox_image

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Installing tmux plugin manager..."
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
log "Installing tmux plugins..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "tmux plugin install failed"

log "Installing Neovim plugins..."
# restore = install the exact versions pinned in lazy-lock.json
nvim --headless "+Lazy! restore" +qa || warn "Neovim plugin install failed; run :Lazy restore manually"

log "Done! Open a new shell to pick up changes."
