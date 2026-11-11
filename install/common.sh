#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOTFILES_DIR

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
log()  { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==> WARN:${NC} $1" >&2; }

require_cmd() { command -v "$1" &>/dev/null; }

# Base packages stowed on every machine
PACKAGES=(bat git lazygit mise nvim scripts ssh tmux zsh)

# Keep only packages that exist in the repo, so a missing dir warns instead of aborting stow
existing_packages() {
  local pkg
  for pkg in "$@"; do
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
      echo "$pkg"
    else
      warn "Skipping missing package: $pkg"
    fi
  done
}

backup_conflicts() {
  local backup_dir
  backup_dir="$HOME/.dotfiles-backup/$(date +%Y-%m-%d_%H%M%S)"
  local backed_up=0 pkg src rel target

  for pkg in "$@"; do
    while IFS= read -r -d '' src; do
      rel="${src#"$DOTFILES_DIR/$pkg/"}"
      target="$HOME/$rel"
      # Skip targets that resolve into the repo: a parent dir may already be a stow
      # symlink (e.g. ~/.config/mise -> repo), making the repo file look like a conflict
      if [[ -e "$target" && ! -L "$target" && "$(realpath "$target")" != "$DOTFILES_DIR"/* ]]; then
        mkdir -p "$backup_dir/$(dirname "$rel")"
        log "Backing up $target → $backup_dir/$rel"
        mv "$target" "$backup_dir/$rel"
        backed_up=1
      fi
    done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
  done

  if [[ $backed_up -eq 1 ]]; then log "Conflicts backed up to $backup_dir"; fi
}

# Usage: stow_packages [extra packages...]
stow_packages() {
  local pkgs
  mapfile -t pkgs < <(existing_packages "${PACKAGES[@]}" "$@")

  # Real dirs, so stow links files inside them instead of symlinking the whole dir
  mkdir -p "$HOME/.config" "$HOME/.local/bin"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

  backup_conflicts "${pkgs[@]}"
  log "Stowing: ${pkgs[*]}"
  # --no-folding: link files, never whole dirs, so packages can share dirs (mise + mise-langs)
  # and apps writing new files into e.g. ~/.config/mise never land them in the repo
  stow --no-folding --restow --dir="$DOTFILES_DIR" --target="$HOME" "${pkgs[@]}"
}
