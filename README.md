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

Theme: Catppuccin Mocha accents on true black (OLED) everywhere — nvim, tmux, p10k, fzf,
lazygit, bat/delta and wezterm share one palette (`#000000` base, `#1a1a1a`/`#262626`/`#333333` surfaces).

Handy keys: `Ctrl-F` project picker (`tp`), `Ctrl-T` fuzzy file, `Alt-C` fuzzy cd,
`Ctrl-R` history (atuin), `Tab` fuzzy completion (fzf-tab), `f` after a failed command (pay-respects).

Claude Code: `~/.claude/CLAUDE.md` (global instructions) is stowed from `claude/`.
`~/.claude/settings.json` is *merged*, not linked, because Claude Code rewrites it itself:
the installer enforces only the keys in `install/claude-settings.json` (no commit/PR attribution)
and keeps everything else on the machine.

Per-machine overrides go in untracked `~/.zshrc.local` and `~/.gitconfig.local`.
The installer asks for your git name/email whenever they're missing (on every run,
including `--stow-only`); run `git-identity` any time to set or change them.

New SSH key: `./init-key.sh`

Test a fresh install in Docker (CI runs this on Ubuntu 24.04 and Debian 12):

```
docker run --rm -v "$PWD:/src:ro" ubuntu:24.04 bash /src/tests/cleanroom.sh
```
