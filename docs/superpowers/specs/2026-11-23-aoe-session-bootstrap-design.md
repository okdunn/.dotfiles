# aoe as the one agent sandbox: teardown, session bootstrap, stability

## Why

Agent of Empires (aoe) should be the only way agents get a sandbox: start a session in any repo
and it comes up in its own container and worktree with a working dev environment, so several
Claude Code sessions can build different features of the same repo at once. Today two things
undermine that:

- A second, separate system (`~/projects/agent-sandbox`, the `/ticket*` skills) overlaps
  with aoe and has changed the host (LXD, gVisor, firewall rules, Caddy, DNS).
- The aoe setup grew one workaround per commit, each tied to aoe 1.24's current behaviour. It is
  partly JS-specific (husky only; lefthook and pre-commit fail silently), and its toolchain cache
  blocks parallel work: `aoe-sandbox-warm` refuses to run while any sandbox is up, and a session's
  own installs are discarded. The owner is unsure it will keep working as aoe and repos change.

## Goals

- Starting an aoe session in any repo gives the agent: the repo's pinned toolchains, its
  dependencies installed from its lockfile, and its git hooks active, with no per-repo setup in
  this dotfiles repo and no files added to the repo.
- Several sessions in the same repo, started at the same time, don't conflict.
- Adding a toolchain to the shared cache works while sessions are running.
- The ticket system and everything it installed on the host are gone.
- When an aoe or base-image upgrade breaks the setup, a check fails loudly, and going back is one
  step.

## Non-goals

- Previews (per-session URLs). Maybe a separate project later.
- Running services or `docker compose` inside sessions (no nested container runtime). Agents
  build and run unit tests; the owner runs compose gates and CI when reviewing.
- Repos declaring their own bootstrap (`.aoe/bootstrap` or similar). Possible later extension.
- Using the repos' `.devcontainer/` or `flake.nix` as the sandbox definition.
- Changing the git guard or the overlay's tamper protection.

## Anti-goals

- A session being able to change toolchains or dependency caches that other sessions execute.
- A bootstrap failure blocking a session from starting (it must log and carry on).
- Repo-specific logic (named projects) in this repo.
- Teardown touching the owner's own host Docker stack (`work-*` containers in host Docker) or
  anything not installed by the ticket system.

## Approaches

**Session bootstrap**

1. **One bootstrap script, tracked here and built into the image, that detects what a repo needs
   from its files (chosen).** Repos stay untouched; anything using common tools works; the
   detection list is maintained here.
2. Repos declare their own bootstrap script, with (1) as fallback. More flexible, but means adding
   files to every repo, including shared work ones. Deferred.
3. Use each repo's devcontainer as the sandbox. Only work repos have one, it means one heavy image
   per repo, and aoe would need to support it. Rejected.

**Toolchain cache**

1. **Generational snapshots on the host (chosen).** Each warm builds a new generation; new sessions
   mount the newest; running sessions keep the one they started with; unused generations are
   deleted. Keeps the overlay's tamper protection, removes the stop-all-sessions rule.
2. One shared, writable cache. Simplest and self-warming, but any session could tamper with tools
   the next session runs. Rejected: that protection was chosen deliberately.
3. Keep today's single overlay volume. Rejected: blocks warming while sessions run.

**Services inside sessions.** Nested rootless Podman per session was considered and rejected for
now: it needs `--privileged`, per-session image storage with its own cleanup, rebuilds the backend's 10
service images per session, and realistically caps parallelism at about two backend sessions on this
8-core / 31 GB host.

## Design

Three parts, built in this order.

### Part 1: remove the ticket system

The repo (`~/projects/agent-sandbox`) has never been committed; its `main` has no commits.

1. Archive it first (tarball, including `~/.local/share/agent-previews` and
   `~/.config/agent-previews`), outside `~/projects`.
2. Undo what its scripts installed, using the scripts themselves (`box/01-host-setup.sh`,
   `box/02-host-install-gvisor.sh`, `box/previews-firewall.sh`, `caddy/`) as the inventory:
   - the LXD container `previews`, its storage pool, bridge `prevbr0`, the LXD snap, the
     `overlay`/`br_netfilter` boot module config it added, and the owner's `lxd` group membership
   - `previews-firewall.service`, `/usr/local/sbin/previews-firewall.sh` and its iptables chains
     and rules (including any in `DOCKER-USER`)
   - the `runsc` runtime in `/etc/docker/daemon.json` (restore from the dated backup if unchanged
     since, otherwise remove just that key), then reload Docker; the gVisor apt repo and `runsc`
   - the `agent-previews` Caddy container and its image
   - the `/ticket`, `/ticket-approve`, `/ticket-clean`, `/ticket-rework`, `/ticket-status` skills
     in `~/.claude/skills/` (untracked, local)
   - the Cloudflare DNS record `*.preview.example.com` and its API token: **ask the owner** before
     touching anything external
3. Then delete the repo and the two data directories.

Steps that need root are given to the owner to run (`! sudo …`). Host Docker containers that the
ticket system didn't create are left alone; any whose origin is unclear (e.g. `stack-*`) are
listed for the owner to decide.

### Part 2: session bootstrap

**Script.** One script, tracked at `aoe/.config/agent-of-empires/sandbox/` and copied into the
image by the Dockerfile (on PATH). `on_launch` becomes a single call to it, replacing today's two
inline entries. It runs in the worktree, does each step independently, logs each step's outcome to
stdout and to a log file outside the worktree (so the worktree stays clean), and always exits 0.
The image records a hash of the script (label) so `dot doctor` can tell the image is stale.

