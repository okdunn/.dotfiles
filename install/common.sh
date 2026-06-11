#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOTFILES_DIR

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}==>${NC} $1"; }

require_cmd() { command -v "$1" &>/dev/null; }

backup_conflicts() {
  local platform_pkg="$1"
  local backup_dir="$HOME/.dotfiles-backup/$(date +%Y-%m-%d)"
  local all_pkgs=("${PACKAGES[@]}")
  [[ -n "${platform_pkg:-}" ]] && all_pkgs+=("$platform_pkg")
  local backed_up=0

  for pkg in "${all_pkgs[@]}"; do
    [[ -d "$DOTFILES_DIR/$pkg" ]] || continue
    while IFS= read -r -d '' src; do
      local rel="${src#$DOTFILES_DIR/$pkg/}"
      local target="$HOME/$rel"
      if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$backup_dir/$(dirname "$rel")"
        log "Backing up $target → $backup_dir/$rel"
        mv "$target" "$backup_dir/$rel"
        backed_up=1
      fi
    done < <(find "$DOTFILES_DIR/$pkg" \( -type f -o -type d \) -not -path "$DOTFILES_DIR/$pkg" -print0)
  done

  [[ $backed_up -eq 1 ]] && log "Conflicts backed up to $backup_dir"
}

stow_packages() {
  local platform_pkg="$1"
  backup_conflicts "$platform_pkg"
  local all_pkgs=("${PACKAGES[@]}")
  [[ -n "${platform_pkg:-}" ]] && all_pkgs+=("$platform_pkg")
  log "Stowing: ${all_pkgs[*]}"
  stow --dir="$DOTFILES_DIR" --target="$HOME" "${all_pkgs[@]}"
}

PACKAGES=(claude git lazygit mise nvim scripts wezterm zellij zsh)
