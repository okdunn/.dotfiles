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
runtime=$(sed -n 's/^container_runtime = "\(.*\)"/\1/p' "$HOME/.config/agent-of-empires/config.toml")
runtime=${runtime:-docker}
warm="$(cd "$(dirname "$0")/.." && pwd)/scripts/bin/aoe-sandbox-warm"

check() { # check name condition...
  local name="$1"
  shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
}
in_container() { "$runtime" exec -w "$workdir" "$container" bash -c "$1" 2>&1; }

cleanup() {
  # Under rootful Docker the container writes as root; hand that back so the host can delete it.
  # Rootless Podman already maps container root to you, and a chown there would remap files away.
  [[ -n "$container" && "$runtime" == docker ]] &&
    docker exec "$container" chown -R "$(id -u):$(id -g)" /workspace 2>/dev/null
  aoe rm "$title" --purge --delete-worktree >/dev/null 2>&1 || aoe rm "$title" --purge >/dev/null 2>&1
  rm -rf "$repo" "$worktrees"
}
trap cleanup EXIT

git -C "$repo" init -q -b main
printf '[toolchain]\nchannel = "1.99.1"\n' >"$repo/rust-toolchain.toml"
git -C "$repo" add . && git -C "$repo" -c commit.gpgsign=false commit -qm init

# Drop the pinned toolchain from the shared cache so the warm check can't pass on a leftover
mise_volume=$("$runtime" volume inspect aoe-mise --format '{{.Mountpoint}}' 2>/dev/null)
[[ -n "$mise_volume" ]] && rm -rf "$mise_volume"/rustup/toolchains/1.99.1-* "$mise_volume/installs/rust"
"$warm" "$repo" >/dev/null 2>&1
mise_volume=$("$runtime" volume inspect aoe-mise --format '{{.Mountpoint}}' 2>/dev/null)
check warm-caches-repo-toolchain bash -c 'compgen -G "$1/rustup/toolchains/1.99.1-*" >/dev/null' _ "${mise_volume:-/nonexistent}"

(cd "$HOME" && aoe add "$repo" -w test -b -s -t "$title" -l --no-submodules >/dev/null 2>&1) || {
  echo "FAIL session-created"
  exit 1
}

id=$(aoe list 2>/dev/null | awk -v t="$title" '$1 == t {print $NF}')
container="aoe-sandbox-${id:0:8}"
workdir=$("$runtime" inspect "$container" --format '{{.Config.WorkingDir}}' 2>/dev/null)
check container-running test -n "$workdir"

# on_launch hooks run before the agent; give them time to install the pinned toolchain
for _ in $(seq 60); do
  in_container 'command -v cargo' >/dev/null && break
  sleep 5
done

check cargo-on-path-pinned grep -q 'cargo 1\.99\.1' <<<"$(in_container 'cargo --version')"

in_container "touch /opt/mise/planted-$$" >/dev/null
check session-writes-to-cache-discarded test ! -e "${mise_volume:-/nonexistent}/planted-$$"
check warm-refuses-while-sandbox-runs bash -c '! "$1" "$2" >/dev/null 2>&1' _ "$warm" "$repo"

in_container 'echo x >f.txt && git add f.txt && git -c commit.gpgsign=false commit -qm probe' >/dev/null
check container-writes-owned-by-user test -z "$(find "$repo" "$worktrees" -not -user "$(id -u)" -print -quit)"
check host-can-commit-after-container git -C "$worktrees/$(basename "$workdir")" -c commit.gpgsign=false \
  commit -q --allow-empty -m host

exit "$failed"
