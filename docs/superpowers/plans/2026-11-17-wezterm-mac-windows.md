# WezTerm Mac/Windows Install and Atuin Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring back the Catppuccin Mocha OLED WezTerm config for Linux `--desktop` and add one-line installers for Mac and Windows. Theme atuin to match.

**Architecture:** `wezterm.lua` returns as a stow package. Two standalone scripts download that same file from GitHub raw and install WezTerm and the font only when they're missing. Atuin gets a theme file in its stowed config dir.

**Tech Stack:** bash, PowerShell 5.1+, Homebrew casks, winget, GNU stow, atuin 18.24.

**Spec:** `docs/superpowers/specs/2026-11-17-wezterm-mac-windows-design.md`

## Global Constraints

- Raw URL base: `https://raw.githubusercontent.com/okdunn/.dotfiles/main/`
- Mac: `brew install --cask wezterm font-jetbrains-mono-nerd-font`. WezTerm counts as installed if `brew list --cask wezterm` succeeds or `/Applications/WezTerm.app` exists.
- Windows: winget IDs `wez.wezterm` and `DEVCOM.JetBrainsMonoNerdFont`. Config path `$HOME\.wezterm.lua` (see Ruling below).
- Mac config path: `~/.config/wezterm/wezterm.lua`.
- A different existing config is backed up to `<config>.bak-<YYYYmmdd-HHMMSS>`. An identical one is left untouched, with no backup.
- No "SSH client" wording anywhere. The README section is titled "Mac/Windows WezTerm install".
- Conventional Commits, no trailers. `dot check` passes before each commit.

