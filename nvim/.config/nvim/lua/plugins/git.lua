return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 400,
        virt_text_pos = "eol",
      },
      current_line_blame_formatter = " <author>, <author_time:%Y-%m-%d> • <summary>",
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_c, {
        function()
          return vim.b.gitsigns_blame_line or ""
        end,
        cond = function()
          return vim.b.gitsigns_blame_line ~= nil
        end,
        color = { fg = "#6e7681" },
      })
    end,
  },
}
