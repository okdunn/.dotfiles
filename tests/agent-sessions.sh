#!/usr/bin/env bash
# shellcheck disable=SC2016  # the bash -c bodies get their values as $1.. on purpose
# Tests for the agent-session setup in install/common.sh (atuin hook guard, aoe gitconfig and
# toolchain cache mounts) and their dot doctor checks. HOME is a temp dir; nothing outside it is
# touched.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
failed=0

setup() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home"
  unset XDG_CONFIG_HOME AOE_MISE_DIR
  mkdir -p "$HOME/.claude"
  SETTINGS="$HOME/.claude/settings.json"
  AOE_DIR="$HOME/.config/agent-of-empires"
  AOE_TOML="$AOE_DIR/config.toml"
  PROF="$AOE_DIR/profiles/main/config.toml"
  MOUNT="$HOME/.gitconfig.local:/root/.gitconfig.local:ro"
  CACHE="$HOME/.local/share/aoe-mise"
  CACHE_LINE="extra_run_args = [\"-v\", \"$CACHE/current:/opt/mise:O\"]"
}
# run "<shell code>": source the installer libs, then run it; output lands in $SANDBOX/out
run() {
  bash -c 'source "$1/install/common.sh"; source "$1/install/checks.sh"; set +e; eval "$2"' _ "$REPO" "$1" \
    >"$SANDBOX/out" 2>&1
}
check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}

UNGUARDED='atuin hook claude-code'
GUARDED='command -v atuin >/dev/null && atuin hook claude-code || true'
settings_with() { # settings_with <atuin command>
  jq -n --arg a "$1" '{attribution: {commit: ""},
    hooks: {PreToolUse: [{matcher: "Bash", hooks: [{type: "command", command: $a}]},
                         {hooks: [{type: "command", command: "sh -c foo"}]}]}}' >"$SETTINGS"
}

# --- guard_atuin_hook ---------------------------------------------------------------------

setup; settings_with "$UNGUARDED"; run guard_atuin_hook
check atuin-guard bash -c 'jq -e --arg g "$2" --arg u "$3" \
  "[.. | .command? // empty] | (index(\$g) != null) and (index(\$u) == null) and (index(\"sh -c foo\") != null)" "$1" >/dev/null && jq -e ".attribution.commit == \"\"" "$1" >/dev/null' _ "$SETTINGS" "$GUARDED" "$UNGUARDED"

setup; settings_with "$UNGUARDED"; run guard_atuin_hook; cp "$SETTINGS" "$SANDBOX/first"; run guard_atuin_hook
check atuin-idempotent cmp -s "$SETTINGS" "$SANDBOX/first"

setup; echo '{}' >"$SETTINGS"; run guard_atuin_hook
check atuin-no-hooks bash -c '[[ "$(cat "$1")" == "{}" ]]' _ "$SETTINGS"

setup; echo 'not json' >"$SETTINGS"; run guard_atuin_hook
check atuin-bad-json bash -c '[[ "$(cat "$1")" == "not json" ]] && grep -q WARN "$2"' _ "$SETTINGS" "$SANDBOX/out"

# --- ensure_aoe_gitconfig_mount -----------------------------------------------------------
# The mount goes in each aoe profile's config (untracked, per machine): the global config is
# stowed from the repo, and a profile's extra_volumes replaces the global list anyway.

