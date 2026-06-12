return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    lazygit = {
      configure = false,
    },
    dashboard = {
      width = 76,
      sections = {
        { text = string.format("NVIM %s", vim.version()), align = "center", padding = 2 },
        {
          text = [[
     _____          ___           ___           ___     
    /  /::\        /__/\         /__/\         /__/\    
   /  /:/\:\       \  \:\        \  \:\        \  \:\   
  /  /:/  \:\       \  \:\        \  \:\        \  \:\  
 /__/:/ \__\:|  ___  \  \:\   _____\__\:\   _____\__\:\ 
 \  \:\ /  /:/ /__/\  \__\:\ /__/::::::::\ /__/::::::::\
  \  \:\  /:/  \  \:\ /  /:/ \  \:\~~\~~\/ \  \:\~~\~~\/
   \  \:\/:/    \  \:\  /:/   \  \:\  ~~~   \  \:\  ~~~ 
    \  \::/      \  \:\/:/     \  \:\        \  \:\     
     \__\/        \  \::/       \  \:\        \  \:\    
                   \__\/         \__\/         \__\/    
        ]],
          align = "center",
        },
        { section = "recent_files", limit = 7, padding = 1 },
      },
    },
  },
}

