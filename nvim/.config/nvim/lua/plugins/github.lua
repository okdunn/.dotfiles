return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
    },
    cmd = "Octo",
    opts = {
      picker = "fzf-lua",
      enable_builtin = true,
    },
    keys = {
      { "<leader>go", "<cmd>Octo<cr>", desc = "Octo" },
      { "<leader>gpl", "<cmd>Octo pr list<cr>", desc = "Pull Requests" },
      { "<leader>gil", "<cmd>Octo issue list<cr>", desc = "Issues" },
    },
  },
}
