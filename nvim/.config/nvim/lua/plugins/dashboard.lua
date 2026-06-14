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
          padding = 2,
        },
        { section = "keys", gap = 1, padding = 1 },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
      },
    },
  },
}
