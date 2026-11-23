# aoe Session Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make aoe the only agent sandbox: remove the ticket system, bootstrap every new session
(toolchains, dependencies, git hooks) in any repo, let toolchain warming run alongside live
sessions, and make aoe/image upgrades deliberate and reversible.

**Architecture:** One bash script, `aoe-bootstrap`, tracked in the stowed sandbox dir and baked
into the sandbox image, is aoe's only `on_launch` hook; it runs three time-limited steps and always
exits 0. The shared toolchain cache moves from the `aoe-mise` Podman volume to host generations
under `~/.local/share/aoe-mise/` with a `current` symlink that sessions mount as an overlay; each
profile config gets that mount from the installer. aoe is pinned in mise and the image build keeps
a `:previous` tag.

**Tech Stack:** bash, rootless Podman 5.7, aoe 1.24.0, mise, GNU coreutils `timeout`/`flock`,
the repo's bash test style (`check name cmd...`, stubs on PATH, temp `HOME`).

**Spec:** `docs/superpowers/specs/2026-11-23-aoe-session-bootstrap-design.md`

## Global Constraints

- The bootstrap always exits 0; a failed or timed-out step is logged and the next step runs.
- Lockfiles are never rewritten (frozen/locked/immutable flags only).
- Package caches are per session, on the container's own filesystem, never a host mount.
- A session can never write a toolchain generation another session mounts.
- No repo-specific logic (no project names) anywhere in this repo.
- Teardown never touches host Docker containers or images the ticket system didn't create, and
  never touches Cloudflare DNS without the owner saying so.
- Root-needing teardown steps are handed to the owner as `! sudo …` commands.
- Commits: Conventional Commits, imperative, lowercase, no trailing period, no attribution lines.
- Code comments only for why/constraints; never narrate.
- Every new `tests/*.sh` that runs offline is added to `tests/check.sh`; network/real-container
  tests (`tests/aoe-sandbox-session.sh`) are not.

## Review Focus

1. A repo with nothing to detect (no lockfiles, no hook config, no mise files): bootstrap logs
   "skipped" lines, finishes in seconds, exits 0. → Task 2 test `bootstrap-empty-repo`.
2. A lockfile whose tool isn't on PATH (`yarn.lock`, no `yarn`): that step is skipped with a log
   line, others still run. → Task 2 test `deps-tool-missing-skipped`.
3. A stale lockfile, so the frozen install fails: logged as failed, lockfile unchanged, hooks step
   still runs. → Task 2 test `deps-failure-continues`.
4. Two sessions in one repo installing hooks at once, colliding on `.git/config.lock`: both end
   with hooks installed. → Task 2 test `hooks-retry-config-lock`, Task 6 e2e
   `parallel-sessions-bootstrap`.
5. Two `aoe-sandbox-warm` runs at once: they serialise, both installs land in the final
   generation. → Task 4 test `warm-serialises`.

---

### Task 1: Remove the ticket system

Operational, outside this repo; nothing is committed. Inventory comes from the scripts in
`~/projects/agent-sandbox/{box,caddy}/`. Read each before undoing it.

- [ ] **Step 1: Archive**

```bash
mkdir -p ~/archive
tar -C ~ -czf ~/archive/agent-sandbox-2026-11-23.tgz \
  projects/agent-sandbox .local/share/agent-previews .config/agent-previews \
  .claude/skills/ticket .claude/skills/ticket-approve .claude/skills/ticket-clean \
  .claude/skills/ticket-rework .claude/skills/ticket-status
tar -tzf ~/archive/agent-sandbox-2026-11-23.tgz | grep -c .
```
Expected: a non-zero count, and the archive lists `projects/agent-sandbox/box/01-host-setup.sh`.

- [ ] **Step 2: List host Docker containers and images of unclear origin**

Run `docker ps -a --format '{{.Names}} {{.Image}} {{.Labels}}'`. Mark as ticket-system only:
`agent-previews` (compose project) and `localhost/agent-previews-caddy:*`. Show the owner every
other container whose name or compose label doesn't obviously belong to their own work dev stack
(at least the `stack-*` ones) and record their answer. Remove nothing in this step.

