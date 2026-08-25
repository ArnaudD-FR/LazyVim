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
      setup = {
        pyright = function()
          Snacks.util.lsp.on({ name = "pyright" }, function(_, client)
            -- Let jedi be the sole source of navigation results. Both servers
            -- answer otherwise and every location is listed twice, and jedi
            -- reaches real source where pyright stops at a typeshed stub.
            local caps = client.server_capabilities
            caps.definitionProvider = false
            caps.declarationProvider = false
            caps.typeDefinitionProvider = false
            caps.referencesProvider = false
          end)
        end,
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
