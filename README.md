# Dotfiles

Debian/Ubuntu only. Managed with GNU Stow; tools via apt + [mise](https://mise.jdx.dev).

## Installation

```
[ -d ~/.dotfiles ] || git clone https://github.com/okdunn/.dotfiles.git ~/.dotfiles; cd ~/.dotfiles && bash install.sh
```

Options:

- `--stow-only` — only (re)link dotfiles, skip package/tool installs
- `--desktop` — also install JetBrains Mono Nerd Font and stow the wezterm config (skip on headless servers)
- `--langs` — also install language toolchains: go, rust, java, dotnet, ruby, lua (`mise-langs` package).
  Neovim turns on the matching LazyVim language extras automatically.
- `--reset` — forget the saved `--desktop`/`--langs` choice

`--desktop`/`--langs` are saved to `~/.config/dotfiles/profile`; later runs that pass neither
(including `--stow-only` and `dot update`) reuse them. Passing either replaces the saved set.

### Mac/Windows WezTerm install

The same WezTerm config (Catppuccin Mocha on OLED black) for macOS and Windows, no clone needed:

```
# macOS (needs Homebrew)
curl -fsSL https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-mac.sh | bash
```

```
# Windows (PowerShell, needs winget)
irm https://raw.githubusercontent.com/okdunn/.dotfiles/main/install/wezterm-windows.ps1 | iex
```

Install WezTerm itself first from [wezterm.org](https://wezterm.org/installation.html); the scripts don't
install it. Each installs JetBrains Mono Nerd Font if it's missing (and warns if WezTerm is), then writes the config
to the file WezTerm will load: an existing `$WEZTERM_CONFIG_FILE` or `~/.config/wezterm/wezterm.lua`
if there is one, otherwise `~/.config/wezterm/wezterm.lua` on macOS and `%USERPROFILE%\.wezterm.lua`
on Windows. A different
existing config is backed up to `*.bak-<timestamp>` first. Rerun to pick up config changes. The
scripts fetch from GitHub, so push changes to `wezterm.lua` before rerunning them.

## Day to day: `dot`

- `dot update` — pull the repo, relink, `mise self-update` + `mise upgrade`, update antidote,
  tmux and Neovim plugins (`Lazy sync` rewrites `lazy-lock.json`; commit it to keep the bump),
  refresh tldr pages, rebuild the aoe sandbox image. A failing step warns and the rest still run.
- `dot doctor` — check this machine: zsh starts cleanly, tools are on PATH, every package is
  linked with no stow conflicts, tmux plugins, bat/btop themes, Claude settings, git identity, tldr,
  aoe sandboxes (rootless Podman works, image built).
- `dot check` — lint the repo (shellcheck, `bash -n`/`zsh -n`, stylua). `dot check --cleanroom`
  also runs the Docker install test on Ubuntu 24.04 and Debian 12. Nothing enforces this;
  there is no hosted CI, so run it before pushing.
- `dot edit` / `dot dir` — open the repo in `$EDITOR` / print its path.

Theme: Catppuccin Mocha on true black (OLED) everywhere — only the base is `#000000`;
catppuccin's own surfaces (`#313244`/`#45475a`/`#585b70`) and pastel accents are used for
selections, cursor lines and highlights. nvim, tmux, p10k, fzf, lazygit, bat/delta, git, eza/ls (vivid),
zsh syntax highlighting, btop, atuin and wezterm all share it.

Handy keys: `Ctrl-F` project picker (`tp`), `Ctrl-T` fuzzy file, `Alt-C` fuzzy cd,
`Ctrl-R` history (atuin), `Tab` fuzzy completion (fzf-tab), `f` after a failed command (pay-respects).

tmux (prefix `Ctrl-Space`): `f` project picker popup, `r` reload config, `|`/`-` split,
`[` copy mode with vi keys — `v` select, `Ctrl-V` block, `y` copy to the system clipboard (OSC 52,
works over SSH).

git aliases: `git lg` (graph log), `git st`, `git fixup <sha>` (then `git rebase -i` squashes it
automatically), `git amend`, `git undo` (uncommit, keep changes). Global ignores live in
`~/.config/git/ignore`. `git-identity` also offers SSH commit signing when `~/.ssh/id_ed25519.pub` exists.

Claude Code: `~/.claude/CLAUDE.md` (global instructions) is stowed from `claude/`.
Tracked skills in `claude/.claude/skills/` are linked file by file, so other skills in
`~/.claude/skills` stay local to the machine.
`~/.claude/settings.json` is *merged*, not linked, because Claude Code rewrites it itself:
the installer enforces only the keys in `install/claude-settings.json` (no commit/PR attribution)
and keeps everything else on the machine.
It also guards atuin's Claude hook (`command -v atuin && ...`) so Agent of Empires sandboxes,
which share that file but don't have atuin, don't error on every Bash call, and adds a read-only
`~/.gitconfig.local` mount to each aoe profile's untracked config
(`~/.config/agent-of-empires/profiles/<name>/config.toml`) so sandboxed sessions commit as you.
A profile's `extra_volumes` replaces the global one, so put extra mounts there too.
`CLAUDE.md` tells agents in an aoe session to rename the session branch to `<type>/<slug>`
before their first commit. Commit signing doesn't work inside sandboxes (the key
is a host path); `dot doctor` warns when it's on.

Agent of Empires (`aoe`): a TUI that runs Claude Code sessions in parallel, each in its own
tmux session (optionally its own git worktree), with status detection and a diff viewer.
`aoe` opens it; `n` new session, `Enter` attach, `Alt-g` lazygit in the session's dir, `?` help.
Back to the list: `Ctrl-Space L` when aoe runs inside tmux (attaching switches your client),
`Ctrl-Space d` outside it. Agents keep running either way.
`aoe add . -w feat/x -b` starts Claude on a new branch in `../<repo>-worktrees/feat-x`.
Config is `aoe/.config/agent-of-empires/config.toml` (Claude by default, Mocha OLED theme);
the settings screen (`s`) writes through to it, so commit what you change there. mise
installs and upgrades it, so aoe's own update check is off. The first session asks once to
install status hooks into `~/.claude/settings.json`; accept, the settings merge keeps them.

aoe sandboxes (on by default) run each session in a rootless Podman container, so files an
agent writes into the repo stay owned by you; Docker is left alone for your own containers.
The image is aoe's base plus mise (`aoe/.config/agent-of-empires/sandbox/Dockerfile`), built
locally by `aoe-sandbox-build`; the installer builds it when missing and `dot update` rebuilds it
for aoe's newer base image. When a session starts, the `on_launch` hook runs `aoe-bootstrap`
(baked into the image; `dot doctor` flags an image built from an older copy) inside it. It
installs the repo's pinned toolchains (`mise.toml`, `rust-toolchain.toml`, `.nvmrc`, …) so they're
on PATH, then the dependencies at the repo root and in `go.work`/workspace members, then the
husky, lefthook or pre-commit hooks. Each step is limited to 900 s (`AOE_BOOTSTRAP_TIMEOUT`),
the agent waits for the script, and its log is `/tmp/aoe-bootstrap.log` in the container.
Package caches sit on the container's own filesystem (`/var/cache/aoe`), not a host mount.
Toolchains come from a cache shared by all sessions (`~/.local/share/aoe-mise`), mounted as an
overlay: sessions read it, but what they write is discarded, so one session can't tamper with
what the next one runs. That also means a session's own installs aren't kept: add them with
`aoe-sandbox-warm <repo-dir | tool@version>...` (it reads a repo's version files and its
`mise.toml` `[tools]`, never its other mise config). The cache is kept in generations
(`gen-1`, `gen-2`, …) with `current` pointing at the newest: a warm installs into a copy of
`current` and switches it once the install succeeds, so it can run while sessions do. Each
session keeps the generation it started with; new ones get the new one, and the warm deletes
generations no running sandbox uses. The installer runs `aoe-sandbox-warm --init` to create
`gen-1`, moving in the old `aoe-mise` volume if there is one; the mount itself goes in each aoe
profile's config, next to the git identity mount.
The container can write the repo, including the main checkout's `.git`, so the git guard
(`zsh/.config/zsh/git-guard.zsh`) pins the settings that would make git on the host run
something a sandbox planted: hooks, `core.fsmonitor`, pager, editor, ssh command, credential
helpers. Hooks still run inside sandboxes: `.git/hooks` is shared by every worktree, and for repos
that use husky, lefthook or pre-commit, `aoe-bootstrap` installs their generated hooks in each new
worktree (they're not committed, and pnpm's `ignoreScripts` skips husky's `prepare`), which also
sets husky's `core.hooksPath` relative. An absolute `core.hooksPath` doesn't exist in the
container, so git skips those hooks silently.
On the host, run one command with the repo's own hooks via `githooks <git args>` once you've
checked them. Not covered: filter/diff/merge
drivers, per-command pagers and git 2.54+ config hooks (`hook.*`), and anything you run yourself
(`pnpm test`, `just check`) after a session. Review a session's diff before running its code.
`tests/aoe-sandbox-session.sh` (a real sandboxed worktree session) and
`tests/mise-repo-versions.sh` need the network and take minutes, so `dot check` doesn't run them.
A session that won't start with `preparing isolated .claude configuration` (debug.log:
`opening anchored directory component`) has files in its agent store `~/.claude/sandbox-v2/<id>`
that you don't own, left by sandboxes from before the switch to rootless Podman. aoe hides the
`EACCES`, and deleting such a session reports success but leaves the store and its worktree
(`<repo>-worktrees/.aoe-trash/<id>`). Fix with `sudo chown -R "$USER": ~/.claude/sandbox-v2`, then
`aoe sandbox reclaim` lists stores of deleted sessions (`--delete` removes them).

Per-machine overrides go in untracked `~/.zshrc.local` and `~/.gitconfig.local`.
Per-project/tool shell config (PATHs, env vars) goes in untracked `~/.zshrc.d/<name>.zsh`,
one file each (the installer creates the folder). `~/.zshrc` is a link into this repo, so an
installer that appends to it is editing the repo: `dot doctor` warns, and the lines belong in `~/.zshrc.d/`.
The installer asks for your git name/email whenever they're missing (on every run,
including `--stow-only`); run `git-identity` any time to set or change them.

New SSH key: `./init-key.sh`

Test a fresh install in Docker (`dot check --cleanroom` runs this on Ubuntu 24.04 and Debian 12;
pass install flags after the script, e.g. `... cleanroom.sh --langs`):

```
docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash /src/tests/cleanroom.sh
```

Tool versions are `latest` in mise with no lockfile, so a fresh machine gets current releases
and `dot update` moves existing ones forward, except aoe, which is pinned. Pin a tool in
`mise/.config/mise/config.toml` if a release breaks something.

To upgrade aoe, bump its pin there, run `bash tests/aoe-sandbox-session.sh`, then commit; `dot check`
fails while the installed version differs from the pin. `aoe-sandbox-build` keeps the image it
replaces as `aoe-sandbox-dotfiles:previous`; roll back with
`podman tag aoe-sandbox-dotfiles:previous aoe-sandbox-dotfiles:latest`.
