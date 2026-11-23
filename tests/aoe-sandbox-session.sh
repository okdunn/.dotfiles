#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329  # bash -c bodies are evaluated inside the container on purpose; cleanup runs from the EXIT trap
# End-to-end check of a real sandboxed worktree session: creates a throwaway repo under $HOME
# (aoe refuses paths outside it), starts `aoe add -s -w`, inspects the container, then purges
# everything. Needs docker, aoe and the aoe-sandbox-dotfiles image. Takes a few minutes.
set -uo pipefail

failed=0
title="aoe-test-$$"
repo=$(mktemp -d -p "$HOME" aoe-test.XXXX)
worktrees="$repo-worktrees"
container=""

check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
in_container() { docker exec -w "$workdir" "$container" bash -c "$1" 2>&1; }

cleanup() {
  # Anything the container wrote as root has to be handed back before the host can delete it
  [[ -n "$container" ]] && docker exec "$container" chown -R "$(id -u):$(id -g)" /workspace 2>/dev/null
  aoe rm "$title" --purge --delete-worktree >/dev/null 2>&1 || aoe rm "$title" --purge >/dev/null 2>&1
  rm -rf "$repo" "$worktrees"
}
trap cleanup EXIT

git -C "$repo" init -q -b main
printf '[toolchain]\nchannel = "1.99.1"\n' >"$repo/rust-toolchain.toml"
git -C "$repo" add . && git -C "$repo" -c commit.gpgsign=false commit -qm init

(cd "$HOME" && aoe add "$repo" -w test -b -s -t "$title" -l --no-submodules >/dev/null 2>&1) || {
  echo "FAIL session-created"
  exit 1
}

id=$(aoe list 2>/dev/null | awk -v t="$title" '$1 == t {print $NF}')
container="aoe-sandbox-${id:0:8}"
workdir=$(docker inspect "$container" --format '{{.Config.WorkingDir}}' 2>/dev/null)
check container-running test -n "$workdir"

# on_launch hooks run before the agent; give them time to install the pinned toolchain
for _ in $(seq 60); do
  in_container 'command -v cargo' >/dev/null && break
  sleep 5
done

check cargo-on-path-pinned grep -q 'cargo 1\.99\.1' <<<"$(in_container 'cargo --version')"

exit "$failed"
