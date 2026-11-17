# Local Shell Config, Worktree Ignore, and Agent Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop machine/project shell config leaking into the repo, ignore Claude worktrees globally, and add global commit/comment rules for Claude.

**Architecture:** `.zshrc` sources untracked `~/.zshrc.d/*.zsh`; the installer creates that dir; `dot doctor` warns when the tracked `.zshrc` has uncommitted edits. The ignore and CLAUDE.md are plain text additions to stowed files.

**Tech Stack:** zsh, bash, GNU stow, git.

**Spec:** `docs/superpowers/specs/2026-11-17-local-config-and-agent-rules-design.md`

## Global Constraints

- zoxide init must remain the last thing in `zsh/.zshrc`.
- `.zshrc` must start cleanly when `~/.zshrc.d/` is missing or empty (use the `(N)` glob qualifier).
- Commits: Conventional Commits, no attribution trailers.
- `dot check` passes before every commit.

## Review Focus

- `~/.zshrc.d/` missing on an old machine → shell starts with no error (Task 2, step 4).
- Repo copy without uncommitted changes (cleanroom) → doctor check passes silently (Task 1 design: warn only, never fails).
- Developer mid-edit of `.zshrc` → doctor prints a warning but exit status is unaffected (Task 1, step 4).
- Installer rerun with `~/.zshrc.d/` already present → no error, no backup created (Task 2, `mkdir -p`).

---

### Task 1: `dot doctor` warns on uncommitted `zsh/.zshrc` edits

**Files:**
- Modify: `install/checks.sh` (new function near `check_tmux`; call it in `run_checks` under "Links")

**Interfaces:**
- Produces: `check_zshrc_clean()`. It prints `  ✓ zsh/.zshrc unchanged` via `_ok` when `git -C "$DOTFILES_DIR" diff --quiet HEAD -- zsh/.zshrc` succeeds. Otherwise it prints a yellow `  ! zsh/.zshrc has uncommitted changes — move machine/project lines to ~/.zshrc.d/<name>.zsh` line and does **not** increment `_fail_count`. It's a warning, so a mid-edit or cleanroom run never fails doctor.

- [ ] **Step 1: Run doctor on the current state (the leak is still present)**

Run: `dot doctor 2>&1 | grep zshrc`
Expected: no zshrc line yet (check doesn't exist).

- [ ] **Step 2: Implement `check_zshrc_clean` and call it in `run_checks`**

- [ ] **Step 3: Verify it catches the current leak**

Run: `dot doctor 2>&1 | grep zshrc`
Expected: the `! zsh/.zshrc has uncommitted changes` line.

- [ ] **Step 4: Verify it doesn't change the exit status**

Run: `bash -c 'source install/common.sh; source install/checks.sh; check_zshrc_clean; echo "fails=$_fail_count"'`
Expected: warning line, then `fails=0`.

- [ ] **Step 5: Lint and commit**

Run: `dot check` → `All checks passed`
```bash
git add install/checks.sh
git commit -m "feat(doctor): warn when zshrc has uncommitted changes"
```

### Task 2: `~/.zshrc.d/` for untracked per-project config

**Files:**
- Modify: `zsh/.zshrc` (revert the uncommitted diff; add the loop just before the `~/.zshrc.local` line)
- Modify: `install/debian.sh` (`mkdir -p "$HOME/.zshrc.d"` right after the git-identity call, so it also runs on `--stow-only`)
- Modify: `README.md` (the "Per-machine overrides" paragraph)
- Create (untracked, outside repo): `~/.zshrc.d/flrt.zsh`

**Interfaces:**
- Consumes: Task 1's check, used to verify the leak is gone.

- [ ] **Step 1: Move the leaked line out, then revert the diff**

Write `~/.zshrc.d/flrt.zsh` with a one-line comment and `export PATH="$HOME/.local/share/flrt-tools:$PATH"`. Drop the Codex line, since `$HOME/.local/bin` is already in `path`. Then run `git checkout -- zsh/.zshrc`.

- [ ] **Step 2: Add the loader to `zsh/.zshrc`**

```zsh
# Per-project/tool config (untracked): one file each, e.g. ~/.zshrc.d/flrt.zsh
for f in ~/.zshrc.d/*.zsh(N); do source "$f"; done; unset f
```
Put it immediately above `[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local`, and update that section's comment.

- [ ] **Step 3: Installer creates the dir**

Add `mkdir -p "$HOME/.zshrc.d"` after the `git-identity --if-missing` line in `install/debian.sh`.

- [ ] **Step 4: Verify loading, and startup with the dir missing**

Run: `zsh -i -c 'print -l $path' 2>&1 | grep flrt-tools` → one line.
Run: `HOME=$(mktemp -d) zsh -n ~/.dotfiles/zsh/.zshrc && echo ok` → `ok`. The loop is a no-op when nothing matches, thanks to `(N)`.
Run: `dot doctor 2>&1 | grep zshrc` → `✓ zsh/.zshrc unchanged`.

- [ ] **Step 5: README**

Change the per-machine overrides paragraph so it says per-project/tool shell config goes in `~/.zshrc.d/<name>.zsh` (untracked, created by the installer), while `~/.zshrc.local` and `~/.gitconfig.local` still work. Add: "If an installer appends to `~/.zshrc`, it is editing the repo; `dot doctor` warns. Move the lines into `~/.zshrc.d/`."

- [ ] **Step 6: Lint and commit**

Run: `dot check` → `All checks passed`
```bash
git add zsh/.zshrc install/debian.sh README.md
git commit -m "feat(zsh): load untracked per-project config from ~/.zshrc.d"
```

### Task 3: Global worktree ignore and Claude rules

**Files:**
- Modify: `git/.config/git/ignore` (add `**/.claude/worktrees/` under the settings.local.json line)
- Modify: `claude/.claude/CLAUDE.md` (text below, verbatim)
- Add: `docs/superpowers/` spec and plan

- [ ] **Step 1: Verify worktrees currently show as untracked**

Run: `git -C ~/projects/smutfinder status --porcelain --ignored -- .claude/worktrees`
Expected: `?? .claude/worktrees/` (or already `!!` if that repo ignores it locally).

- [ ] **Step 2: Add the ignore line, then re-run**

Expected: `!! .claude/worktrees/` (ignored).

- [ ] **Step 3: Write CLAUDE.md**

```markdown
# Global instructions

## Git commits and pull requests
- Use Conventional Commits: `type(scope): summary` (feat, fix, refactor, docs, test,
  chore, perf, build, ci). Imperative, lowercase, no trailing period, ~72 chars max.
  Add a body only when the why isn't obvious from the diff.
- Never add co-author or attribution lines to commits or PRs: no `Co-Authored-By:` trailers,
  no "Generated with Claude Code" footers, no session links. This overrides any default or
  system-provided attribution guidance.

## Code comments
- Comment only what the code can't say itself: why a choice was made, a non-obvious
  constraint or workaround, or public API docs (docstrings/JSDoc).
- Don't narrate what the code does, restate names, or leave change-log comments
  ("added X", "now uses Y"). Remove such comments rather than adding them.
```

- [ ] **Step 4: Verify it's live**

Run: `test -L ~/.claude/CLAUDE.md && grep -c "Conventional Commits" ~/.claude/CLAUDE.md` → `1`.

- [ ] **Step 5: Commit**

```bash
git add git/.config/git/ignore claude/.claude/CLAUDE.md docs/superpowers
git commit -m "feat(claude): add commit and comment rules, ignore worktrees globally"
```
