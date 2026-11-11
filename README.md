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

## Day to day: `dot`

- `dot update` — pull the repo, relink, `mise self-update` + `mise upgrade`, update antidote,
  tmux and Neovim plugins (`Lazy sync` rewrites `lazy-lock.json`; commit it to keep the bump),
  refresh tldr pages. A failing step warns and the rest still run.
- `dot doctor` — check this machine: zsh starts cleanly, tools are on PATH, every package is
  linked with no stow conflicts, tmux plugins, bat/btop themes, Claude settings, git identity, tldr.
- `dot check` — lint the repo (shellcheck, `bash -n`/`zsh -n`, stylua). `dot check --cleanroom`
  also runs the Docker install test on Ubuntu 24.04 and Debian 12. Nothing enforces this;
  there is no hosted CI, so run it before pushing.
- `dot edit` / `dot dir` — open the repo in `$EDITOR` / print its path.

Theme: Catppuccin Mocha on true black (OLED) everywhere — only the base is `#000000`;
catppuccin's own surfaces (`#313244`/`#45475a`/`#585b70`) and pastel accents are used for
selections, cursor lines and highlights. nvim, tmux, p10k, fzf, lazygit, bat/delta, git, eza/ls (vivid),
zsh syntax highlighting, btop and wezterm all share it.

Handy keys: `Ctrl-F` project picker (`tp`), `Ctrl-T` fuzzy file, `Alt-C` fuzzy cd,
`Ctrl-R` history (atuin), `Tab` fuzzy completion (fzf-tab), `f` after a failed command (pay-respects).

tmux (prefix `Ctrl-Space`): `f` project picker popup, `r` reload config, `|`/`-` split,
`[` copy mode with vi keys — `v` select, `Ctrl-V` block, `y` copy to the system clipboard (OSC 52,
works over SSH).

git aliases: `git lg` (graph log), `git st`, `git fixup <sha>` (then `git rebase -i` squashes it
automatically), `git amend`, `git undo` (uncommit, keep changes). Global ignores live in
`~/.config/git/ignore`. `git-identity` also offers SSH commit signing when `~/.ssh/id_ed25519.pub` exists.

Claude Code: `~/.claude/CLAUDE.md` (global instructions) is stowed from `claude/`.
`~/.claude/settings.json` is *merged*, not linked, because Claude Code rewrites it itself:
the installer enforces only the keys in `install/claude-settings.json` (no commit/PR attribution)
and keeps everything else on the machine.

Per-machine overrides go in untracked `~/.zshrc.local` and `~/.gitconfig.local`.
The installer asks for your git name/email whenever they're missing (on every run,
including `--stow-only`); run `git-identity` any time to set or change them.

New SSH key: `./init-key.sh`

Test a fresh install in Docker (`dot check --cleanroom` runs this on Ubuntu 24.04 and Debian 12;
pass install flags after the script, e.g. `... cleanroom.sh --langs`):

```
docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash /src/tests/cleanroom.sh
```

Tool versions are `latest` in mise with no lockfile, so a fresh machine gets current releases
and `dot update` moves existing ones forward. Pin a tool in `mise/.config/mise/config.toml`
if a release breaks something.
