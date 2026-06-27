return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jedi_language_server = {},
        hydra_lsp = {},
        vale_ls = {
          filetypes = { "rst" },
        },
      },
    },
  },

  -- Mason: auto-install servers available in the registry
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "jedi-language-server",
        "vale-ls",
      })
    end,
  },
}
