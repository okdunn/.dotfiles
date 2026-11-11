#!/usr/bin/env bash
# shellcheck disable=SC2088  # "~/..." strings below are labels, not paths
# Health checks for an installed machine. Used by `dot doctor` and tests/cleanroom.sh.
# Source install/common.sh first, then call run_checks; it returns non-zero on any failure.

CHECK_TOOLS=(mise nvim tmux fzf fd bat atuin zoxide eza delta jq btop dust vivid pay-respects claude tldr)

_ok_count=0
_fail_count=0
_ok() { echo -e "  ${GREEN}✓${NC} $1"; _ok_count=$((_ok_count + 1)); }
_fail() { echo -e "  \033[0;31m✗${NC} $1${2:+ — $2}"; _fail_count=$((_fail_count + 1)); }
_check() { # _check "description" command...
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then _ok "$desc"; else _fail "$desc"; fi
}

# Packages this machine should have stowed: base + the saved profile's extras
expected_packages() {
  local extras=() extra
  mapfile -t extras < <(load_profile)
  for extra in "${extras[@]}"; do
    case "$extra" in
      --desktop) echo wezterm ;;
      --langs)   echo mise-langs ;;
    esac
  done
  printf '%s\n' "${PACKAGES[@]}"
}

check_zsh_startup() {
  # Interactive zsh under a pty, the way a real login uses it
  local out
  # shellcheck disable=SC2016  # $t is expanded by the inner zsh
  out=$(script -qc "zsh -i -c 'for t in ${CHECK_TOOLS[*]}; do whence -p \$t >/dev/null || echo MISSING:\$t; done; echo ZSH_OK'" /dev/null 2>&1 | tr -d '\r' |
    sed -E $'s/\x1b\\[[?0-9;]*[a-zA-Z]//g')  # drop terminal control codes (cursor, sync output)
  if ! grep -q '^ZSH_OK' <<<"$out"; then
    _fail "zsh starts cleanly" "$(tail -3 <<<"$out")"
  elif grep -qE 'Traceback|command not found' <<<"$out"; then
    _fail "zsh starts cleanly" "$(grep -E 'Traceback|command not found' <<<"$out" | head -3)"
  else
    _ok "zsh starts cleanly"
  fi
  local missing
  missing=$(grep -o 'MISSING:.*' <<<"$out" | cut -d: -f2 | tr '\n' ' ' || true)
  if [[ -n "$missing" ]]; then _fail "tools on PATH" "missing: $missing"; else _ok "tools on PATH (${#CHECK_TOOLS[@]})"; fi
}

check_stow() {
  local wanted pkgs out
  mapfile -t wanted < <(expected_packages)
  mapfile -t pkgs < <(existing_packages "${wanted[@]}" 2>/dev/null)
  out=$(stow --no-folding --simulate --restow --dir="$DOTFILES_DIR" --target="$HOME" "${pkgs[@]}" 2>&1 || true)
  if grep -qi 'conflict' <<<"$out"; then
    _fail "stow links (${pkgs[*]})" "conflicts — run install.sh --stow-only to back them up and relink"
  else
    _ok "stow links (${pkgs[*]})"
  fi
}

# Inspects the running tmux server rather than starting one: a fresh server would make
# tmux-continuum restore saved sessions into it and could overwrite the resurrect save
check_tmux() {
  if ! tmux has-session 2>/dev/null; then
    echo "  - tmux: no server running, skipped (start tmux and rerun to check plugins)"
    return
  fi
  if tmux show -gv status-right | grep -q continuum_save; then
    _ok "tmux plugins loaded, continuum autosave hooked"
  else
    _fail "tmux continuum autosave hooked" "run ~/.tmux/plugins/tpm/bin/install_plugins, then prefix + r"
  fi
}

check_claude_settings() {
  jq -e '.attribution.commit == "" and .attribution.pr == "" and .attribution.sessionUrl == false' \
    "$HOME/.claude/settings.json"
}

check_tldr() {
  tldr git | grep -qi git
}

run_checks() {
  _ok_count=0 _fail_count=0
  echo "Shell & tools"
  check_zsh_startup
  echo "Links"
  check_stow
  _check "~/.claude/CLAUDE.md linked" test -L "$HOME/.claude/CLAUDE.md"
  _check "eza theme linked" test -L "$HOME/.config/eza/theme.yml"
  _check "git global ignore linked" test -L "$HOME/.config/git/ignore"
  _check "atuin config linked" test -L "$HOME/.config/atuin/config.toml"
  echo "Tool config"
  check_tmux
  _check "bat theme 'Catppuccin Mocha OLED' built" sh -c 'bat --list-themes | grep -q "Catppuccin Mocha OLED"'
  _check "btop theme set" grep -q '^color_theme = "catppuccin_mocha_oled"' "$HOME/.config/btop/btop.conf"
  _check "Claude Code settings merged" check_claude_settings
  _check "git identity set" sh -c 'git config --global --includes user.name && git config --global --includes user.email'
  _check "tldr pages cached" check_tldr

  echo
  if ((_fail_count == 0)); then
    log "All $_ok_count checks passed"
  else
    warn "$_fail_count failed, $_ok_count passed"
    return 1
  fi
}