- [ ] **Step 3: Remove the Caddy container and image (no root needed)**

```bash
docker compose -f ~/projects/agent-sandbox/caddy/compose.yaml down --rmi local
```
Expected: `docker ps -a | grep agent-previews` prints nothing.

- [ ] **Step 4: Hand the owner the root teardown**

Write the commands to `~/archive/ticket-teardown.sh`, derived line by line from what
`box/01-host-setup.sh`, `box/02-host-install-gvisor.sh` and `box/previews-firewall.sh` add:
delete LXD container `previews`, its storage pool, bridge `prevbr0`; `snap remove lxd`; remove the
module-load file for `overlay`/`br_netfilter` it created; `systemctl disable --now
previews-firewall.service`, remove the unit and `/usr/local/sbin/previews-firewall.sh`, flush and
delete the chains/rules it added (including `DOCKER-USER` entries); `gpasswd -d $USER lxd`; restore
`/etc/docker/daemon.json` from the dated backup if the only difference is the `runsc` runtime,
otherwise remove just `.runtimes.runsc` with `jq`; `systemctl reload docker`; remove the gVisor apt
source and `apt-get purge runsc`. Ask the owner to review it, then run `! sudo bash
~/archive/ticket-teardown.sh`.

- [ ] **Step 5: Verify the host is clean**

```bash
snap list lxd; ip link show prevbr0; systemctl status previews-firewall; command -v runsc
jq -e '.runtimes.runsc' /etc/docker/daemon.json; id -nG | tr ' ' '\n' | grep -x lxd
sudo iptables -S | grep -i -E 'prevbr0|previews'
docker info >/dev/null && echo docker-ok
```
Expected: every command reports not found / no output, except `docker-ok`.

- [ ] **Step 6: Ask about DNS, then delete local files**

Ask the owner whether to delete the Cloudflare record `*.preview.example.com` and revoke the token
in `~/.config/agent-previews/dns-token`. Do only what they say. Then:
```bash
rm -rf ~/projects/agent-sandbox ~/.local/share/agent-previews ~/.config/agent-previews \
  ~/.claude/skills/ticket ~/.claude/skills/ticket-{approve,clean,rework,status}
```
Expected: `ls ~/.claude/skills` shows no `ticket*`.

---

### Task 2: `aoe-bootstrap` script

**Files:**
- Create: `aoe/.config/agent-of-empires/sandbox/aoe-bootstrap`
- Create: `tests/aoe-bootstrap.sh`
- Modify: `tests/check.sh` (run the new test after "aoe sandbox setup tests")

**Interfaces:**
- Produces: executable `aoe-bootstrap` (bash, `set -uo pipefail`, no `-e`), run with cwd = worktree.
  - Env: `AOE_BOOTSTRAP_LOG` (default `/tmp/aoe-bootstrap.log`), `AOE_BOOTSTRAP_TIMEOUT` (seconds
    per step, default `900`).
  - Internal re-entry: `aoe-bootstrap --step toolchains|deps|hooks`; the top level runs each as
    `timeout --kill-after=10 "$AOE_BOOTSTRAP_TIMEOUT" "$0" --step <name>`.
  - Log lines (stdout and appended to the log), one per action:
    `aoe-bootstrap: <step>: <action>: ok|failed (<rc>)|timed out|skipped (<reason>)`.
    Timed out = `timeout` rc 124 or 137.
  - Always exits 0.

Step behaviour (from the spec):
- **toolchains:** if any of `mise.toml .mise.toml mise.lock .tool-versions` or the idiomatic version
  files the image enables (the `VERSION_FILES` list in `scripts/bin/aoe-sandbox-warm`) exists: `MISE_LOCKED=true` when `mise.lock` exists, then `mise install`.
