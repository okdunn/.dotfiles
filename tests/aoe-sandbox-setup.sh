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
  unset XDG_CONFIG_HOME STUB_INFO_FAIL STUB_ROOTLESS STUB_BUILD_FAIL STUB_NEW_ID
  export BOOTSTRAP_LABEL=sha-of-ours
  mkdir -p "$HOME" "$STUB" "$SANDBOX/bin"
  AOE_TOML="$HOME/.config/agent-of-empires/config.toml"
  # Answers like podman: `info` (rootless via --format), `image inspect` (--format prints the stubbed label), and `build`
  cat >"$SANDBOX/bin/podman" <<'EOF'
#!/bin/sh
case "$1" in
  info) [ -z "$STUB_INFO_FAIL" ] || exit 1; [ "$2" != --format ] || echo "${STUB_ROOTLESS:-true}" ;;
  image)
    case "$3" in
      dangling-ours) echo "$*" >>"$STUB/calls"; echo "$BOOTSTRAP_LABEL"; exit 0 ;;
      dangling-other) echo "$*" >>"$STUB/calls"; echo; exit 0 ;;
    esac
    [ -e "$STUB/image" ] || exit 1
    [ "$4" = --format ] || exit 0
    if [ "$5" = "{{.Id}}" ]; then cat "$STUB/id"; else cat "$STUB/label" 2>/dev/null; fi ;;
  images) echo "$*" >>"$STUB/calls"; cat "$STUB/dangling" 2>/dev/null ;;
  tag) echo "tag $2 $3" >>"$STUB/calls" ;;
  rmi) echo "rmi $2" >>"$STUB/calls" ;;
  build)
    echo "build" >>"$STUB/calls"; echo "$*" >"$STUB/build-args"
    [ -z "$STUB_BUILD_FAIL" ] || exit 1
    touch "$STUB/image" "$STUB/built"; echo "${STUB_NEW_ID:-new-id}" >"$STUB/id" ;;
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

setup; configured; touch "$STUB/image"; echo old-id >"$STUB/id"; run "$REPO/scripts/bin/aoe-sandbox-build"
check build-tags-previous bash -c 'grep -n -E "^(tag|build)" "$1" | sed "s/^[0-9]*://" | head -2 | tr "\n" "|" | grep -q "^build|tag old-id aoe-sandbox-dotfiles:previous|$"' _ "$STUB/calls"

setup; configured; touch "$STUB/image"; echo same-id >"$STUB/id"; export STUB_NEW_ID=same-id; run "$REPO/scripts/bin/aoe-sandbox-build"
check build-same-id-keeps-previous bash -c '! grep -q "^tag" "$1" && grep -q "^build" "$1"' _ "$STUB/calls"

setup; configured; touch "$STUB/image"; echo old-id >"$STUB/id"; export STUB_BUILD_FAIL=1; run "$REPO/scripts/bin/aoe-sandbox-build"
check build-failure-keeps-previous bash -c '! grep -q "^tag" "$1" && grep -q "^build" "$1"' _ "$STUB/calls"

setup; configured; run "$REPO/scripts/bin/aoe-sandbox-build"
check build-first-time-no-tag bash -c '! grep -q "^tag" "$1" && grep -q "^build" "$1"' _ "$STUB/calls"

setup; configured; printf 'dangling-ours\ndangling-other\n' >"$STUB/dangling"; run "$REPO/scripts/bin/aoe-sandbox-build"
check build-prunes-own-dangling bash -c 'grep -q "^rmi dangling-ours" "$1" && ! grep -q "^rmi dangling-other" "$1"' _ "$STUB/calls"

# --- check_aoe_version ---------------------------------------------------------------------------

aoe_version() { # aoe_version <printed version>
  mkdir -p "$HOME/.config/mise"
  echo '"github:agent-of-empires/agent-of-empires" = "1.24.0"' >"$HOME/.config/mise/config.toml"
  printf '#!/bin/sh\necho "aoe %s"\n' "$1" >"$SANDBOX/bin/aoe"
  chmod +x "$SANDBOX/bin/aoe"
  run 'check_aoe_version; echo "fails=$_fail_count oks=$_ok_count"'
}
setup; aoe_version 1.24.0
check doctor-aoe-version-match out_has "fails=0 oks=1"

setup; aoe_version 1.25.0
check doctor-aoe-version-drift bash -c 'grep -q "fails=1" "$1" && grep -q "bump the pin after running tests/aoe-sandbox-session.sh" "$1"' _ "$SANDBOX/out"

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
