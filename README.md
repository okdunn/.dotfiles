# Dotfiles

My shell, editor and terminal setup for Debian and Ubuntu, plus a sandboxed setup for running
several Claude Code agents in parallel. Files are linked into place with GNU Stow; tools come
from apt and [mise](https://mise.jdx.dev).

## Install

```
[ -d ~/.dotfiles ] || git clone https://github.com/okdunn/.dotfiles.git ~/.dotfiles; cd ~/.dotfiles && bash install.sh
```

Options:

| Flag | What it does |
|------|--------------|
| `--stow-only` | Only (re)link the dotfiles; skip installing packages and tools |
| `--desktop` | Also install JetBrains Mono Nerd Font and the WezTerm config (skip on headless servers) |
| `--langs` | Also install go, rust, java, dotnet, ruby and lua. Neovim turns on the matching LazyVim language extras |
| `--reset` | Forget the saved `--desktop` / `--langs` choice |

`--desktop` and `--langs` are remembered in `~/.config/dotfiles/profile`, so later runs
(including `--stow-only` and `dot update`) reuse them. Passing either flag replaces the saved set.

The installer asks for your git name and email whenever they're missing. Run `git-identity` to
set or change them later; it also offers SSH commit signing when `~/.ssh/id_ed25519.pub` exists.
To create a new SSH key, run `./init-key.sh`.

### WezTerm on macOS and Windows

The same WezTerm config, without cloning the repo. Install WezTerm first from
[wezterm.org](https://wezterm.org/installation.html); these scripts don't.

```
# macOS (needs Homebrew)
curl -fsSL https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-mac.sh | bash
```

```
# Windows (PowerShell, needs winget)
irm https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-windows.ps1 | iex
```

Each script installs JetBrains Mono Nerd Font if it's missing, then writes the config to the
file WezTerm loads: `$WEZTERM_CONFIG_FILE` or `~/.config/wezterm/wezterm.lua` if either exists,
otherwise `~/.config/wezterm/wezterm.lua` on macOS and `%USERPROFILE%\.wezterm.lua` on Windows.
An existing, different config is backed up to `*.bak-<timestamp>` first. The scripts download
from GitHub, so push changes to `wezterm.lua` before rerunning them.

## Everyday use: `dot`

- **`dot update`** pulls the repo and relinks it, then updates mise and its tools, antidote, the
  tmux and Neovim plugins, and the tldr pages, and rebuilds the aoe sandbox image. A failing step
  warns and the rest still run. Neovim's `Lazy sync` rewrites `lazy-lock.json`; commit it to keep
  the update.
- **`dot doctor`** checks this machine: zsh starts cleanly, tools are on PATH, every package is
  linked without conflicts, themes and Claude settings are in place, git identity, tldr, and the
  aoe sandboxes.
- **`dot check`** lints the repo (shellcheck, `bash -n` / `zsh -n`, stylua).
  `dot check --cleanroom` also runs a fresh install in Docker on Ubuntu 24.04 and Debian 12.
  There's no hosted CI, so run it before pushing.
- **`dot edit`** opens the repo in `$EDITOR`; **`dot dir`** prints its path.

## Look and keys

Everything uses Catppuccin Mocha on true black for OLED screens: only the background is
`#000000`, and Catppuccin's own surface and accent colours are kept for selections, cursor lines
and highlights. That covers nvim, tmux, p10k, fzf, lazygit, bat and delta, git, eza and ls
(vivid), zsh syntax highlighting, btop, atuin and WezTerm.

| Keys | Action |
|------|--------|
| `Ctrl-F` | Project picker (`tp`) |
| `Ctrl-T` | Fuzzy-find a file |
| `Alt-C` | Fuzzy `cd` |
| `Ctrl-R` | Shell history (atuin) |
| `Tab` | Fuzzy completion (fzf-tab) |
| `f` | Fix the last failed command (pay-respects) |

tmux uses `Ctrl-Space` as its prefix. Then: `f` project picker popup, `r` reload config, `|` and
`-` split, `[` copy mode with vi keys (`v` select, `Ctrl-V` block select, `y` copy to the system
clipboard, which also works over SSH).

Git aliases: `git lg` (graph log), `git st`, `git fixup <sha>` (a later `git rebase -i` squashes it
automatically), `git amend`, and `git undo` (uncommit but keep the changes). Global ignores are in
`~/.config/git/ignore`.

## Machine-specific settings

Nothing machine-specific belongs in this repo. Put it in these untracked files instead:

- `~/.zshrc.local` and `~/.gitconfig.local` for per-machine overrides.
- `~/.zshrc.d/<name>.zsh` for one project's or tool's shell setup (PATH entries, environment
  variables), one file each. The installer creates the folder.

`~/.zshrc` is a link into this repo, so a tool's installer that appends to it is editing the repo.
`dot doctor` warns when that happens; move those lines into `~/.zshrc.d/`.

## Claude Code

- `~/.claude/CLAUDE.md`, the global instructions, is linked from `claude/`. Among other things it
  tells agents in an aoe session to rename the session's branch to `<type>/<slug>` before their
  first commit.
- `~/.claude/settings.json` is merged rather than linked, because Claude Code rewrites it itself.
  The installer enforces only the keys in `install/claude-settings.json` (no attribution in
  commits or PRs) and leaves the rest alone. It also makes atuin's Claude hook skip itself when
  atuin isn't installed, so aoe sandboxes, which share the file, don't print an error on every
  command.

## Agent of Empires (aoe)

aoe is a terminal UI that runs several Claude Code sessions in parallel. Each session gets its own
tmux session, optionally its own git worktree, and a sandbox container. aoe shows each session's
status and has a diff viewer.

### Using it

- `aoe` opens it. `n` starts a new session, `Enter` attaches, `Alt-g` opens lazygit in the
  session's folder, `?` shows help.
- To get back to the list: `Ctrl-Space L` when aoe runs inside tmux, `Ctrl-Space d` outside it.
  Agents keep running either way.
- `aoe add . -w feat/x -b` starts Claude on a new branch in `../<repo>-worktrees/feat-x`.
- The config is `aoe/.config/agent-of-empires/config.toml`. The settings screen (`s`) writes
  straight into it, so commit what you change there.
- The first session asks to install status hooks into `~/.claude/settings.json`. Accept; the
  settings merge keeps them.
- mise installs and updates aoe, so aoe's own update check is off.

### Sandboxes

Each session runs in a rootless Podman container, so files an agent writes into the repo stay
owned by you. Docker is left alone for your own containers.

The image is aoe's base image plus mise, defined in
`aoe/.config/agent-of-empires/sandbox/Dockerfile` and built locally by `aoe-sandbox-build`. The
installer builds it when it's missing, and `dot update` rebuilds it when aoe's base image changes.

Sessions commit as you: the installer mounts `~/.gitconfig.local` read-only into each aoe
profile's own config (`~/.config/agent-of-empires/profiles/<name>/config.toml`, untracked). A
profile's `extra_volumes` replaces the global list, so any extra mounts go in the profile too.
Commit signing doesn't work inside sandboxes, because the key is a path on the host; `dot doctor`
warns when it's on.

### Session setup

Before the agent starts, each new session runs `aoe-bootstrap` inside its container, in this order:

1. **Toolchains:** installs the versions the repo pins (`mise.toml`, `rust-toolchain.toml`,
   `.nvmrc`, …).
2. **Dependencies:** installs from the lockfiles at the repo root and in its workspaces
   (`go.work`, pnpm/npm/yarn/Cargo workspaces). Lockfiles are never rewritten.
3. **Git hooks:** installs husky, lefthook or pre-commit hooks if the repo uses them.

The agent waits for this. Each step stops after 900 seconds (set `AOE_BOOTSTRAP_TIMEOUT` when you
run the script by hand), and a failed or slow step is logged without blocking the session. The
log is `/tmp/aoe-bootstrap.log` inside the container. Package caches live inside each container
(`/var/cache/aoe`), not on the host.

The script is built into the image; `dot doctor` tells you when the image has an older copy and
needs `aoe-sandbox-build`.

### Shared toolchain cache

Installed toolchains are cached in `~/.local/share/aoe-mise` and shared by all sessions. Each
session sees the cache through an overlay: it can read everything, but whatever it writes is
thrown away when it stops, so one session can't tamper with tools the next one runs. That also
means a session's own installs don't stick. To add tools to the cache, run:

```
aoe-sandbox-warm <repo-dir | tool@version>...
```

Given a repo, it reads the repo's version files and the `[tools]` section of its `mise.toml`.

You can warm the cache while sessions are running. The cache is kept as numbered generations
(`gen-1`, `gen-2`, …) with `current` pointing at the newest. A warm copies `current`, installs
into the copy, and switches `current` only if the install worked. Running sessions keep the
generation they started with, new sessions get the newest, and generations no running session
uses are deleted.

The installer and `dot update` create the cache with `aoe-sandbox-warm --init` and add its mount
to each aoe profile's config.

### Git safety

A sandbox can write to the repo, including the main checkout's `.git`. So the git guard
(`zsh/.config/zsh/git-guard.zsh`) pins the git settings a sandbox could use to make git on the
host run its code: hooks, `core.fsmonitor`, the pager, the editor, the ssh command and credential
helpers.

Hooks do still run inside sandboxes. `.git/hooks` is shared by every worktree, and
`aoe-bootstrap` installs husky, lefthook or pre-commit hooks in each new worktree, because they
aren't committed and pnpm's `ignoreScripts` skips husky's own install. Hooks configured with an
absolute `core.hooksPath` don't exist inside the container, so git skips them without a warning.

On the host, once you've checked a repo's hooks, run a single git command with them using
`githooks <git args>`.

The guard doesn't cover git's filter, diff and merge drivers, per-command pagers, git 2.54+ config
hooks (`hook.*`), or anything you run yourself after a session (`pnpm test`, `just check`, …).
Review a session's diff before running its code.

### When a session won't start

If a session fails with `preparing isolated .claude configuration` (and aoe's `debug.log` says
`opening anchored directory component`), its folder in `~/.claude/sandbox-v2/<id>` contains files
you don't own. Sandboxes from before the switch to rootless Podman left them behind. aoe hides the
permission error, and deleting such a session reports success but leaves its folder and worktree
(`<repo>-worktrees/.aoe-trash/<id>`) behind.

To fix it, run `sudo chown -R "$USER": ~/.claude/sandbox-v2`, and the same for any affected
`<repo>-worktrees` folder. Then `aoe sandbox reclaim` lists folders of deleted sessions, and
`aoe sandbox reclaim --delete` removes them.

### Upgrading and rolling back

aoe is pinned in `mise/.config/mise/config.toml`. To upgrade, bump the pin, run
`bash tests/aoe-sandbox-session.sh`, then commit. `dot doctor` fails while the installed version
differs from the pin.

`aoe-sandbox-build` keeps the image it replaces as `aoe-sandbox-dotfiles:previous`. To roll back:

```
podman tag aoe-sandbox-dotfiles:previous aoe-sandbox-dotfiles:latest
```

## Tool versions

Every tool except aoe uses `latest` in mise with no lockfile, so a fresh machine gets current
releases and `dot update` moves existing machines forward. If a release breaks something, pin
that tool in `mise/.config/mise/config.toml`.

## Tests

`dot check` runs the fast checks. These take minutes and need the network, so run them yourself:

- **A fresh install in Docker.** `dot check --cleanroom` runs it on Ubuntu 24.04 and Debian 12.
  To run one by hand, adding install flags after the script (for example `--langs`):

  ```
  docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash /src/tests/cleanroom.sh
  ```

- **`tests/aoe-sandbox-session.sh`** starts real sandboxed sessions. It also warms its test
  toolchains into the real `~/.local/share/aoe-mise` cache.
- **`tests/mise-repo-versions.sh`** checks that repo-pinned versions win over the global defaults.