- **deps:** root lockfiles → commands, each only if the tool is on PATH:
  `pnpm-lock.yaml`→`pnpm install --frozen-lockfile`, `package-lock.json`→`npm ci`,
  `yarn.lock`→`yarn install --immutable`, `bun.lock`/`bun.lockb`→`bun install --frozen-lockfile`,
  `uv.lock`→`uv sync --frozen`, `Cargo.lock`→`cargo fetch --locked`, `Gemfile.lock`→`bundle install`,
  `go.mod`→`go mod download`. `go.work` (no root `go.mod` needed): `go mod download` in each
  `Use[].DiskPath` from `go work edit -json`. Nested lockfiles are never looked for.
- **hooks:** husky if `package.json` lists `husky` in dependencies/devDependencies: run
  `node_modules/.bin/husky` if present, else `npx --yes husky@<version with ~^ stripped>`.
  lefthook if any of `lefthook.yml lefthook.yaml .lefthook.yml .lefthook.yaml lefthook.toml
  lefthook.json` exists: `node_modules/.bin/lefthook install`, else `lefthook install` on PATH.
  pre-commit if `.pre-commit-config.yaml` exists: `pre-commit install` on PATH, else
  `uvx pre-commit install`. Each hook install is retried up to 5 times, 1 s apart, when its stderr
  contains `could not lock config file`.

Tests run on the host with a temp repo per case and stub commands on PATH that append
`<name> <args>` (and cwd) to `$CALLS`; stubs can be told to fail, sleep, or print the lock error.

- [ ] **Step 1: Write the failing tests in `tests/aoe-bootstrap.sh`**

Structure like `tests/aoe-sandbox-setup.sh` (`setup` makes `$SANDBOX`, repo, stub bin;
`check name cmd…`). Cases and assertions:
```text
bootstrap-empty-repo        exit 0; $CALLS empty; log has 3 "skipped" lines; runtime < 5 s
toolchains-locked           mise.lock present → stub mise saw MISE_LOCKED=true and "install"
deps-pnpm-frozen            pnpm-lock.yaml → "pnpm install --frozen-lockfile"
deps-go-work-modules        go.work using ./a and ./b (no root go.mod) → "go mod download" run in a/ and b/
deps-nested-ignored         tools/pnpm-lock.yaml only → no pnpm call
deps-tool-missing-skipped   yarn.lock, no yarn stub → log "deps: yarn: skipped", exit 0
deps-failure-continues      pnpm stub exits 1 → log "failed (1)", lockfile byte-identical, hooks step still logged
step-timeout                AOE_BOOTSTRAP_TIMEOUT=2, mise stub sleeps 30 → log "toolchains: … timed out", total < 20 s, deps still ran
hooks-husky-local           node_modules/.bin/husky stub exists → it ran, no npx call
hooks-husky-npx-fallback    package.json devDependencies husky "^9.1.7", no node_modules → "npx --yes husky@9.1.7"
hooks-lefthook              lefthook.yml + lefthook stub → "lefthook install"
hooks-pre-commit-uvx        .pre-commit-config.yaml, only uvx stub → "uvx pre-commit install"
hooks-retry-config-lock     lefthook stub prints "could not lock config file" twice then succeeds → 3 calls, log ok
always-exit-0               every stub fails → exit 0
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/aoe-bootstrap.sh`
Expected: FAIL lines (script missing).

- [ ] **Step 3: Implement `aoe/.config/agent-of-empires/sandbox/aoe-bootstrap`** per the Interfaces
  block. Executable bit set.

- [ ] **Step 4: Run tests and lint**

Run: `bash tests/aoe-bootstrap.sh && shellcheck aoe/.config/agent-of-empires/sandbox/aoe-bootstrap`
Expected: all PASS, no shellcheck output.

- [ ] **Step 5: Add the test to `tests/check.sh`, run `dot check`**

Expected: passes.

- [ ] **Step 6: Commit**

```bash
git add aoe/.config/agent-of-empires/sandbox/aoe-bootstrap tests/aoe-bootstrap.sh tests/check.sh
git commit -m "feat(aoe): add a session bootstrap for toolchains, dependencies and hooks"
```

---

