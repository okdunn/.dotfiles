local wezterm = require("wezterm")
local config = wezterm.config_builder()
local mux = wezterm.mux

wezterm.on("gui-startup", function(window)
	local tab, pane, window = mux.spawn_window(cmd or {})
	local gui_window = window:gui_window()
	gui_window:maximize()
end)

config.color_scheme = "Catppuccin Macchiato"
config.hide_tab_bar_if_only_one_tab = true

return config
