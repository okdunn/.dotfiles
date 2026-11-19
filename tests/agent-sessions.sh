#!/usr/bin/env bash
# shellcheck disable=SC2016  # the bash -c bodies get their values as $1.. on purpose
# Tests for the agent-session setup in install/common.sh (atuin hook guard, aoe gitconfig
# mount) and its dot doctor checks. HOME is a temp dir; nothing outside it is touched.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
failed=0

setup() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home"
  unset XDG_CONFIG_HOME
  mkdir -p "$HOME/.claude"
  SETTINGS="$HOME/.claude/settings.json"
  AOE_DIR="$HOME/.config/agent-of-empires"
  AOE_TOML="$AOE_DIR/config.toml"
  MOUNT="$HOME/.gitconfig.local:/root/.gitconfig.local:ro"
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

setup; touch "$HOME/.gitconfig.local"; run ensure_aoe_gitconfig_mount
check aoe-absent test ! -e "$AOE_DIR"

setup; mkdir -p "$AOE_DIR"; run ensure_aoe_gitconfig_mount
check aoe-no-local bash -c '[[ ! -s "$1" ]] && grep -q WARN "$2"' _ "$AOE_TOML" "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"; run ensure_aoe_gitconfig_mount
check aoe-new-file bash -c 'grep -qx "\[sandbox\]" "$1" && grep -qxF "extra_volumes = [\"$2\"]" "$1"' _ "$AOE_TOML" "$MOUNT"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"
printf '[sandbox]\nenabled_by_default = true\n[session]\nx = 1\n' >"$AOE_TOML"; run ensure_aoe_gitconfig_mount
check aoe-existing-sandbox bash -c 'sed -n "/^\[sandbox\]/,/^\[session\]/p" "$1" | grep -qF "$2" &&
  grep -qx "enabled_by_default = true" "$1" && grep -qx "x = 1" "$1"' _ "$AOE_TOML" "$MOUNT"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"
printf '[sandbox]  # mine\nenabled_by_default = true\n' >"$AOE_TOML"; run ensure_aoe_gitconfig_mount
check aoe-header-comment bash -c '[[ $(grep -c "^\\[sandbox\\]" "$1") == 1 ]] && sed -n 2p "$1" | grep -qF "$2"' _ "$AOE_TOML" "$MOUNT"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"
printf '[sandbox]\nextra_volumes = ["/a:/a"]\n' >"$AOE_TOML"; cp "$AOE_TOML" "$SANDBOX/orig"; run ensure_aoe_gitconfig_mount
check aoe-existing-array bash -c 'cmp -s "$1" "$2" && grep -q WARN "$3" && grep -qF "$4" "$3"' _ "$AOE_TOML" "$SANDBOX/orig" "$SANDBOX/out" "$MOUNT"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"; run ensure_aoe_gitconfig_mount; run ensure_aoe_gitconfig_mount
check aoe-idempotent bash -c '[[ $(grep -cF "$2" "$1") == 1 ]]' _ "$AOE_TOML" "$MOUNT"

setup; mkdir -p "$AOE_DIR"; touch "$HOME/.gitconfig.local"
printf '[sandbox]\nextra_volumes = []\n[session]\nx = 1\n' >"$AOE_TOML"; run ensure_aoe_gitconfig_mount
check aoe-empty-array bash -c 'grep -qxF "extra_volumes = [\"$2\"]" "$1" && [[ $(grep -c extra_volumes "$1") == 1 ]] &&
  grep -qx "x = 1" "$1"' _ "$AOE_TOML" "$MOUNT"

# --- dot doctor checks --------------------------------------------------------------------

# shellcheck disable=SC2317  # called through check
not() { ! "$@"; }
setup; settings_with "$GUARDED"
check doctor-atuin-ok run check_atuin_hook
setup; settings_with "$UNGUARDED"
check doctor-atuin-bad not run check_atuin_hook

doctor_aoe() { run 'check_aoe_mount; echo "fails=$_fail_count oks=$_ok_count"'; }

setup; doctor_aoe
check doctor-aoe-skip bash -c 'grep -q skipped "$1" && grep -q "fails=0" "$1"' _ "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR"; printf '[sandbox]\nextra_volumes = ["%s"]\n' "$MOUNT" >"$AOE_TOML"; doctor_aoe
check doctor-aoe-ok bash -c 'grep -q "fails=0 oks=1" "$1"' _ "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR"; echo '[sandbox]' >"$AOE_TOML"; doctor_aoe
check doctor-aoe-missing bash -c 'grep -q "fails=1" "$1"' _ "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR/profiles/main"; printf '[sandbox]\nextra_volumes = ["%s"]\n' "$MOUNT" >"$AOE_TOML"
printf '[sandbox]\nextra_volumes = ["/x:/x"]\n' >"$AOE_DIR/profiles/main/config.toml"; doctor_aoe
check doctor-aoe-profile bash -c 'grep -q "fails=1" "$1" && grep -q "profiles/main/config.toml" "$1"' _ "$SANDBOX/out"

setup; mkdir -p "$AOE_DIR"; printf '[sandbox]\nextra_volumes = ["%s"]\n' "$MOUNT" >"$AOE_TOML"
printf '[commit]\n\tgpgsign = true\n' >"$HOME/.gitconfig.local"; doctor_aoe
check doctor-aoe-signing bash -c 'grep -q "fails=0 oks=1" "$1" && grep -qi "sign" "$1"' _ "$SANDBOX/out"

exit "$failed"
