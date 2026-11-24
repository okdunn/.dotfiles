#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # bash -c bodies are evaluated inside the container on purpose; cleanup runs from the EXIT trap
# End-to-end check of real sandboxed worktree sessions: creates a throwaway repo under $HOME
# (aoe refuses paths outside it), starts `aoe add -s -w` sessions, inspects their containers, then
# purges everything. Needs the container runtime, aoe, the aoe-sandbox-dotfiles image and the
# network. Takes several minutes.
set -uo pipefail

failed=0
titles=()
repo=$(mktemp -d -p "$HOME" aoe-test.XXXX)
worktrees="$repo-worktrees"
runtime=$(sed -n 's/^container_runtime = "\(.*\)"/\1/p' "$HOME/.config/agent-of-empires/config.toml")
runtime=${runtime:-docker}
mise_dir=${AOE_MISE_DIR:-$HOME/.local/share/aoe-mise}
warm="$(cd "$(dirname "$0")/.." && pwd)/scripts/bin/aoe-sandbox-warm"
log=/tmp/aoe-bootstrap.log

check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
not() { ! "$@"; }
# run_in <container> <script>: run in the session's worktree
run_in() { "$runtime" exec -w "$("$runtime" inspect "$1" --format '{{.Config.WorkingDir}}')" "$1" bash -c "$2" 2>&1; }

cleanup() {
  local t c
  for t in "${titles[@]}"; do
    # Under rootful Docker the container writes as root; hand that back so the host can delete it.
    # Rootless Podman already maps container root to you, and a chown there would remap files away.
    c=$(container_of "$t")
    [[ -n "$c" && "$runtime" == docker ]] &&
      docker exec "$c" chown -R "$(id -u):$(id -g)" /workspace 2>/dev/null
    aoe rm "$t" --purge --delete-worktree >/dev/null 2>&1 || aoe rm "$t" --purge >/dev/null 2>&1
  done
  rm -rf "$repo" "$worktrees"
}
trap cleanup EXIT

container_of() {
  local id
  id=$(aoe list 2>/dev/null | awk -v t="$1" '$1 == t {print $NF}')
  [[ -n "$id" ]] && echo "aoe-sandbox-${id:0:8}"
}

add() { # add <title> <branch>
  (cd "$HOME" && aoe add "$repo" -w "$2" -b -s -t "$1" -l --no-submodules >/dev/null 2>&1)
}

# The hooks step runs last and always logs; the fixture configures one hook tool, so its first
# hooks line is also the last line
wait_bootstrapped() {
  for _ in $(seq 120); do
    run_in "$1" "grep -q '^aoe-bootstrap: hooks: ' $log" >/dev/null && return 0
    sleep 5
  done
  return 1
}

bootstrapped_ok() {
  local out
  out=$(run_in "$1" "cat $log")
  grep -Eq '^aoe-bootstrap: hooks: [^:]+: ok$' <<<"$(tail -n1 <<<"$out")" &&
    not grep -Eq '^aoe-bootstrap: .*: (failed|timed out)' <<<"$out"
}
both_bootstrapped_ok() { bootstrapped_ok "$1" && bootstrapped_ok "$2"; }

