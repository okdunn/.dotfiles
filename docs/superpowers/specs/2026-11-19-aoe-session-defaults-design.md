# Agent of Empires sessions start ready to work

Small change. Approach approved in conversation on 2026-11-19.

## Why

Every new aoe sandbox session:

- has no git identity, so git asks for name/email. aoe mounts `~/.gitconfig` read-only, but
  identity lives in `~/.gitconfig.local` (written by `git-identity`), which isn't mounted, so
  the `[include]` resolves to nothing.
- throws hook errors on every Bash call: atuin installed `atuin hook claude-code` into the
  host `~/.claude/settings.json`, which the sandbox shares, and atuin isn't in the sandbox image.
- commits onto the aoe session branch (e.g. `berbers`) instead of a feature branch.
- over-comments code. The comments rule in `claude/.claude/CLAUDE.md` does reach sandboxes
  (verified in session `berbers`), so the agent is ignoring it, not missing it.

Usage: one feature per session, many sessions in parallel.

## Goals / non-goals / anti-goals

- Goal: a new session commits as the user, on a feature-named branch, without prompts or hook noise.
- Goal: set up by the installer and checked by `dot doctor`, like the rest of the repo.
- Non-goal: tracking the whole aoe config or the rest of `~/.claude` in the repo.
- Anti-goal: git identity in the tracked repo, or stored in a second place.
- Anti-goal: breaking atuin's Claude Code integration on the host.

## Approaches (git identity)

- **A. Mount `~/.gitconfig.local` into the sandbox via aoe `sandbox.extra_volumes`** (chosen):
  same file the `[include]` already reads; brings signing settings; `git-identity` stays the
  single place to change it.
- B. Forward `GIT_AUTHOR_*`/`GIT_COMMITTER_*` via `sandbox.environment`: no mount, but a
  second copy of the identity and no signing config.
- Rejected: identity in tracked `.gitconfig` (deliberately kept out of the repo).

## Design

1. **Git identity.** Installer ensures the global aoe `config.toml` has a read-only
   `extra_volumes` entry mapping `~/.gitconfig.local` to `/root/.gitconfig.local`, when aoe is
   installed. `dot doctor` checks the entry is present.
2. **Hook errors.** Installer rewrites any `atuin hook claude-code` command in
   `~/.claude/settings.json` to `command -v atuin >/dev/null && atuin hook claude-code || true`
   (jq, alongside `merge_claude_settings`; the existing `*` merge replaces arrays so can't do it).
   `dot doctor` warns if an unguarded atuin hook is back (atuin may re-add it).
3. **Branches.** New `CLAUDE.md` rule: before the first commit in a session, if the current
   branch is the aoe session branch (name doesn't look like `<type>/<slug>`), rename it with
   `git branch -m <type>/<short-slug>` using the Conventional Commit types. Rename, not a new
   branch, so aoe keeps tracking the same worktree and no empty branch is left behind.
4. **Comments.** Tighten the `CLAUDE.md` "Code comments" rule: shorter and absolute ("default
   to no comment"), plus a closing step: before finishing, reread the diff and delete comments
   that narrate or restate code.
5. README: note the aoe mount and the branch rule.

## Left to the builder

- Exact `extra_volumes` syntax and the global config path: not in aoe's docs; confirm against
  the installed aoe (source or `aoe` help) before writing. Edit the TOML without clobbering
  the rest of the file.
- Placement in `install/common.sh` / `install/checks.sh`, following existing `log`/`warn` style.
- Run `dot check` before committing.
