# Dotfiles

Debian/Ubuntu only. Managed with GNU Stow; tools via apt + [mise](https://mise.jdx.dev).

## Installation

```
[ -d ~/.dotfiles ] || git clone https://github.com/okdunn/.dotfiles.git ~/.dotfiles; cd ~/.dotfiles && bash install.sh
```

Options:

- `--stow-only` — only (re)link dotfiles, skip package/tool installs
- `--desktop` — also install JetBrains Mono Nerd Font and stow the wezterm config (skip on headless servers)

Per-machine overrides go in untracked `~/.zshrc.local` and `~/.gitconfig.local`
(the installer prompts for git name/email if the latter is missing).

New SSH key: `./init-key.sh`
