local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local function get_mise_langs()
  local config_path = vim.fn.expand("~/.config/mise/config.toml")
  local f = io.open(config_path, "r")
  if not f then return {} end
  local in_tools = false
  local langs = {}
  for line in f:lines() do
    if line:match("^%[tools%]") then
      in_tools = true
    elseif line:match("^%[") then
      in_tools = false
    elseif in_tools then
      local lang = line:match("^(%w+)%s*=")
      if lang then langs[lang] = true end
    end
  end
  f:close()
  return langs
end

local extras_map = {
  node = "lazyvim.plugins.extras.lang.typescript",
  go = "lazyvim.plugins.extras.lang.go",
  rust = "lazyvim.plugins.extras.lang.rust",
  python = "lazyvim.plugins.extras.lang.python",
  java = "lazyvim.plugins.extras.lang.java",
  ruby = "lazyvim.plugins.extras.lang.ruby",
  dotnet = "lazyvim.plugins.extras.lang.dotnet",
}

local langs = get_mise_langs()
local spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
}
for lang, extra in pairs(extras_map) do
  if langs[lang] then
    table.insert(spec, { import = extra })
  end
end
table.insert(spec, { import = "plugins" })

require("lazy").setup({
  spec = spec,
  defaults = {
    lazy = false,
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