### Task 3: Bake the bootstrap into the image and run it on launch

**Files:**
- Modify: `aoe/.config/agent-of-empires/sandbox/Dockerfile`
- Modify: `scripts/bin/aoe-sandbox-build`
- Modify: `aoe/.config/agent-of-empires/config.toml` (`[hooks] on_launch`)
- Modify: `install/common.sh`, `install/checks.sh` (`check_aoe_sandbox`)
- Modify: `tests/aoe-sandbox-setup.sh`

**Interfaces:**
- Consumes: `aoe-bootstrap` from Task 2.
- Produces:
  - Image label `dotfiles.bootstrap-sha256=<sha256 of aoe-bootstrap>`; build arg `BOOTSTRAP_SHA256`.
  - `aoe_bootstrap_sha()` in `install/common.sh`: sha256 of the repo's script.
  - `aoe_image_bootstrap_sha()` in `install/common.sh`: the image's label value.
  - `on_launch = ["aoe-bootstrap"]`.

Dockerfile additions: `COPY aoe-bootstrap /usr/local/bin/aoe-bootstrap`; package caches on the
container's own filesystem:
`ENV XDG_CACHE_HOME=/var/cache/aoe npm_config_cache=/var/cache/aoe/npm
npm_config_store_dir=/var/cache/aoe/pnpm-store GOPATH=/var/cache/aoe/go UV_CACHE_DIR=/var/cache/aoe/uv
BUNDLE_PATH=/var/cache/aoe/bundle`; `ARG BOOTSTRAP_SHA256` + `LABEL dotfiles.bootstrap-sha256=$BOOTSTRAP_SHA256`.
(`CARGO_HOME` stays under `/opt/mise`, whose writes already land in the session's overlay.)

- [ ] **Step 1: Write failing tests in `tests/aoe-sandbox-setup.sh`**

Extend the podman stub: `build` records its args to `$STUB/build-args`; `image inspect --format`
prints `$STUB/label` contents.
```text
build-passes-bootstrap-sha   build-args contain "BOOTSTRAP_SHA256=<sha256sum of the repo script>"
doctor-bootstrap-current     label == repo sha → no fail, ok line mentions bootstrap
doctor-bootstrap-stale       label differs → one fail whose hint says aoe-sandbox-build
```
Update `doctor-sandbox-ok` to the new ok count.

- [ ] **Step 2: Run to verify they fail**

Run: `bash tests/aoe-sandbox-setup.sh` — Expected: the three new cases FAIL.

- [ ] **Step 3: Implement** the Dockerfile changes, `--build-arg BOOTSTRAP_SHA256=…` in
  `aoe-sandbox-build`, the two helpers, the stale check in `check_aoe_sandbox`, and
  `on_launch = ["aoe-bootstrap"]` (replace both inline entries and their comment block with one
  line on why it's a single script call).

- [ ] **Step 4: Run tests**

Run: `bash tests/aoe-sandbox-setup.sh && dot check` — Expected: all PASS.

- [ ] **Step 5: Build the real image and smoke it**

```bash
aoe-sandbox-build
podman run --rm --entrypoint aoe-bootstrap -w /tmp aoe-sandbox-dotfiles:latest; echo rc=$?
podman image inspect aoe-sandbox-dotfiles:latest --format '{{index .Labels "dotfiles.bootstrap-sha256"}}'
```
Expected: three "skipped" lines, `rc=0`, label equals `sha256sum aoe/.config/agent-of-empires/sandbox/aoe-bootstrap`.

- [ ] **Step 6: Update README** (the aoe sandboxes paragraph): `on_launch` runs `aoe-bootstrap`
  (toolchains, root + `go.work`/workspace dependencies, husky/lefthook/pre-commit hooks), its log
  path, per-step time limit, the agent waits for it; drop "Other hook managers … aren't handled".

- [ ] **Step 7: Commit**

```bash
git add -A aoe scripts/bin/aoe-sandbox-build install tests/aoe-sandbox-setup.sh README.md
git commit -m "feat(aoe): run the bootstrap script from the sandbox image on launch"
```

---

### Task 4: Generational toolchain cache

**Files:**
- Modify: `scripts/bin/aoe-sandbox-warm`
- Modify: `aoe/.config/agent-of-empires/config.toml` (remove `extra_run_args` and its comment)
- Modify: `install/common.sh`, `install/checks.sh`, `install/debian.sh`
- Create: `tests/aoe-sandbox-warm.sh`; Modify: `tests/agent-sessions.sh`, `tests/check.sh`

**Interfaces:**
- Produces:
  - Layout: `${AOE_MISE_DIR:-$HOME/.local/share/aoe-mise}/gen-<N>/` (N = 1, 2, …), each with a
    `.generation` file containing `N`; `current` → `gen-<N>` (relative symlink); `.lock` (flock).
  - `aoe-sandbox-warm [repo-dir | tool@version]...` — same arguments as today, no longer refuses
    while sandboxes run. Under `flock .lock`: `cp -a --reflink=auto` current → `gen-<N+1>`, write
    `.generation`, run today's install container with `-v gen-<N+1>:/opt/mise`, then switch
    `current` atomically (`ln -sfn` to a temp name, `mv -T`), then GC. If the install fails, delete
    `gen-<N+1>` and leave `current` alone.
  - `aoe-sandbox-warm --init`: if `current` is missing, create `gen-1`, seeded from the `aoe-mise`
    volume when it exists (copied through a container: `-v aoe-mise:/from:ro -v gen-1:/to`), then
    `"$RUNTIME" volume rm aoe-mise`; otherwise empty. No-op when `current` exists.
  - GC: delete every `gen-*` that isn't `current` and whose number isn't printed by
    `"$RUNTIME" exec <c> cat /opt/mise/.generation` for any running `aoe-sandbox-*` container
    (Podman reports the overlay's lowerdir as the unresolved symlink, so the marker file is the
    reliable source).
  - `AOE_MISE_MOUNT="$AOE_MISE_DIR/current:/opt/mise:O"` and `ensure_aoe_cache_mount` in
    `install/common.sh`: writes `extra_run_args = ["-v", "<AOE_MISE_MOUNT>"]` into each profile's
    `[sandbox]`, with the same cases as `add_aoe_mount` (absent / empty array / existing other
    array → warn / header with comment / idempotent). Factor the shared awk into one helper
    `add_aoe_profile_list <cfg> <key> <toml array body> <marker>` and make `add_aoe_mount` use it.
  - `check_aoe_cache` in `install/checks.sh`: fail if any profile lacks the mount, or `current`
    doesn't resolve to a dir with `.generation`.
  - Installer: after `ensure_aoe_sandbox_image`, run `aoe-sandbox-warm --init` (only when the
    runtime is usable); `setup_claude` also calls `ensure_aoe_cache_mount`.

- [ ] **Step 1: Write failing tests**

`tests/aoe-sandbox-warm.sh` (temp `HOME`, `AOE_MISE_DIR` in it, stub `podman` that: for `run`
with `-v <dir>:/opt/mise` touches `<dir>/installed-<each spec>` (and for `/from` `/to` copies a
fixture dir); `ps` prints `$STUB/running`; `exec <c> cat /opt/mise/.generation` prints
`$STUB/gen-<c>`; `volume inspect/rm` act on `$STUB/volume`):
```text
init-seeds-from-volume      volume fixture file ends up in gen-1, current -> gen-1, volume rm called
init-empty                  no volume → gen-1 exists with .generation "1"
init-idempotent             second --init leaves gen-1 only, current unchanged
warm-new-generation         warm node@24 → gen-2 has installed-node@24 and gen-1's files; current -> gen-2
warm-while-running          container running on gen 1 → warm succeeds; gen-1 kept
gc-unused                   no running containers → after warm only current gen remains
warm-failure-keeps-current  stub run exits 1 → current unchanged, no gen-<N+1> left
warm-serialises             two warms in parallel (node@24, go@1.27) → final current has both, gens numbered without gaps
```
`tests/agent-sessions.sh`: mirror the `aoe-*` mount cases for `ensure_aoe_cache_mount`
(`cache-mount-main`, `cache-mount-all-profiles`, `cache-mount-existing-array-warns`,
`cache-mount-idempotent`, `cache-mount-global-untouched`), plus `doctor-cache-ok` /
`doctor-cache-no-current`. Existing `aoe-*` gitconfig cases must still pass after the refactor.

- [ ] **Step 2: Run to verify they fail**

Run: `bash tests/aoe-sandbox-warm.sh; bash tests/agent-sessions.sh` — Expected: new cases FAIL.

- [ ] **Step 3: Implement** per the Interfaces block. Update the warm script's header usage text.

- [ ] **Step 4: Run tests**

Run: `bash tests/aoe-sandbox-warm.sh && bash tests/agent-sessions.sh && dot check` — Expected: all PASS.

- [ ] **Step 5: Migrate this machine**

```bash
bash install.sh --stow-only && aoe-sandbox-warm --init
readlink ~/.local/share/aoe-mise/current; podman volume ls | grep aoe-mise
grep extra_run_args ~/.config/agent-of-empires/profiles/*/config.toml
```
Expected: `gen-1`; no `aoe-mise` volume; each profile has the `current:/opt/mise:O` mount.

- [ ] **Step 6: Update README**: the cache paragraph describes generations, warming while sessions
  run, `--init`, GC; remove "while no sandbox is running".

- [ ] **Step 7: Commit**

```bash
git add -A scripts/bin/aoe-sandbox-warm aoe install tests README.md
git commit -m "feat(aoe): keep the toolchain cache in generations so warming runs alongside sessions"
```

---

### Task 5: Deliberate aoe and image upgrades

**Files:**
- Modify: `mise/.config/mise/config.toml:26`
- Modify: `scripts/bin/aoe-sandbox-build`
- Modify: `install/checks.sh`; `tests/aoe-sandbox-setup.sh`; `README.md`

**Interfaces:**
- Produces: `"github:agent-of-empires/agent-of-empires" = "1.24.0"` (with a one-line why comment);
  `aoe-sandbox-build` tags the existing `aoe-sandbox-dotfiles:latest` as
  `aoe-sandbox-dotfiles:previous` before building, then removes dangling images whose
  `Config.Labels` include `dotfiles.bootstrap-sha256` (only ours); `check_aoe_version` in
  `install/checks.sh` compares `aoe --version` to the pin in `~/.config/mise/config.toml` and
  fails with hint "bump the pin after running tests/aoe-sandbox-session.sh".

- [ ] **Step 1: Write failing tests** in `tests/aoe-sandbox-setup.sh`:
```text
build-tags-previous         image present → stub saw "tag aoe-sandbox-dotfiles:latest aoe-sandbox-dotfiles:previous" before "build"
build-first-time-no-tag     no image → no tag call, build ran
build-prunes-own-dangling   stub "images" lists a dangling ours + a dangling other → rmi only ours
doctor-aoe-version-match    aoe stub prints "aoe 1.24.0", pin 1.24.0 → ok
doctor-aoe-version-drift    aoe stub prints "aoe 1.25.0" → fail with the hint
```
- [ ] **Step 2: Run to verify they fail** — `bash tests/aoe-sandbox-setup.sh`, new cases FAIL.
- [ ] **Step 3: Implement**, and wire `check_aoe_version` into `run_checks`.
- [ ] **Step 4: Run tests** — `bash tests/aoe-sandbox-setup.sh && dot check`, all PASS; then
  `mise install && aoe --version` prints `aoe 1.24.0`.
- [ ] **Step 5: README**: aoe is pinned and how to upgrade (bump, `bash tests/aoe-sandbox-session.sh`,
  commit); roll back an image with `podman tag aoe-sandbox-dotfiles:previous aoe-sandbox-dotfiles:latest`.
  Fix the "Tool versions are `latest`" paragraph to name the aoe exception.
- [ ] **Step 6: Commit**

```bash
git add mise scripts/bin/aoe-sandbox-build install/checks.sh tests/aoe-sandbox-setup.sh README.md
git commit -m "feat(aoe): pin aoe and keep the previous sandbox image for rollback"
```

---

### Task 6: End-to-end session test

**Files:**
- Modify: `tests/aoe-sandbox-session.sh`

**Interfaces:**
- Consumes: Tasks 2–5 (real image, real aoe, `aoe-sandbox-warm`, `$AOE_MISE_DIR`).

Fixture repo additions: `pnpm-lock.yaml` + `package.json` with one tiny dependency and pnpm pinned
in `mise.toml`; `lefthook.yml` with a `commit-msg` hook rejecting messages not starting with `ok`
(replacing the husky fixture, which stays covered by Task 2 unit tests); a `go.work` with one
module. Wait for completion by polling for the final `aoe-bootstrap: hooks:` line in the container's
log file instead of fixed sleeps.

- [ ] **Step 1: Rewrite the checks**
```text
bootstrap-deps-installed        node_modules/<dep> exists in the worktree
bootstrap-go-work-downloaded    GOMODCACHE in the container is non-empty
hook-rejects-commit-in-sandbox  lefthook blocks "bad" message
caches-not-on-host              no `podman inspect` mount destination is /var/cache/aoe or a parent of it
parallel-sessions-bootstrap     second session (`-w test2`) started right after the first; both logs end with hooks ok
warm-while-running              aoe-sandbox-warm node@<other version> succeeds while both run
running-session-keeps-gen       running container's /opt/mise/.generation unchanged after warm
new-session-gets-new-gen        third session sees the new generation number
session-writes-to-cache-discarded  (kept, against the generation dir)
container-writes-owned-by-user, host-can-commit-after-container  (kept)
```
Remove `warm-refuses-while-sandbox-runs` and the `aoe-mise` volume lookups; cleanup removes all
three sessions.

- [ ] **Step 2: Run it**

Run: `bash tests/aoe-sandbox-session.sh` (network, several minutes)
Expected: every line PASS, exit 0. On a FAIL, fix the owning task's code, rerun its unit tests,
then rerun this.

- [ ] **Step 3: Commit**

```bash
git add tests/aoe-sandbox-session.sh
git commit -m "test(aoe): cover bootstrap, parallel sessions and warming in the session test"
```

---

### Task 7: Session-start failures and leftovers

Uses superpowers:systematic-debugging. No code change is assumed.

- [ ] **Step 1: Reproduce or rule out** the `preparing isolated .claude configuration` /
  `opening anchored directory component` failure: correlate its session ids in
  `~/.config/agent-of-empires/debug.log` with `sessions.json` and `.aoe-trash` paths, and check
  whether it occurs for any session created after Task 6 (search the log after that timestamp).
  Expected outcome, written down: root cause, or "not reproducible on 1.24.0 since <date>" with
  the evidence.
- [ ] **Step 2: Act on it**: a cause in this repo gets a failing test plus fix and a `fix(aoe): …`
  commit; a cause in aoe gets a README note with the workaround (and an upstream issue draft for
  the owner, not filed).
- [ ] **Step 3: Leftover worktrees**: for each `*/.aoe-trash/*` and each path in log lines
  `trashed worktree is no longer registered`, decide: registered with git and inside the 30-day
  retention → leave; not tracked by aoe or git → show the owner `git -C <path> log --oneline
  @{u}.. 2>/dev/null; git -C <path> status --short` and remove only with their OK.
- [ ] **Step 4: Run `dot doctor`** — Expected: no FAIL lines in the aoe section.

---

## Self-review notes

- Spec coverage: Part 1 → Task 1; bootstrap script/steps/scope/wait/timeouts/lock retry → Task 2;
  image bake + hash + doctor stale + caches per session → Task 3; generations, migration, profile
  mount, GC → Task 4; pin, rollback, dangling image → Task 5; e2e tests → Task 6; investigate +
  leftovers → Task 7; README → Tasks 3–5.
