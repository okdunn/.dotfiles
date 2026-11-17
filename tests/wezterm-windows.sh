#!/usr/bin/env bash
# shellcheck disable=SC2016  # PowerShell snippets are single-quoted on purpose
# Tests for install/wezterm-windows.ps1 under PowerShell 7 on Linux. winget is faked as a
# PowerShell function, HOME is a temp dir, and the config is served from the repo over
# localhost. Skips when no pwsh is available (get one with: mise install powershell@latest).
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO_LUA="$PWD/wezterm/.config/wezterm/wezterm.lua"
SCRIPT="$PWD/install/wezterm-windows.ps1"

PWSH=$({ d=$(mise where powershell@latest 2>/dev/null) && echo "$d/pwsh"; } || command -v pwsh || true)
# a mise shim needs the real HOME, which these tests replace
[[ $PWSH == */mise/shims/* ]] && PWSH=""
if [[ -z "$PWSH" ]]; then
  echo "SKIP wezterm-windows tests (pwsh not installed)"
  exit 0
fi

ROOT=$(mktemp -d)
python3 -u -m http.server 0 --bind 127.0.0.1 -d "${REPO_LUA%/*}" >"$ROOT/server.log" 2>&1 &
server=$!
trap 'kill $server 2>/dev/null; rm -rf "$ROOT"' EXIT
for _ in $(seq 50); do
  port=$(grep -o 'port [0-9]*' "$ROOT/server.log" | grep -o '[0-9]*$') && break
  sleep 0.1
done
[[ -n ${port:-} ]] || { echo "FAIL could not start local HTTP server"; exit 1; }
URL="http://127.0.0.1:$port/wezterm.lua"

# Fake winget: `list` succeeds for ids in $env:WINGET_INSTALLED; `install` logs and
# returns $env:WINGET_INSTALL_CODE (default 0). "session-alive" proves iex didn't exit.
cat >"$ROOT/run.ps1" <<'EOF'
function global:winget {
  if ($args[0] -eq 'list') {
    $global:LASTEXITCODE = if ((" $env:WINGET_INSTALLED " -split ' ') -contains $args[3]) { 0 } else { 1 }
  } else {
    Add-Content $env:WINGET_LOG "$args"
    $global:LASTEXITCODE = if ($env:WINGET_INSTALL_CODE) { [int]$env:WINGET_INSTALL_CODE } else { 0 }
  }
}
Get-Content -Raw $env:SCRIPT | Invoke-Expression
"session-alive"
"EAP=$ErrorActionPreference"
EOF

failed=0
# run <case> [VAR=value...]: fresh HOME at $ROOT/<case>; output in $ROOT/<case>.out
run() {
  local name="$1"
  shift
  mkdir -p "$ROOT/$name"
  env -u XDG_CONFIG_HOME -u WEZTERM_CONFIG_FILE HOME="$ROOT/$name" SCRIPT="$SCRIPT" \
    WEZTERM_LUA_URL="$URL" WINGET_LOG="$ROOT/$name.log" "$@" \
    "$PWSH" -NoProfile -File "$ROOT/run.ps1" >"$ROOT/$name.out" 2>&1
}
check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; tail -3 "$ROOT/$name.out"; failed=1; fi
}
alive() { grep -qx session-alive "$ROOT/$1.out" && grep -qx EAP=Continue "$ROOT/$1.out"; }
nbak() { find "$ROOT/$1" -name '*.bak-*' | wc -l; }

run fresh
check fresh bash -c 'cmp -s "$1/fresh/.wezterm.lua" "$2" && grep -q "install -e --id wez.wezterm" "$1/fresh.log" && grep -q "DEVCOM.JetBrainsMonoNerdFont" "$1/fresh.log"' _ "$ROOT" "$REPO_LUA"
alive fresh || { echo "FAIL fresh-session"; failed=1; }

run installed WINGET_INSTALLED="wez.wezterm DEVCOM.JetBrainsMonoNerdFont"
check installed test ! -s "$ROOT/installed.log"

run already-code WINGET_INSTALL_CODE=-1978335189
check already-code cmp -s "$ROOT/already-code/.wezterm.lua" "$REPO_LUA"

run install-fails WINGET_INSTALL_CODE=1
check install-fails bash -c 'grep -q "could not install" "$1" && [[ ! -e $2 ]]' _ "$ROOT/install-fails.out" "$ROOT/install-fails/.wezterm.lua"

mkdir -p "$ROOT/backup"; echo "-- mine" >"$ROOT/backup/.wezterm.lua"; run backup
check backup bash -c '[[ $(find "$1" -name "*.bak-*" | wc -l) == 1 ]] && grep -qx -- "-- mine" "$1"/.wezterm.lua.bak-* && cmp -s "$1/.wezterm.lua" "$2"' _ "$ROOT/backup" "$REPO_LUA"

run idem; run idem
check idem bash -c '[[ $1 == 0 ]] && grep -q "already up to date" "$2"' _ "$(nbak idem)" "$ROOT/idem.out"

mkdir -p "$ROOT/bad-url"; echo "-- mine" >"$ROOT/bad-url/.wezterm.lua"; run bad-url WEZTERM_LUA_URL="http://127.0.0.1:$port/nope.lua"
check bad-url bash -c 'grep -qx -- "-- mine" "$1/.wezterm.lua" && [[ $2 == 0 ]]' _ "$ROOT/bad-url" "$(nbak bad-url)"
alive bad-url || { echo "FAIL bad-url-session"; failed=1; }

# WezTerm loads these before %USERPROFILE%\.wezterm.lua, so the script must write them instead
mkdir -p "$ROOT/dotconfig/.config/wezterm"; echo "-- x" >"$ROOT/dotconfig/.config/wezterm/wezterm.lua"; run dotconfig
check dotconfig bash -c 'cmp -s "$1/.config/wezterm/wezterm.lua" "$2" && [[ ! -e $1/.wezterm.lua ]]' _ "$ROOT/dotconfig" "$REPO_LUA"

run envfile WEZTERM_CONFIG_FILE="$ROOT/envfile/custom/my.lua"
check envfile bash -c 'cmp -s "$1/custom/my.lua" "$2" && [[ ! -e $1/.wezterm.lua ]]' _ "$ROOT/envfile" "$REPO_LUA"

mkdir -p "$ROOT/xdg/x/wezterm"; echo "-- x" >"$ROOT/xdg/x/wezterm/wezterm.lua"; run xdg XDG_CONFIG_HOME="$ROOT/xdg/x"
check xdg bash -c 'cmp -s "$1/x/wezterm/wezterm.lua" "$2" && [[ ! -e $1/.wezterm.lua ]]' _ "$ROOT/xdg" "$REPO_LUA"

exit "$failed"
