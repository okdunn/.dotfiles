local wezterm = require("wezterm")
local config = wezterm.config_builder()
local mux = wezterm.mux

wezterm.on("gui-startup", function(cmd)
	local _, _, window = mux.spawn_window(cmd or {})
	local gui_window = window:gui_window()
	gui_window:maximize()
end)

-- Catppuccin Mocha accents on a true-black (OLED) background,
-- matching nvim/tmux/lazygit/fzf/p10k in these dotfiles
local oled = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]
oled.background = "#000000"
oled.cursor_border = "#f5e0dc"
oled.selection_bg = "#45475a"
oled.tab_bar = {
	background = "#000000",
	active_tab = { bg_color = "#cba6f7", fg_color = "#000000" },
	inactive_tab = { bg_color = "#313244", fg_color = "#7f849c" },
	inactive_tab_hover = { bg_color = "#45475a", fg_color = "#cdd6f4" },
	new_tab = { bg_color = "#000000", fg_color = "#7f849c" },
	new_tab_hover = { bg_color = "#45475a", fg_color = "#cdd6f4" },
}
config.color_schemes = { ["Catppuccin Mocha OLED"] = oled }
config.color_scheme = "Catppuccin Mocha OLED"

config.font = wezterm.font("JetBrainsMono Nerd Font")
config.hide_tab_bar_if_only_one_tab = true

return config
