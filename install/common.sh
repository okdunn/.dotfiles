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
PACKAGES=(aoe atuin bat btop claude eza git lazygit mise nvim scripts ssh tmux zsh)

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
  # aoe refuses to start when its app dir is group-writable, which a stow-created
  # dir would be under umask 002
  mkdir -p "$HOME/.config/agent-of-empires/themes" "$HOME/.config/agent-of-empires/sandbox"
  chmod 700 "$HOME/.config/agent-of-empires" "$HOME/.config/agent-of-empires/themes" \
    "$HOME/.config/agent-of-empires/sandbox"

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

# atuin installs this hook into ~/.claude/settings.json, which aoe sandboxes share; their
# image has no atuin, so the bare command fails on every Bash call there
ATUIN_HOOK_UNGUARDED='atuin hook claude-code'
ATUIN_HOOK_GUARDED='command -v atuin >/dev/null && atuin hook claude-code || true'

guard_atuin_hook() {
  local dst="$HOME/.claude/settings.json" tmp
  [[ -f "$dst" ]] && require_cmd jq || return 0
  tmp="$(mktemp)"
  if jq --arg u "$ATUIN_HOOK_UNGUARDED" --arg g "$ATUIN_HOOK_GUARDED" \
    'walk(if type == "object" and .command == $u then .command = $g else . end)' "$dst" >"$tmp"; then
    if ! cmp -s "$tmp" "$dst"; then
      log "Guarding atuin's Claude Code hook in $dst"
      cat "$tmp" >"$dst"
    fi
  else
    warn "Could not guard atuin's Claude Code hook (is $dst valid JSON?)"
  fi
  rm -f "$tmp"
}

# aoe mounts ~/.gitconfig into sandboxes but not the ~/.gitconfig.local it includes, which
# holds the git identity
AOE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agent-of-empires/config.toml"
AOE_GITCONFIG_MOUNT="$HOME/.gitconfig.local:/root/.gitconfig.local:ro"

ensure_aoe_gitconfig_mount() {
  local line="extra_volumes = [\"$AOE_GITCONFIG_MOUNT\"]" tmp
  [[ -d "${AOE_CONFIG%/*}" ]] || return 0
  grep -qF "$AOE_GITCONFIG_MOUNT" "$AOE_CONFIG" 2>/dev/null && return 0
  if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    # Docker would create a root-owned directory in its place
    warn "No ~/.gitconfig.local yet; run git-identity, then rerun install.sh --stow-only for aoe sandboxes"
    return 0
  fi
  if grep -qE '^[[:space:]]*extra_volumes[[:space:]]*=' "$AOE_CONFIG" 2>/dev/null; then
    warn "Add \"$AOE_GITCONFIG_MOUNT\" to sandbox.extra_volumes in $AOE_CONFIG so aoe sandboxes get your git identity"
    return 0
  fi
  local header='^[[:space:]]*\[sandbox\][[:space:]]*(#.*)?$'
  if grep -qE "$header" "$AOE_CONFIG" 2>/dev/null; then
    tmp="$(mktemp)"
    awk -v l="$line" -v h="$header" '{ print } $0 ~ h { print l }' "$AOE_CONFIG" >"$tmp" && cat "$tmp" >"$AOE_CONFIG"
    rm -f "$tmp"
  else
    printf '\n[sandbox]\n%s\n' "$line" >>"$AOE_CONFIG"
  fi
  log "Mounted ~/.gitconfig.local into aoe sandboxes ($AOE_CONFIG)"
}

setup_claude() {
  merge_claude_settings
  guard_atuin_hook
  ensure_aoe_gitconfig_mount
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