**Ruling (plan-time):** the Windows config goes to `$HOME\.wezterm.lua` rather than `$HOME\.config\wezterm\wezterm.lua`. WezTerm's docs name `%USERPROFILE%/.wezterm.lua` explicitly for Windows, but they don't clearly confirm the `.config` path there (https://wezterm.org/config/files.html). Cost if wrong: none, since the fallback path is always read.

## Review Focus

- WezTerm installed from the website (not brew) on the Mac → no reinstall attempt (Task 2, test `app-present`).
- An existing hand-written config → backed up, never lost (Task 2, test `backup`).
- Rerun with the config unchanged → no new backup file (Task 2, test `idempotent`).
- Homebrew missing → clear message and non-zero exit, nothing half-installed (Task 2, test `no-brew`).
- Download failure (offline, or the repo not pushed) → the existing config is left intact. Download to a temp file and move it into place only on success (Task 2, test `bad-url`).

---

### Task 1: Restore the WezTerm package for Linux `--desktop`

**Files:** whatever `git revert a82274a` touches (wezterm.lua, install/*.sh, README, tests/check.sh, nvim comment).

- [ ] **Step 1:** `dot doctor` currently expects no wezterm link: `bash -c 'source install/common.sh; source install/checks.sh; printf "%s\n" --desktop > /tmp/p; PROFILE_FILE=/tmp/p expected_packages' | grep -c wezterm` → `0`.
- [ ] **Step 2:** `git revert --no-edit a82274a`, then amend the message to `feat(wezterm): restore catppuccin mocha oled config for --desktop`.
- [ ] **Step 3:** Re-run step 1's command → `1`. Run `git show HEAD:wezterm/.config/wezterm/wezterm.lua | grep -c '#000000'` → `2`. Run `grep -c 'wez=' install/debian.sh` → `0` (cleanup gone).
- [ ] **Step 4:** `dot check` → `All checks passed`. The revert commit is the commit for this task.

### Task 2: `install/wezterm-mac.sh`

**Files:**
- Create: `install/wezterm-mac.sh` (bash, `#!/usr/bin/env bash`, `set -euo pipefail`, executable)
- Create: `tests/wezterm-mac.sh`. The test fakes `brew` on PATH and points HOME at a temp dir.

**Interfaces:**
- Env overrides, for tests only: `WEZTERM_LUA_URL` (default: the raw URL base + `wezterm/.config/wezterm/wezterm.lua`) and `WEZTERM_APP` (default `/Applications/WezTerm.app`).
- Fake `brew`: a script that appends `$*` to `$BREW_LOG`. `brew list --cask <x>` exits 0 only if `<x>` is listed in `$BREW_INSTALLED`.

- [ ] **Step 1: Write `tests/wezterm-mac.sh`.** Each case gets a fresh temp HOME and `WEZTERM_LUA_URL=file://$PWD/wezterm/.config/wezterm/wezterm.lua`. It prints `PASS <name>` or `FAIL <name>` and exits non-zero on any failure.
  - `fresh`: nothing installed → BREW_LOG contains `install --cask wezterm` and `install --cask font-jetbrains-mono-nerd-font`; the config matches the repo file.
  - `app-present`: `WEZTERM_APP` is an existing temp dir → BREW_LOG has no `install --cask wezterm`, but still installs the font.
  - `installed`: `BREW_INSTALLED="wezterm font-jetbrains-mono-nerd-font"` → no `install` lines.
  - `backup`: an existing config `-- mine` → exactly one `wezterm.lua.bak-*` containing `-- mine`; the config matches the repo.
  - `idempotent`: run twice → no `.bak-*` files.
  - `no-brew`: PATH without brew → exit non-zero, output contains `brew.sh`, no config written.
  - `bad-url`: `WEZTERM_LUA_URL=file:///nonexistent`, existing config `-- mine` → exit non-zero, config still `-- mine`, no `.bak-*`.
- [ ] **Step 2:** `bash tests/wezterm-mac.sh` → fails (script missing).
- [ ] **Step 3:** Implement `install/wezterm-mac.sh`. Order: brew check → install WezTerm if missing → install the font if missing → `curl -fsSL` to a `mktemp` file → `cmp -s` with the existing config: identical means done; otherwise back up the existing file if any, then `mv` into place. Use `==>` log lines like `install/common.sh`, but inline them, since the script runs standalone via `curl | bash`.
- [ ] **Step 4:** `bash tests/wezterm-mac.sh` → all 7 `PASS`.
- [ ] **Step 5:** `dot check` → passes. It picks up both new files via their shebangs. Commit `feat(wezterm): add mac installer` with both files.

### Task 3: `install/wezterm-windows.ps1`

**Files:** Create `install/wezterm-windows.ps1`.

Same flow as Task 2. WezTerm counts as installed if `winget list -e --id wez.wezterm` exits 0 or `wezterm` is on PATH. The font counts as installed if `winget list -e --id DEVCOM.JetBrainsMonoNerdFont` exits 0. Installs use `winget install -e --id <id> --accept-package-agreements --accept-source-agreements`. The download goes to `[IO.Path]::GetTempFileName()` with `Invoke-WebRequest -UseBasicParsing`, compared with `Get-FileHash`. A different config is backed up as `.wezterm.lua.bak-<stamp>`, then the new one is moved into place. If winget is missing, the script prints "install App Installer from the Microsoft Store" and exits 1. `$ErrorActionPreference = 'Stop'`. Honour `$env:WEZTERM_LUA_URL` like Task 2.

- [ ] **Step 1:** There's no PowerShell runtime here (`pwsh` isn't installed). Verify with `mise exec pwsh@latest -- pwsh -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -Raw install/wezterm-windows.ps1)); "parse-ok"'` → `parse-ok`. If mise can't provide pwsh, ledger a Ruling and mark it untested on Windows.
- [ ] **Step 2:** Commit `feat(wezterm): add windows installer`.

### Task 4: Atuin theme

**Files:**
- Create: `atuin/.config/atuin/themes/catppuccin-mocha-oled.toml`. Copy upstream `catppuccin/atuin` `themes/mocha/catppuccin-mocha-mauve.toml` exactly (AlertInfo `#a6e3a1`, AlertWarn `#fab387`, AlertError `#f38ba8`, Annotation `#cba6f7`, Base `#cdd6f4`, Guidance `#9399b2`, Important `#f38ba8`, Title `#cba6f7`), with `name = "catppuccin-mocha-oled"` and a one-line source comment.
- Modify: `atuin/.config/atuin/config.toml`. Uncomment `[theme]` and set `name = "catppuccin-mocha-oled"`.
- Modify: `install/checks.sh`. Add `_check "atuin theme linked" test -L "$HOME/.config/atuin/themes/catppuccin-mocha-oled.toml"`.

- [ ] **Step 1:** `dot doctor | grep "atuin theme"` → no line yet.
- [ ] **Step 2:** Add the files and edits, then `bash install.sh --stow-only </dev/null`.
- [ ] **Step 3:** `dot doctor | grep "atuin theme"` → `✓`. `python3 -c 'import tomllib,sys;[tomllib.load(open(f,"rb")) for f in sys.argv[1:]]' atuin/.config/atuin/config.toml atuin/.config/atuin/themes/catppuccin-mocha-oled.toml && echo toml-ok` → `toml-ok`. `atuin search --limit 1 >/dev/null && echo atuin-ok` → `atuin-ok`, with no theme warning on stderr.
- [ ] **Step 4:** `dot check` → passes. Commit `feat(atuin): catppuccin mocha theme`.

### Task 5: README

- [ ] **Step 1:** Add a "Mac/Windows WezTerm install" section with the two one-liners (`curl -fsSL <base>install/wezterm-mac.sh | bash` and `irm <base>install/wezterm-windows.ps1 | iex`). It notes that they install WezTerm and the font only if missing, back up a different existing config, and fetch from GitHub, so changes must be pushed first. Add atuin to the theme list sentence.
- [ ] **Step 2:** `grep -ci "ssh client" README.md` → `0`. Commit `docs: wezterm install for mac and windows`, together with the spec and plan files.
