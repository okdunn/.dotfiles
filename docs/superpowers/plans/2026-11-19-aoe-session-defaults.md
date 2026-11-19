# aoe Session Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New Agent of Empires sandbox sessions commit as the user, on a feature-named branch, without hook errors, and follow the comments rule.

**Architecture:** Two new bash functions in `install/common.sh` (guard the atuin hook in `~/.claude/settings.json` via jq; add a read-only `~/.gitconfig.local` mount to aoe's global `config.toml`), wired into the installer through one `setup_claude` wrapper, checked by two new `dot doctor` checks. Agent behaviour (branch rename, comments) is `CLAUDE.md` wording.

**Tech Stack:** bash, jq, GNU Stow, plain-text TOML edits (no TOML tool on target machines).

**Spec:** `docs/superpowers/specs/2026-11-19-aoe-session-defaults-design.md`

## Global Constraints

- aoe global config: `${XDG_CONFIG_HOME:-$HOME/.config}/agent-of-empires/config.toml` (Linux; verified in aoe source `get_app_dir_path`).
- `extra_volumes` is a TOML string array under `[sandbox]`, entries `"host:container[:ro]"`, split on `:`; host path is not tilde-expanded, so write an absolute path.
- Mount entry exactly: `"$HOME/.gitconfig.local:/root/.gitconfig.local:ro"` (with `$HOME` expanded at write time).
- A profile's `[sandbox] extra_volumes` replaces the global list (aoe `test_merge_configs_replaces_extra_volumes`).
- Guarded atuin hook command exactly: `command -v atuin >/dev/null && atuin hook claude-code || true`; unguarded is exactly `atuin hook claude-code`.
- Follow existing `log`/`warn`/`_ok`/`_fail`/`_check` styles; doctor-only advisories use the yellow `!` line like `check_zshrc_clean`.
- Commits: Conventional Commits, no attribution lines.
- Never write identity into the repo; never rewrite the user's whole aoe config.

## Review Focus

- `~/.gitconfig.local` missing on the host (non-tty install skipped `git-identity`): do not add the mount (Docker would create a root-owned directory there); warn instead. → Task 1 test `aoe-no-local`.
- aoe config already has `extra_volumes` with other entries: leave the file untouched and warn with the line to add, never rewrite the array. → Task 1 test `aoe-existing-array`.
- Rerunning the installer: both edits are idempotent (no duplicate mount line, no double-guarded hook). → Task 1 tests `aoe-idempotent`, `atuin-idempotent`.
- aoe not installed / no aoe config dir: installer and doctor stay silent and pass. → Task 1 test `aoe-absent`, Task 2 doctor skip.
- `settings.json` with no hooks or invalid JSON: guard is a no-op / warns, never truncates the file. → Task 1 tests `atuin-no-hooks`, `atuin-bad-json`.

---

### Task 1: Installer functions for the atuin hook and aoe mount

**Files:**
- Modify: `install/common.sh` (after `merge_claude_settings`)
- Modify: `install/debian.sh` (both `merge_claude_settings` call sites, lines ~142 and ~156)
- Create: `tests/agent-sessions.sh`
- Modify: `tests/check.sh` (run the new test next to the wezterm tests)

**Interfaces:**
- Produces: `guard_atuin_hook` (no args; edits `$HOME/.claude/settings.json`), `ensure_aoe_gitconfig_mount` (no args; edits `${XDG_CONFIG_HOME:-$HOME/.config}/agent-of-empires/config.toml`), `setup_claude` (calls `merge_claude_settings`, `guard_atuin_hook`, `ensure_aoe_gitconfig_mount` in that order), and the constants `ATUIN_HOOK_GUARDED`, `AOE_CONFIG`, `AOE_GITCONFIG_MOUNT` used by Task 2. All return 0 on every path (warn, don't abort the installer).

- [ ] **Step 1: Write `tests/agent-sessions.sh`** in the style of `tests/wezterm-mac.sh` (`set -uo pipefail`, `setup` makes a temp `HOME`, unsets `XDG_CONFIG_HOME`, `check name cmd...` prints PASS/FAIL, exit 1 if any failed). Each case sources `install/common.sh` in a subshell (`bash -c 'source install/common.sh; <fn>'`) with the temp `HOME`. Cases:
  - `atuin-guard`: settings with a `PreToolUse` Bash hook `"atuin hook claude-code"` and an unrelated `"sh -c foo"` hook → after `guard_atuin_hook`, `jq` finds the guarded string, no exact unguarded string, `sh -c foo` unchanged, `.attribution` unchanged.
  - `atuin-idempotent`: run twice → file identical after the 2nd run (`cmp`).
  - `atuin-no-hooks`: `{}` → file unchanged.
  - `atuin-bad-json`: `not json` → content unchanged, output contains `WARN`.
  - `aoe-absent`: no `~/.config/agent-of-empires` → `ensure_aoe_gitconfig_mount` creates nothing.
  - `aoe-no-local`: aoe dir exists, no `~/.gitconfig.local` → config not created/changed, output contains `WARN`.
  - `aoe-new-file`: aoe dir exists, empty, `.gitconfig.local` exists → `config.toml` contains a `[sandbox]` line and a line `extra_volumes = ["<HOME>/.gitconfig.local:/root/.gitconfig.local:ro"]`.
  - `aoe-existing-sandbox`: config has `[sandbox]\nenabled_by_default = true\n[session]\nx = 1` → `extra_volumes` line is inside `[sandbox]` (appears between `[sandbox]` and `[session]`), other lines intact.
  - `aoe-existing-array`: config has `[sandbox]\nextra_volumes = ["/a:/a"]` → file unchanged, output contains `WARN` and the mount string.
  - `aoe-idempotent`: run `aoe-new-file` setup twice → exactly one occurrence of the mount string.

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/agent-sessions.sh`
Expected: FAIL lines (functions not defined).

- [ ] **Step 3: Implement in `install/common.sh`**
  - `guard_atuin_hook`: skip silently if no settings file or no jq; `jq` `walk` replacing any `.command == "atuin hook claude-code"` with `$ATUIN_HOOK_GUARDED`; write via temp file + `cmp` like `merge_claude_settings`; on jq failure `warn` and leave the file.
  - `ensure_aoe_gitconfig_mount`: return if `${AOE_CONFIG%/*}` dir doesn't exist; return if the mount string already appears in the file; `warn` and return if `~/.gitconfig.local` is missing; if the file already has an `extra_volumes` key, `warn` "add $AOE_GITCONFIG_MOUNT to sandbox.extra_volumes in $AOE_CONFIG" and return; if it has a `[sandbox]` header, insert the `extra_volumes = [...]` line directly after it (awk); otherwise append `\n[sandbox]\nextra_volumes = [...]`. `log` when it changes the file.
  - `setup_claude` wrapper; add a one-line why-comment above the aoe function: aoe mounts `~/.gitconfig` but not the `.local` include that holds the identity.

- [ ] **Step 4: Wire into the installer and lint harness**
  - `install/debian.sh`: replace both `merge_claude_settings` calls with `setup_claude`.
  - `tests/check.sh`: add `step "agent session setup tests"; bash tests/agent-sessions.sh || fail "agent-sessions tests"` after the wezterm steps.

- [ ] **Step 5: Run the tests**

Run: `bash tests/agent-sessions.sh && bash -n install/common.sh install/debian.sh tests/agent-sessions.sh`
Expected: all PASS, no syntax errors. Then `dot check` (or `bash tests/check.sh`) where shellcheck is available: `All checks passed`.

- [ ] **Step 6: Commit**

```bash
git add install/common.sh install/debian.sh tests/agent-sessions.sh tests/check.sh
git commit -m "feat(install): give aoe sandboxes git identity and guard atuin hook"
```

### Task 2: `dot doctor` checks

**Files:**
- Modify: `install/checks.sh` (new functions near `check_claude_settings`; calls in `run_checks` under "Tool config")

**Interfaces:**
- Consumes: `ATUIN_HOOK_GUARDED`, `AOE_CONFIG`, `AOE_GITCONFIG_MOUNT` from Task 1 (checks.sh is sourced after common.sh).

- [ ] **Step 1: Add tests to `tests/agent-sessions.sh`** sourcing both `install/common.sh` and `install/checks.sh`:
  - `doctor-atuin-ok`: settings with guarded hook → `check_atuin_hook` returns 0.
  - `doctor-atuin-bad`: unguarded hook → returns non-zero.
  - `doctor-aoe-skip`: no aoe dir → `check_aoe_mount` output contains `skipped`, does not increment `_fail_count`.
  - `doctor-aoe-ok`/`doctor-aoe-missing`: config with / without the mount → `_ok` vs `_fail` (inspect `_fail_count`).
  - `doctor-aoe-profile`: global has the mount, `profiles/main/config.toml` has `extra_volumes = ["/x:/x"]` → `_fail` mentioning the profile file.

- [ ] **Step 2: Run to see them fail**

Run: `bash tests/agent-sessions.sh`
Expected: the new `doctor-*` cases FAIL.

- [ ] **Step 3: Implement in `install/checks.sh`**
  - `check_atuin_hook`: `jq -e` that no `.command` anywhere equals `"atuin hook claude-code"`; used via `_check "atuin Claude hook guarded (run install.sh --stow-only)" check_atuin_hook`.
  - `check_aoe_mount`: aoe dir absent → print `  - aoe: not configured, skipped` and return; global config lacks the mount → `_fail "aoe mounts ~/.gitconfig.local" "run install.sh --stow-only"`; any `profiles/*/config.toml` under the aoe dir with an `extra_volumes` key lacking the mount → `_fail` naming that file (profiles replace the global list); else `_ok`.

- [ ] **Step 4: Run tests**

Run: `bash tests/agent-sessions.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add install/checks.sh tests/agent-sessions.sh
git commit -m "feat(doctor): check aoe gitconfig mount and atuin hook guard"
```

### Task 3: CLAUDE.md rules and README

**Files:**
- Modify: `claude/.claude/CLAUDE.md`
- Modify: `README.md` (Claude Code paragraph)

- [ ] **Step 1: Replace the "Code comments" section and add a "Branches" section** (after "Git commits and pull requests") with exactly:

```markdown
## Branches
- One feature per branch. Before the first commit, if the current branch isn't named
  `<type>/<short-slug>` (e.g. an Agent of Empires session branch like `berbers`), rename it
  with `git branch -m <type>/<short-slug>`, using the commit types above.
- Never rename `main`, `master`, or a branch that's already pushed; create a new branch instead.

## Code comments
- Default to no comment. Write one only for what the code can't say itself: why a choice was
  made, a non-obvious constraint or workaround, or public API docs (docstrings/JSDoc).
- Never narrate what the code does, restate a name, or leave change-log comments
  ("added X", "now uses Y").
- Before finishing, reread your diff and delete every comment that breaks this rule.
```

Keep the existing commit/attribution bullets unchanged.

- [ ] **Step 2: README** — in the Claude Code paragraph add two sentences: the installer adds a read-only `~/.gitconfig.local` mount to Agent of Empires' sandbox config (so sandboxed sessions commit as you) and guards atuin's Claude hook so sandboxes without atuin don't error; `CLAUDE.md` tells agents to rename aoe session branches to `<type>/<slug>` before committing.

- [ ] **Step 3: Verify**

Run: `bash tests/check.sh` (or `dot check`)
Expected: `All checks passed`.

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/CLAUDE.md README.md
git commit -m "docs(claude): add branch naming rule and tighten comments rule"
```

### Manual check on the host (after merge)

Run `install.sh --stow-only`, then `dot doctor` (both new checks pass), start a new aoe sandbox session, and confirm inside it: `git config user.email` prints the identity, a Bash tool call shows no hook error, and the agent renames the session branch before its first commit.
