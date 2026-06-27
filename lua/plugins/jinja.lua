-- lua/plugins/jinja.lua
return {
  -- Jinja syntax highlighting
  { "HiPhish/jinja.vim" },

  -- Mason: auto-install jinja-lsp binary
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "jinja-lsp" })
    end,
  },

  -- LSP: register jinja_lsp with nvim-lspconfig
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jinja_lsp = {
          filetypes = { "jinja", "j2", "jinja2", "html", "cpp.jinja", "html.jinja", "python.jinja" },
        },
      },
    },
  },
}