# True when no mount covers /var/cache/aoe, so package caches stay inside the container
caches_not_on_host() {
  local d
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    [[ "$d" == / || /var/cache/aoe == "$d" || /var/cache/aoe == "$d"/* ]] && return 1
  done < <("$runtime" inspect "$1" --format '{{range .Mounts}}{{println .Destination}}{{end}}')
  return 0
}

git -C "$repo" init -q -b main
cat >"$repo/mise.toml" <<'EOF'
[tools]
node = "26.13.0"
pnpm = "12.22.0"
go = "1.27.3"
lefthook = "2.2.1"
EOF
echo node_modules >"$repo/.gitignore"
echo '{ "name": "fixture", "private": true, "dependencies": { "is-number": "7.0.0" } }' >"$repo/package.json"
cat >"$repo/pnpm-lock.yaml" <<'EOF'
lockfileVersion: '9.0'

settings:
  autoInstallPeers: true
  excludeLinksFromLockfile: false

importers:

  .:
    dependencies:
      is-number:
        specifier: 7.0.0
        version: 7.0.0

packages:

  is-number@7.0.0:
    resolution: {integrity: sha512-41Cifkg6e8TylSpdtTpeLVMqvSBEVzTttHvERD741+pnZ8ANv0004MRL43QKPDlK9cGvNp6NZWZUBlbGXYxxng==}
    engines: {node: '>=0.12.0'}

snapshots:

  is-number@7.0.0: {}
EOF
printf 'go 1.24\n\nuse ./mod\n' >"$repo/go.work"
mkdir "$repo/mod"
printf 'module example.com/mod\n\ngo 1.24\n\nrequire github.com/google/uuid v1.6.0\n' >"$repo/mod/go.mod"
cat >"$repo/lefthook.yml" <<'EOF'
commit-msg:
  commands:
    ok-prefix:
      run: grep -q '^ok' {1}
EOF
git -C "$repo" add . && git -C "$repo" -c commit.gpgsign=false commit -qm init

# Sessions install whatever the cache lacks on every launch; warming first keeps three of them quick
"$warm" "$repo" >/dev/null 2>&1 || {
  echo "FAIL warm-fixture-toolchains"
  exit 1
}

# `aoe add -l` returns only once on_launch hooks finish, so the second can't wait for the first
titles+=("aoe-test-$$" "aoe-test-$$-2")
add "aoe-test-$$" test &
p1=$!
sleep 1
add "aoe-test-$$-2" test2 &
p2=$!
wait "$p1"
rc1=$?
wait "$p2"
if ((rc1 || $?)); then
  echo "FAIL session-created"
  exit 1
fi
c1=$(container_of "aoe-test-$$")
c2=$(container_of "aoe-test-$$-2")
wt1="$worktrees/$(basename "$("$runtime" inspect "$c1" --format '{{.Config.WorkingDir}}' 2>/dev/null)")"

check container-running test -n "$c1" -a -n "$c2"
wait_bootstrapped "$c1"
wait_bootstrapped "$c2"

check bootstrap-deps-installed test -e "$wt1/node_modules/is-number/package.json"
check bootstrap-go-work-downloaded test -n "$(run_in "$c1" \
  'm=$(go env GOMODCACHE) && [[ $m == /var/cache/aoe/* ]] && ls -A "$m/github.com/google"')"
bad=$(run_in "$c1" 'git -c commit.gpgsign=false commit -q --allow-empty -m bad') &&
  bad_rc=0 || bad_rc=$?
check hook-rejects-commit-in-sandbox test "$bad_rc" -ne 0 -a -n "$(grep ok-prefix <<<"$bad")"
check caches-not-on-host caches_not_on_host "$c1"
check parallel-sessions-bootstrap both_bootstrapped_ok "$c1" "$c2"

gen=$(run_in "$c1" 'cat /opt/mise/.generation')
run_in "$c1" "touch /opt/mise/planted-$$" >/dev/null
check session-writes-to-cache-discarded test ! -e "$mise_dir/gen-$gen/planted-$$" -a ! -e "$mise_dir/current/planted-$$"

check warm-while-running bash -c '"$1" node@24.22.3 >/dev/null 2>&1' _ "$warm"
check running-session-keeps-gen test "$(run_in "$c1" 'cat /opt/mise/.generation')" = "$gen"

titles+=("aoe-test-$$-3")
add "aoe-test-$$-3" test3 || {
  echo "FAIL session-created"
  exit 1
}
new_gen=$(cat "$mise_dir/current/.generation")
check new-session-gets-new-gen test "$new_gen" -gt "$gen" -a \
  "$(run_in "$(container_of "aoe-test-$$-3")" 'cat /opt/mise/.generation')" = "$new_gen"

run_in "$c1" 'echo x >f.txt && git add f.txt && git -c commit.gpgsign=false commit -qm "ok probe"' >/dev/null
check container-writes-owned-by-user test -z "$(find "$repo" "$worktrees" -not -user "$(id -u)" -print -quit)"
check host-can-commit-after-container bash -c \
  'git -C "$1" -c commit.gpgsign=false commit -q --allow-empty -m "ok host" >/dev/null 2>&1' _ "$wt1"

exit "$failed"
