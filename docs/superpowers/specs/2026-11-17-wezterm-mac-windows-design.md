# WezTerm install for Mac/Windows and atuin theme, Catppuccin Mocha OLED

Small change. Approach picked in conversation on 2026-11-17.

## Why

One look everywhere: Catppuccin Mocha with a pure black (`#000000`) background. Every
Linux tool in this repo already uses it, but the terminal window itself is drawn by
WezTerm, which runs on the user's Mac and Windows machines. Those machines are only used
to SSH into Linux servers, so they need just the terminal, its font and its config.

## Goals / non-goals / anti-goals

- Goal: one pasteable command per Mac/Windows machine installs WezTerm, JetBrains Mono
  Nerd Font and the OLED config. Rerunning it updates the config.
- Goal: Linux `--desktop` stows the same `wezterm.lua` again (as before `a82274a`).
- Non-goal: shell, nvim or other tools on Mac/Windows (macOS support stays dropped).
- Goal: atuin's history search uses the same Catppuccin Mocha palette.
- Non-goal: SSH host shortcuts in WezTerm (host names are private; separate idea).
- Anti-goal: silently overwriting a WezTerm config the user wrote on a Mac/Windows machine.

## Approaches

- **A. One-line scripts fetched from GitHub raw, no clone (chosen).** No git needed on
  the machine; updates are manual reruns; the repo must stay public.
- B. Clone the repo on each Mac/Windows machine and link the config. Needs git plus the whole repo for
  one file; Windows links need Developer Mode, so Windows would copy anyway.
- Dropped: WezTerm fetching its config at startup. It breaks offline and adds moving parts.

## Design

1. Restore `wezterm/.config/wezterm/wezterm.lua` exactly as it was at `a82274a^`, and
   restore the `wezterm` package wiring for `--desktop` in `install/debian.sh`,
   `install/checks.sh` and `install/common.sh`. Remove the dangling-link cleanup added in
   `a82274a`, since the link is valid again.
2. `install/wezterm-mac.sh` (bash): requires Homebrew. If brew is missing, it prints the brew.sh
   install command and exits. Otherwise it runs `brew install --cask wezterm
   font-jetbrains-mono-nerd-font`, skipping anything already installed, and downloads
   `wezterm.lua` from `https://raw.githubusercontent.com/okdunn/.dotfiles/main/wezterm/.config/wezterm/wezterm.lua`
   to `~/.config/wezterm/wezterm.lua`.
3. `install/wezterm-windows.ps1` (PowerShell 5.1+): uses `winget` to install WezTerm and the
   JetBrains Mono Nerd Font, skipping anything already installed, then downloads the
   same file to `$HOME\.config\wezterm\wezterm.lua`.
4. Both scripts back up an existing config that differs to `wezterm.lua.bak-<timestamp>`
   before replacing it. An identical config is left untouched.
5. Atuin (added mid-design): add `atuin/.config/atuin/themes/catppuccin-mocha-oled.toml`,
   using Catppuccin Mocha colours with mauve accents to match the other tools. Base it on
   the official catppuccin/atuin palette where possible. Set `[theme] name =
   "catppuccin-mocha-oled"` in `atuin/.config/atuin/config.toml`. The background comes
   from the terminal, which is black. The installed atuin must support themes (18.4+);
   check with `atuin --version`. Add a `dot doctor` line that checks the theme file is linked.
6. README: a "Mac/Windows WezTerm install" section with the two commands. It notes that the
   scripts use the copy on GitHub, so changes must be pushed first.

## Left to the builder

- Exact winget package IDs, and whether WezTerm on Windows reads
  `$HOME\.config\wezterm\wezterm.lua`. Verify both against current docs.
- Log style should match `install/common.sh`.
- `dot check` lints `wezterm-mac.sh` automatically (it has a shebang). PowerShell is linted with
  `pwsh` only if it's available.
- Prerequisite outside this change: pushing to `origin` currently fails (SSH access), and
  the Mac/Windows commands only work after a push.
