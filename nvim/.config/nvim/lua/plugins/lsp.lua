return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Mason can't install gopls correctly when Go is managed by mise.
        -- Install manually once: go install golang.org/x/tools/gopls@latest
        gopls = { mason = false },
      },
    },
  },
}
