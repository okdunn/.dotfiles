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

# Optional install flags (--desktop, --langs) are remembered here, so plain reruns
# and `dot update` keep the same extras without retyping them
PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile"

load_profile() {
  if [[ -r "$PROFILE_FILE" ]]; then
    grep -E '^--(desktop|langs)$' "$PROFILE_FILE" || true
    return
  fi
  # No profile yet (machine installed before profiles existed): infer it from what's linked
  [[ "$(realpath -q "$HOME/.config/wezterm/wezterm.lua")" == "$DOTFILES_DIR"/* ]] && echo --desktop
  [[ "$(realpath -q "$HOME/.config/mise/conf.d/langs.toml")" == "$DOTFILES_DIR"/* ]] && echo --langs
  return 0
}

save_profile() {
  mkdir -p "${PROFILE_FILE%/*}"
  printf '%s\n' "$@" >"$PROFILE_FILE"
}

# Base packages stowed on every machine
PACKAGES=(atuin bat btop claude eza git lazygit mise nvim scripts ssh tmux zsh)

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

# Unlink optional packages that are no longer selected (e.g. after --reset). Unstowing
# a package that was never stowed is a no-op.
unstow_packages() {
  local pkg
  for pkg in "$@"; do
    [[ -d "$DOTFILES_DIR/$pkg" ]] || continue
    stow --no-folding --delete --dir="$DOTFILES_DIR" --target="$HOME" "$pkg"
  done
}

# Merge the tracked Claude Code settings (install/claude-settings.json) into
# ~/.claude/settings.json. Not stowed: Claude Code rewrites that file itself
# (plugins, /config), so only these keys are enforced; everything else is kept.
merge_claude_settings() {
  local src="$DOTFILES_DIR/install/claude-settings.json"
  local dst="$HOME/.claude/settings.json"
  if ! require_cmd jq; then
    warn "jq not found; skipping Claude Code settings merge"
    return 0
  fi
  mkdir -p "$HOME/.claude"
  [[ -s "$dst" ]] || echo '{}' > "$dst"
  local tmp
  tmp="$(mktemp)"
  if jq -s '.[0] * .[1]' "$dst" "$src" > "$tmp"; then
    if cmp -s "$tmp" "$dst"; then
      rm -f "$tmp"
    else
      log "Merging Claude Code settings into $dst"
      cat "$tmp" > "$dst" && rm -f "$tmp"
    fi
  else
    rm -f "$tmp"
    warn "Could not merge Claude Code settings (is $dst valid JSON?)"
  fi
}

# Point btop at the tracked catppuccin OLED theme. btop.conf itself isn't stowed:
# btop rewrites it on exit, so only these two keys are set and the rest is left alone.
set_btop_theme() {
  local conf="$HOME/.config/btop/btop.conf"
  mkdir -p "${conf%/*}"
  touch "$conf"
  local key val
  for kv in 'color_theme="catppuccin_mocha_oled"' 'theme_background=False'; do
    key="${kv%%=*}" val="${kv#*=}"
    if grep -q "^${key} *=" "$conf"; then
      sed -i "s|^${key} *=.*|${key} = ${val}|" "$conf"
    else
      echo "${key} = ${val}" >> "$conf"
    fi
  done
}
