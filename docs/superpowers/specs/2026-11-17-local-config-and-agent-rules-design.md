# Local shell config, worktree ignore, and global agent rules

Small change. Approved in conversation on 2026-11-17.

## Why

- Installers append to `~/.zshrc`, which is a stow symlink into this repo, so
  machine/project-specific lines (Codex, FLRT tools) leak into the dotfiles.
- Claude Code worktrees (`<repo>/.claude/worktrees/`) show up as untracked in every repo.
- Claude should write Conventional Commits and stop over-commenting code, everywhere.

## Goals / non-goals

- Goal: one obvious untracked place for per-project shell config; catch future leaks.
- Goal: global rules apply on every machine via the stowed `claude/.claude/CLAUDE.md`.
- Non-goal: tracking the rest of `~/.claude` (skills, hooks, plugins). Separate topic.
- Anti-goal: anything that makes the tracked `.zshrc` depend on files existing.

## Approaches

- **One file (`~/.zshrc.local`)**: already supported, but mixes unrelated projects.
- **`~/.zshrc.d/*.zsh` plus `~/.zshrc.local`** (chosen): one file per project/tool,
  easy to find and delete; `.zshrc.local` keeps working.

## Design

1. `git/.config/git/ignore`: add `**/.claude/worktrees/`.
2. `zsh/.zshrc`: source `~/.zshrc.d/*.zsh(N)` alongside `~/.zshrc.local`, before p10k and
   zoxide (zoxide must stay last).
3. Move the FLRT PATH line to `~/.zshrc.d/flrt.zsh` (untracked); drop the Codex line
   (`~/.local/bin` is already on PATH); revert the uncommitted `.zshrc` diff.
4. Installer creates `~/.zshrc.d/` if missing; README documents it.
5. `dot doctor` warns when `zsh/.zshrc` has uncommitted changes, pointing to `~/.zshrc.d/`.
6. `claude/.claude/CLAUDE.md`: add Conventional Commits rule (keep no-attribution rule)
   and a "Code comments" section: comment only the why, non-obvious constraints, and
   public API docs; no narration or change-log comments.

## Left to the builder

Exact placement within `install.sh` / `install/checks.sh`, following their existing
`log`/`warn` style. Run `dot check` before committing.
