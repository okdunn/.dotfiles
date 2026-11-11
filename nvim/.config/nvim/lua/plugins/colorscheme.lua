-- Catppuccin Mocha accents on a true-black (OLED) background.
-- Same palette as tmux, lazygit, fzf, p10k and wezterm in these dotfiles.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      color_overrides = {
        mocha = {
          base = "#000000",
          mantle = "#000000",
          crust = "#000000",
          surface0 = "#1a1a1a",
          surface1 = "#262626",
          surface2 = "#333333",
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      -- "catppuccin-mocha", not "catppuccin": nvim >= 0.12 ships a built-in catppuccin.vim
      -- that shadows the plugin (colors/*.vim wins over *.lua) and ignores these overrides
      colorscheme = "catppuccin-mocha",
    },
  },
}
