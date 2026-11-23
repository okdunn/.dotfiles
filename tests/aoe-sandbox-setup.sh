#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # bash -c bodies take $1.. on purpose; check calls helpers by name
# Tests for building the aoe sandbox image at install time (ensure_aoe_sandbox_image) and its
# dot doctor check (check_aoe_sandbox). HOME is a temp dir and the container runtime is a stub
# on PATH; nothing outside the temp dir is touched.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
failed=0

setup() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home" STUB="$SANDBOX/stub"
  unset XDG_CONFIG_HOME STUB_INFO_FAIL STUB_ROOTLESS
  mkdir -p "$HOME" "$STUB" "$SANDBOX/bin"
  AOE_TOML="$HOME/.config/agent-of-empires/config.toml"
  # Answers like podman: `info` (rootless via --format), `image inspect` (--format prints the stubbed label), and `build`
  cat >"$SANDBOX/bin/podman" <<'EOF'
#!/bin/sh
case "$1" in
  info) [ -z "$STUB_INFO_FAIL" ] || exit 1; [ "$2" != --format ] || echo "${STUB_ROOTLESS:-true}" ;;
  image) [ -e "$STUB/image" ] || exit 1; [ "$4" != --format ] || cat "$STUB/label" 2>/dev/null ;;
  build) touch "$STUB/image" "$STUB/built"; echo "$*" >"$STUB/build-args" ;;
esac
EOF
  chmod +x "$SANDBOX/bin/podman"
  export PATH="$SANDBOX/bin:$PATH"
}
configured() { # configured [runtime]
  mkdir -p "${AOE_TOML%/*}"
  printf '[sandbox]\ncontainer_runtime = "%s"\ndefault_image = "aoe-sandbox-dotfiles:latest"\n' \
    "${1:-podman}" >"$AOE_TOML"
}
run() {
  bash -c 'source "$1/install/common.sh"; source "$1/install/checks.sh"; set +e; eval "$2"' _ "$REPO" "$1" \
    >"$SANDBOX/out" 2>&1
}
doctor() { run 'check_aoe_sandbox; echo "fails=$_fail_count oks=$_ok_count"'; }
check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
BOOTSTRAP_SHA=$(sha256sum "$REPO/aoe/.config/agent-of-empires/sandbox/aoe-bootstrap" | cut -d' ' -f1)
out_has() { grep -q "$1" "$SANDBOX/out"; }

# --- ensure_aoe_sandbox_image ---------------------------------------------------------------

setup; configured; run ensure_aoe_sandbox_image
check ensure-builds-missing-image test -e "$STUB/built"

setup; configured; touch "$STUB/image"; run ensure_aoe_sandbox_image
check ensure-keeps-existing-image test ! -e "$STUB/built"

setup; configured; export STUB_INFO_FAIL=1; run ensure_aoe_sandbox_image
check ensure-warns-runtime-unusable bash -c '! [[ -e "$1/built" ]] && grep -q WARN "$2" && grep -q aoe-sandbox-build "$2"' \
  _ "$STUB" "$SANDBOX/out"

setup; run ensure_aoe_sandbox_image
check ensure-skips-without-aoe bash -c '! [[ -e "$1/built" ]] && ! grep -q WARN "$2"' _ "$STUB" "$SANDBOX/out"

setup; configured; run "$REPO/scripts/bin/aoe-sandbox-build"
check build-passes-bootstrap-sha grep -q "BOOTSTRAP_SHA256=$BOOTSTRAP_SHA" "$STUB/build-args"

# --- check_aoe_sandbox -----------------------------------------------------------------------

setup; configured; touch "$STUB/image"; echo "$BOOTSTRAP_SHA" >"$STUB/label"; doctor
check doctor-sandbox-ok out_has "fails=0 oks=4"
check doctor-bootstrap-current bash -c 'grep -q "bootstrap" "$1"' _ "$SANDBOX/out"

setup; configured; touch "$STUB/image"; echo stale >"$STUB/label"; doctor
check doctor-bootstrap-stale bash -c 'grep -q "fails=1" "$1" && grep -q aoe-sandbox-build "$1"' _ "$SANDBOX/out"

setup; configured; doctor
check doctor-sandbox-no-image bash -c 'grep -q "fails=1" "$1" && grep -q aoe-sandbox-build "$1"' _ "$SANDBOX/out"

setup; configured; touch "$STUB/image"; echo "$BOOTSTRAP_SHA" >"$STUB/label"; export STUB_ROOTLESS=false; doctor
check doctor-sandbox-rootful-podman out_has "fails=1"

setup; configured; export STUB_INFO_FAIL=1; doctor
check doctor-sandbox-runtime-unusable out_has "fails=1"

setup; doctor
check doctor-sandbox-skip bash -c 'grep -q skipped "$1" && grep -q "fails=0" "$1"' _ "$SANDBOX/out"

exit "$failed"
