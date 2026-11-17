#!/usr/bin/env bash
# shellcheck disable=SC2016  # the bash -c bodies get their values as $1.. on purpose
# Tests for install/wezterm-mac.sh on Linux: brew is faked on PATH, HOME is a temp dir,
# and the config is fetched from the repo through a file:// URL.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO_LUA="$PWD/wezterm/.config/wezterm/wezterm.lua"
SCRIPT="$PWD/install/wezterm-mac.sh"
failed=0

# Fresh sandbox: sets HOME, BREW_LOG, a PATH holding fake brew, and CFG
setup() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home" BREW_LOG="$SANDBOX/brew.log" BREW_INSTALLED=""
  export WEZTERM_LUA_URL="file://$REPO_LUA" WEZTERM_APP="$SANDBOX/no-such.app"
  unset XDG_CONFIG_HOME WEZTERM_CONFIG_FILE
  mkdir -p "$HOME" "$SANDBOX/bin"
  : >"$BREW_LOG"
  cat >"$SANDBOX/bin/brew" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$BREW_LOG"
if [[ "$1" == list ]]; then [[ " $BREW_INSTALLED " == *" ${@: -1} "* ]]; fi
EOF
  chmod +x "$SANDBOX/bin/brew"
  BREW_PATH="$SANDBOX/bin:/usr/bin:/bin"
  CFG="$HOME/.config/wezterm/wezterm.lua"
}
run() { PATH="$1" bash "$SCRIPT" >"$SANDBOX/out" 2>&1; }
check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
backups() { find "$HOME/.config/wezterm" -name 'wezterm.lua.bak-*' 2>/dev/null | wc -l; }

setup; run "$BREW_PATH"
check fresh bash -c 'grep -qx "install --cask wezterm" "$1" && grep -qx "install --cask font-jetbrains-mono-nerd-font" "$1" && cmp -s "$2" "$3"' _ "$BREW_LOG" "$CFG" "$REPO_LUA"

setup; mkdir -p "$WEZTERM_APP"; run "$BREW_PATH"
check app-present bash -c '! grep -qx "install --cask wezterm" "$1" && grep -qx "install --cask font-jetbrains-mono-nerd-font" "$1"' _ "$BREW_LOG"

setup; export BREW_INSTALLED="wezterm font-jetbrains-mono-nerd-font"; run "$BREW_PATH"
check installed bash -c '! grep -q "^install" "$1"' _ "$BREW_LOG"

setup; mkdir -p "${CFG%/*}"; echo "-- mine" >"$CFG"; run "$BREW_PATH"
check backup bash -c '[[ $(find "${1%/*}" -name "wezterm.lua.bak-*" | wc -l) == 1 ]] && grep -qx -- "-- mine" "${1%/*}"/wezterm.lua.bak-* && cmp -s "$1" "$2"' _ "$CFG" "$REPO_LUA"

setup; run "$BREW_PATH"; run "$BREW_PATH"
check idempotent test "$(backups)" -eq 0

setup; mkdir -p "$SANDBOX/nobrew"; ln -s "$(command -v bash)" "$SANDBOX/nobrew/bash"
run "$SANDBOX/nobrew:/usr/bin:/bin" && status=0 || status=$?
# /usr/bin may hold a real brew (Linuxbrew); skip the case rather than misreport it
if PATH=/usr/bin:/bin command -v brew >/dev/null; then echo "SKIP no-brew (brew in /usr/bin)"; else
  check no-brew bash -c '[[ $1 != 0 ]] && grep -q brew.sh "$2" && [[ ! -e $3 ]]' _ "$status" "$SANDBOX/out" "$CFG"
fi

setup; mkdir -p "${CFG%/*}"; echo "-- mine" >"$CFG"; export WEZTERM_LUA_URL="file:///nonexistent/wezterm.lua"
run "$BREW_PATH" && status=0 || status=$?
check bad-url bash -c '[[ $1 != 0 ]] && grep -qx -- "-- mine" "$2" && [[ $(find "${2%/*}" -name "wezterm.lua.bak-*" | wc -l) == 0 ]]' _ "$status" "$CFG"

# WezTerm reads $WEZTERM_CONFIG_FILE, then an existing $XDG_CONFIG_HOME/wezterm/wezterm.lua,
# before ~/.config/...; the script must write the file WezTerm will actually load
setup; export WEZTERM_CONFIG_FILE="$SANDBOX/custom/my.lua"; run "$BREW_PATH"
check env-config-file bash -c 'cmp -s "$1" "$2" && [[ ! -e $3 ]]' _ "$WEZTERM_CONFIG_FILE" "$REPO_LUA" "$CFG"

setup; export XDG_CONFIG_HOME="$SANDBOX/xdg"; mkdir -p "$XDG_CONFIG_HOME/wezterm"; echo "-- xdg" >"$XDG_CONFIG_HOME/wezterm/wezterm.lua"; run "$BREW_PATH"
check xdg-existing bash -c 'cmp -s "$1/wezterm/wezterm.lua" "$2" && [[ ! -e $3 ]]' _ "$XDG_CONFIG_HOME" "$REPO_LUA" "$CFG"

# curl | bash runs input as it arrives: a download cut off after the backup but before the
# install must run nothing
setup; mkdir -p "${CFG%/*}"; echo "-- mine" >"$CFG"
cut=$(($(grep -nF 'mv "$tmp" "$CONFIG"' "$SCRIPT" | cut -d: -f1) - 1))
[[ $cut -gt 0 ]] || { echo "FAIL truncated (install line not found)"; failed=1; }
head -n "$cut" "$SCRIPT" | PATH="$BREW_PATH" bash >"$SANDBOX/out" 2>&1
check truncated bash -c 'grep -qx -- "-- mine" "$1"' _ "$CFG"

exit "$failed"