profile() { mkdir -p "${PROF%/*}"; touch "$HOME/.gitconfig.local"; [[ $# == 0 ]] || printf "%b" "$1" >"$PROF"; }

setup; touch "$HOME/.gitconfig.local"; run ensure_aoe_gitconfig_mount
check aoe-absent test ! -e "$AOE_DIR"

setup; mkdir -p "${PROF%/*}"; run ensure_aoe_gitconfig_mount
check aoe-no-local bash -c '[[ ! -s "$1" ]] && grep -q WARN "$2"' _ "$PROF" "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"; run ensure_aoe_gitconfig_mount
check aoe-bootstrap-main bash -c 'grep -qx "\[sandbox\]" "$1" && grep -qxF "extra_volumes = [\"$2\"]" "$1" &&
  [[ $(stat -c %a "${1%/*}") == 700 && $(stat -c %a "${1%/*/*}") == 700 ]]' _ "$PROF" "$MOUNT"

setup; profile; mkdir -p "$AOE_DIR/profiles/work"; run ensure_aoe_gitconfig_mount
check aoe-all-profiles bash -c 'grep -qF "$2" "$1" && grep -qF "$2" "${1%/main/*}/work/config.toml"' _ "$PROF" "$MOUNT"

setup; profile; printf '[sandbox]\nextra_volumes = []\n' >"$AOE_TOML"; cp "$AOE_TOML" "$SANDBOX/orig"; run ensure_aoe_gitconfig_mount
check aoe-global-untouched cmp -s "$AOE_TOML" "$SANDBOX/orig"

setup; profile '[sandbox]\nenabled_by_default = true\n[session]\nx = 1\n'; run ensure_aoe_gitconfig_mount
check aoe-existing-sandbox bash -c 'sed -n "/^\[sandbox\]/,/^\[session\]/p" "$1" | grep -qF "$2" &&
  grep -qx "enabled_by_default = true" "$1" && grep -qx "x = 1" "$1"' _ "$PROF" "$MOUNT"

setup; profile '[sandbox]  # mine\nenabled_by_default = true\n'; run ensure_aoe_gitconfig_mount
check aoe-header-comment bash -c '[[ $(grep -c "^\\[sandbox\\]" "$1") == 1 ]] && sed -n 2p "$1" | grep -qF "$2"' _ "$PROF" "$MOUNT"

setup; profile '[sandbox]\nextra_volumes = ["/a:/a"]\n'; cp "$PROF" "$SANDBOX/orig"; run ensure_aoe_gitconfig_mount
check aoe-existing-array bash -c 'cmp -s "$1" "$2" && grep -q WARN "$3" && grep -qF "$4" "$3"' _ "$PROF" "$SANDBOX/orig" "$SANDBOX/out" "$MOUNT"

setup; profile; run ensure_aoe_gitconfig_mount; run ensure_aoe_gitconfig_mount
check aoe-idempotent bash -c '[[ $(grep -cF "$2" "$1") == 1 ]]' _ "$PROF" "$MOUNT"

setup; profile '[sandbox]\nextra_volumes = []\n[session]\nx = 1\n'; run ensure_aoe_gitconfig_mount
check aoe-empty-array bash -c 'grep -qxF "extra_volumes = [\"$2\"]" "$1" && [[ $(grep -c extra_volumes "$1") == 1 ]] &&
  grep -qx "x = 1" "$1"' _ "$PROF" "$MOUNT"

# --- ensure_aoe_cache_mount ---------------------------------------------------------------
# Also per profile: like extra_volumes, a profile's extra_run_args replaces the global list.

setup; mkdir -p "$AOE_DIR"; run ensure_aoe_cache_mount
check cache-mount-main bash -c 'grep -qx "\[sandbox\]" "$1" && grep -qxF "$2" "$1" &&
  [[ $(stat -c %a "${1%/*}") == 700 && $(stat -c %a "${1%/*/*}") == 700 ]]' _ "$PROF" "$CACHE_LINE"

setup; profile; mkdir -p "$AOE_DIR/profiles/work"; run ensure_aoe_cache_mount
check cache-mount-all-profiles bash -c 'grep -qxF "$2" "$1" && grep -qxF "$2" "${1%/main/*}/work/config.toml"' _ "$PROF" "$CACHE_LINE"

setup; profile '[sandbox]\nextra_run_args = ["--cpus", "2"]\n'; cp "$PROF" "$SANDBOX/orig"; run ensure_aoe_cache_mount
check cache-mount-existing-array-warns bash -c 'cmp -s "$1" "$2" && grep -q WARN "$3" && grep -qF "/opt/mise:O" "$3"' \
  _ "$PROF" "$SANDBOX/orig" "$SANDBOX/out"

setup; profile '[sandbox]\nextra_run_args = []\n[session]\nx = 1\n'; run ensure_aoe_cache_mount
check cache-mount-empty-array bash -c 'grep -qxF "$2" "$1" && [[ $(grep -c extra_run_args "$1") == 1 ]] && grep -qx "x = 1" "$1"' \
  _ "$PROF" "$CACHE_LINE"

setup; profile; run ensure_aoe_cache_mount; run ensure_aoe_cache_mount
check cache-mount-idempotent bash -c '[[ $(grep -cF "$2" "$1") == 1 ]]' _ "$PROF" "$CACHE_LINE"

setup; profile; run ensure_aoe_gitconfig_mount; run ensure_aoe_cache_mount
check cache-mount-beside-gitconfig bash -c '[[ $(grep -c "^\\[sandbox\\]" "$1") == 1 ]] && grep -qF "$2" "$1" && grep -qxF "$3" "$1"' \
  _ "$PROF" "$MOUNT" "$CACHE_LINE"

setup; profile; printf '[sandbox]\nextra_run_args = []\n' >"$AOE_TOML"; cp "$AOE_TOML" "$SANDBOX/orig"; run ensure_aoe_cache_mount
check cache-mount-global-untouched cmp -s "$AOE_TOML" "$SANDBOX/orig"

# --- dot doctor checks --------------------------------------------------------------------

# shellcheck disable=SC2317,SC2329  # called through check
not() { ! "$@"; }
setup; settings_with "$GUARDED"
check doctor-atuin-ok run check_atuin_hook
setup; settings_with "$UNGUARDED"
check doctor-atuin-bad not run check_atuin_hook

doctor_aoe() { run 'check_aoe_mount; echo "fails=$_fail_count oks=$_ok_count"'; }
mounted() { mkdir -p "${1%/*}"; printf '[sandbox]\nextra_volumes = ["%s"]\n' "$MOUNT" >"$1"; }

setup; doctor_aoe
check doctor-aoe-skip bash -c 'grep -q skipped "$1" && grep -q "fails=0" "$1"' _ "$SANDBOX/out"

setup; mounted "$PROF"; doctor_aoe
check doctor-aoe-ok bash -c 'grep -q "fails=0 oks=1" "$1"' _ "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR"; doctor_aoe
check doctor-aoe-no-profiles bash -c 'grep -q "fails=1" "$1"' _ "$SANDBOX/out"

setup; mounted "$PROF"; mkdir -p "$AOE_DIR/profiles/work"; echo '[sandbox]' >"$AOE_DIR/profiles/work/config.toml"; doctor_aoe
check doctor-aoe-missing bash -c 'grep -q "fails=1" "$1" && grep -q "profiles/work/config.toml" "$1"' _ "$SANDBOX/out"

setup; mounted "$PROF"; printf '[commit]\n\tgpgsign = true\n' >"$HOME/.gitconfig.local"; doctor_aoe
check doctor-aoe-signing bash -c 'grep -q "fails=0 oks=1" "$1" && grep -qi "sign" "$1"' _ "$SANDBOX/out"

doctor_cache() { run 'check_aoe_cache; echo "fails=$_fail_count oks=$_ok_count"'; }
# The current-generation check needs a usable runtime: `podman info` succeeds unless STUB_INFO_FAIL
runtime() {
  mkdir -p "$SANDBOX/bin" "$AOE_DIR"
  printf '[sandbox]\ncontainer_runtime = "podman"\n' >"$AOE_TOML"
  printf '#!/bin/sh\n[ "$1" != info ] || [ -z "$STUB_INFO_FAIL" ]\n' >"$SANDBOX/bin/podman"
  chmod +x "$SANDBOX/bin/podman"
}
cache_mounted() { mkdir -p "${PROF%/*}"; printf '[sandbox]\n%s\n' "$CACHE_LINE" >"$PROF"; }
cache_initialised() { mkdir -p "$CACHE/gen-1"; echo 1 >"$CACHE/gen-1/.generation"; ln -s gen-1 "$CACHE/current"; }

setup; doctor_cache
check doctor-cache-skip bash -c 'grep -q skipped "$1" && grep -q "fails=0" "$1"' _ "$SANDBOX/out"

setup; runtime; cache_mounted; cache_initialised; PATH="$SANDBOX/bin:$PATH" doctor_cache
check doctor-cache-ok bash -c 'grep -q "fails=0 oks=2" "$1"' _ "$SANDBOX/out"

setup; runtime; cache_mounted; PATH="$SANDBOX/bin:$PATH" doctor_cache
check doctor-cache-no-current bash -c 'grep -q "fails=1" "$1" && grep -q -- --init "$1"' _ "$SANDBOX/out"

setup; runtime; cache_mounted; cache_initialised; mkdir -p "$AOE_DIR/profiles/work"; echo '[sandbox]' >"$AOE_DIR/profiles/work/config.toml"; doctor_cache
check doctor-cache-unmounted bash -c 'grep -q "fails=1" "$1" && grep -q "profiles/work/config.toml" "$1"' _ "$SANDBOX/out"

setup; runtime; cache_mounted; STUB_INFO_FAIL=1 PATH="$SANDBOX/bin:$PATH" doctor_cache
check doctor-cache-runtime-unusable-skips bash -c 'grep -q "fails=0 oks=1" "$1" && grep -q skipped "$1"' _ "$SANDBOX/out"

exit "$failed"
