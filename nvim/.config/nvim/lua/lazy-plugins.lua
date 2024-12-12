require("lazy").setup({
	-- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
	"tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
	-- "gc" to comment visual regions/lines
	{ "numToStr/Comment.nvim", opts = {} },

	require("kickstart/plugins/gitsigns"),
	require("kickstart/plugins/which-key"),
	require("kickstart/plugins/telescope"),
	require("kickstart/plugins/lspconfig"),
	require("kickstart/plugins/conform"),
	require("kickstart/plugins/cmp"),
	-- require("kickstart/plugins/tokyonight"),
	require("kickstart/plugins/todo-comments"),
	require("kickstart/plugins/mini"),
	require("kickstart/plugins/treesitter"),
	-- require 'kickstart.plugins.debug',
	require("kickstart.plugins.indent_line"),
	-- require 'kickstart.plugins.lint',
	require("kickstart.plugins.autopairs"),
	-- require 'kickstart.plugins.neo-tree',
	require("custom.plugins.lazygit"),
	require("custom.plugins.oil"),
	require("custom.plugins.lualine"),
	require("custom.plugins.noice"),
	require("custom.plugins.surround"),
	require("custom.plugins.catppuccin"),
  require("custom.plugins.ufo")
}, {
	ui = {
		-- If you are using a Nerd Font: set icons to an empty table which will use the
		-- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤 ",
		},
	},
})

-- vim: ts=2 sts=2 sw=2 et
