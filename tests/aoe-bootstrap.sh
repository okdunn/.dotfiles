#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # bash -c bodies take $1.. on purpose; check calls helpers by name
# Tests for aoe-bootstrap. Each case runs it in a temp repo with a PATH of stub commands that
# append "<name> <args> | cwd | MISE_LOCKED" to $CALLS. Stubs are steered by env vars:
# FAIL_<name>=rc, SLEEP_<name>=secs, LOCKERR_<name>=n (print the git config lock error n times).
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
BOOTSTRAP="$PWD/aoe/.config/agent-of-empires/sandbox/aoe-bootstrap"
failed=0

setup() {
  cd / && [[ -z ${SANDBOX:-} ]] || rm -rf "$SANDBOX"
  SANDBOX=$(mktemp -d)
  REPO="$SANDBOX/repo" STUBS="$SANDBOX/stubs" BASE="$SANDBOX/base"
  export CALLS="$SANDBOX/calls" STATE="$SANDBOX/state" AOE_BOOTSTRAP_LOG="$SANDBOX/log"
  mkdir -p "$REPO" "$STUBS" "$BASE" "$STATE"
  : >"$CALLS"
  unset AOE_BOOTSTRAP_TIMEOUT GO_WORK_JSON CI YARN_VERSION
  # A PATH without the host's real toolchains, so "tool missing" cases are deterministic
  for c in bash env timeout sleep cat tee grep sed tr mktemp rm mkdir dirname python3 wc; do
    ln -s "$(command -v "$c")" "$BASE/$c"
  done
  cat >"$SANDBOX/stub" <<'STUB'
#!/bin/bash
n=${0##*/}
echo "$n $* | cwd=$PWD | MISE_LOCKED=${MISE_LOCKED:-} | BUNDLE_FROZEN=${BUNDLE_FROZEN:-} | CI=${CI:-} | stdin=$(cat | wc -c)" >>"$CALLS"
v=${n//-/_}
s=SLEEP_$v
[ -z "${!s:-}" ] || sleep "${!s}"
l=LOCKERR_$v
if [ -n "${!l:-}" ]; then
  c=$(cat "$STATE/$n" 2>/dev/null || echo 0)
  if [ "$c" -lt "${!l}" ]; then
    echo $((c + 1)) >"$STATE/$n"
    echo "error: could not lock config file .git/config" >&2
    exit 1
  fi
fi
f=FAIL_$v
[ -z "${!f:-}" ] || exit "${!f}"
[ "$1" != --version ] || echo "${YARN_VERSION:-4.1.0}"
[ "$1 $2 $3" != "work edit -json" ] || echo "$GO_WORK_JSON"
exit 0
STUB
  chmod +x "$SANDBOX/stub"
  cd "$REPO" || exit 1
}
stub() { for n in "$@"; do ln -s "$SANDBOX/stub" "$STUBS/$n"; done; }
run() { # run [env...]; sets $rc and $elapsed
  local t=$SECONDS
  env "$@" PATH="$STUBS:$BASE" bash -c '"$1"' _ "$BOOTSTRAP" <<<pending >"$SANDBOX/out" 2>&1
  rc=$?
  elapsed=$((SECONDS - t))
}
check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
called() { grep -q -- "$1" "$CALLS"; }
logged() { grep -q -- "$1" "$AOE_BOOTSTRAP_LOG"; }

setup; stub mise pnpm
run
check bootstrap-empty-repo bash -c '[[ $1 == 0 && ! -s $2 && $(grep -c skipped "$3") == 3 && $4 -lt 5 ]]' \
  _ "$rc" "$CALLS" "$AOE_BOOTSTRAP_LOG" "$elapsed"

setup; stub mise; touch mise.lock; run
check toolchains-locked bash -c 'grep -q "^mise install .*MISE_LOCKED=true" "$1"' _ "$CALLS"

setup; stub mise; touch .nvmrc; run
check toolchains-version-file bash -c 'grep -q "^mise install .*MISE_LOCKED= |" "$1"' _ "$CALLS"

setup; stub pnpm; touch pnpm-lock.yaml; run
check deps-pnpm-frozen called "^pnpm install --frozen-lockfile"

setup; stub pnpm; touch pnpm-lock.yaml; run
check deps-no-stdin-and-ci bash -c 'grep -q "^pnpm .*CI=true | stdin=0" "$1"' _ "$CALLS"

setup; stub yarn; touch yarn.lock; run
check deps-yarn-berry-immutable called "^yarn install --immutable"

setup; stub yarn; touch yarn.lock; run YARN_VERSION=1.22.19
check deps-yarn-classic-frozen-lockfile called "^yarn install --frozen-lockfile"

setup; stub bundle; touch Gemfile.lock; run
check deps-bundle-frozen bash -c 'grep -q "^bundle install .*BUNDLE_FROZEN=true" "$1"' _ "$CALLS"

setup; stub go; touch go.work; mkdir a b
export GO_WORK_JSON='{"Use":[{"DiskPath":"./a"},{"DiskPath":"./b"}]}'
run
check deps-go-work-modules bash -c 'grep -q "^go mod download | cwd=.*/repo/a" "$1" && grep -q "^go mod download | cwd=.*/repo/b" "$1"' _ "$CALLS"

setup; stub pnpm; mkdir tools; touch tools/pnpm-lock.yaml; run
check deps-nested-ignored bash -c '! grep -q "^pnpm" "$1"' _ "$CALLS"

setup; touch yarn.lock; run
check deps-tool-missing-skipped bash -c '[[ $1 == 0 ]] && grep -q "deps: yarn: skipped" "$2"' _ "$rc" "$AOE_BOOTSTRAP_LOG"

setup; stub pnpm; echo lock >pnpm-lock.yaml; before=$(cat pnpm-lock.yaml)
run FAIL_pnpm=1
check deps-failure-continues bash -c '[[ $1 == 0 && $(cat pnpm-lock.yaml) == "$2" ]] && grep -q "deps: pnpm: failed (1)" "$3" && grep -q "hooks:" "$3"' \
  _ "$rc" "$before" "$AOE_BOOTSTRAP_LOG"

setup; stub mise pnpm; touch mise.lock pnpm-lock.yaml
run AOE_BOOTSTRAP_TIMEOUT=2 SLEEP_mise=30
check step-timeout bash -c 'grep -q "toolchains: .*timed out" "$1" && grep -q "^pnpm" "$2" && [[ $3 -lt 20 ]]' \
  _ "$AOE_BOOTSTRAP_LOG" "$CALLS" "$elapsed"

setup; stub npx; mkdir -p node_modules/.bin; ln -s "$SANDBOX/stub" node_modules/.bin/husky
echo '{"devDependencies":{"husky":"^9.1.7"}}' >package.json; run
check hooks-husky-local bash -c 'grep -q "^husky " "$1" && ! grep -q "^npx" "$1"' _ "$CALLS"

setup; stub npx; echo '{"devDependencies":{"husky":"^9.1.7"}}' >package.json; run
check hooks-husky-npx-fallback called "^npx --yes husky@9.1.7 "

setup; stub lefthook; touch lefthook.yml; run
check hooks-lefthook called "^lefthook install"

setup; stub uvx; touch .pre-commit-config.yaml; run
check hooks-pre-commit-uvx called "^uvx pre-commit install"

setup; stub lefthook; touch lefthook.yml; run LOCKERR_lefthook=2
check hooks-retry-config-lock bash -c '[[ $(grep -c "^lefthook install" "$1") == 3 ]] && grep -q "hooks: lefthook.*: ok" "$2"' \
  _ "$CALLS" "$AOE_BOOTSTRAP_LOG"

setup; stub mise pnpm npx lefthook uvx go
touch mise.lock pnpm-lock.yaml go.mod lefthook.yml .pre-commit-config.yaml
echo '{"devDependencies":{"husky":"9.0.0"}}' >package.json
run FAIL_mise=1 FAIL_pnpm=1 FAIL_npx=1 FAIL_lefthook=1 FAIL_uvx=1 FAIL_go=1
check always-exit-0 test "$rc" = 0

rm -rf "$SANDBOX"
exit "$failed"