**The agent waits for the bootstrap (owner's decision).** It runs in the foreground of
`on_launch`, so the agent always starts with the environment ready. Every step has its own time
limit; a step that hits it is killed and logged as timed out, and the bootstrap moves on, so a
network stall can't hang a session. Limits are the builder's call (generous: a cold backend
install with two sessions starting at once can take several minutes).

Already settled from the repos (builder check): every pnpm repo pins pnpm in `mise.toml`, so
"tool on PATH" holds after step 1 without corepack; no repo needs registry credentials or SSH git
dependencies, so none are passed into sandboxes.

Steps, in order:

1. **Toolchains.** `mise install`, strictly from `mise.lock` when present (today's behaviour).
2. **Dependencies,** chosen by lockfile, only when the tool is on PATH:
   `pnpm-lock.yaml` → `pnpm install --frozen-lockfile`, `package-lock.json` → `npm ci`,
   `yarn.lock` → `yarn install --immutable`, `bun.lock`/`bun.lockb` → `bun install --frozen-lockfile`,
   `uv.lock` → `uv sync --frozen`, `Cargo.lock` → `cargo fetch --locked`, `go.mod` →
   `go mod download`, `Gemfile.lock` → `bundle install`. Lockfiles are never rewritten. Package
   caches are per session (inside the container); sharing them is out of scope because it would
   reopen the tamper anti-goal.

   **Scope: the repo root plus workspaces it declares (owner's decision).** `go.work` at the root
   means `go mod download` in every module it lists (backend has no root `go.mod`, ~20
   modules under `go.work`, linters pinned in `tools/go.mod`); pnpm, npm/yarn and Cargo
   workspaces declared at the root are handled by the tool's own workspace install. Lockfiles in
   unrelated subdirectories (the backend's `tools/`, `scripts/`, `examples/`,
   `evals/`) are skipped; agents install those when they need them.
3. **Git hooks,** after dependencies so a repo's own pinned hook tool is used:
   husky (`package.json` dependency, `.husky/`), lefthook (`lefthook.yml` and variants),
   pre-commit (`.pre-commit-config.yaml`). Each installs the way its tool normally does; husky's
   relative `core.hooksPath` keeps working inside sandboxes as today. Writes to the shared
   `.git/config` and `.git/hooks` retry on git's config lock, because parallel sessions in one repo
   bootstrap at the same moment.

**Toolchain snapshots.** Replace the `aoe-mise` Podman volume with a host directory:
`~/.local/share/aoe-mise/` holding numbered generations and a `current` symlink.

- Sessions mount `<abs path>/current:/opt/mise:O`. Verified with rootless Podman 5.7: the symlink
  resolves at container start, a running container keeps its generation after `current` is
  switched, a new one gets the new generation, and writes never reach the generation.
- The path is absolute and per machine, so the mount is written into each profile's config by the
  installer, like the `~/.gitconfig.local` mount, not into the stowed global config.
- `aoe-sandbox-warm` (same interface) takes a lock, copies `current` to a new generation
  (`cp --reflink=auto`; the cache is 1.8 GB on ext4 today), installs into it with a plain
  read-write mount, switches `current` atomically, then deletes generations that are neither
  `current` nor mounted by a running container. The "sandboxes are running" refusal goes away.
- Migration: the first run seeds generation 1 from the existing `aoe-mise` volume, then removes
  the volume.

**Tests.** `tests/aoe-sandbox-session.sh` is extended: a repo with a pnpm lockfile and lefthook
gets dependencies and hooks; two sessions in one repo started together both finish bootstrapping;
warming while a session runs succeeds, that session still sees the old generation, a new one sees
the new one; a failing bootstrap step doesn't stop the session.

### Part 3: stability

1. **Pin aoe** to the version that passes the end-to-end test, in the mise config, instead of
   `latest`. Upgrading becomes deliberate: bump, run the e2e test, commit. *(Builder's call,
   flagged for the owner.)*
2. **Image rollback.** `aoe-sandbox-build` keeps the previous image under a second tag and removes
   the dangling image the build leaves behind (one 10 GB dangling image exists today). Going back
   means retagging.
3. **`dot doctor`** adds: the image's bootstrap script matches the repo; `current` points to an
   existing generation; every profile has the cache mount; the installed aoe matches the pin.
4. **Investigate** the `preparing isolated .claude configuration` / `opening anchored directory
   component` failures in `~/.config/agent-of-empires/debug.log` (Nov 18–19, they blocked session
   starts), using systematic debugging. Fix it if the cause is in this setup; if it's in aoe,
   document it and any workaround.
5. **Leftovers.** `.aoe-trash` worktrees inside aoe's 30-day trash retention are by design and
   stay. Only ones aoe no longer tracks (the log names `app-worktrees/old-session`) are
   cleaned up, after checking they hold no unmerged work.
6. **README** describes the new bootstrap and cache, and drops the husky-only and "stop sandboxes
   before warming" text.

## Left to the builder

Script names and file layout; the log file location; exact lockfile and hook config filename
variants; per-step time limits; where per-session package caches land inside the container; how
generations are numbered and how the lock is taken; how "mounted by a running container" is
detected (a stopped container re-resolves `current` when it restarts, so only running ones
count); the test harness details.
