-- lua/plugins/likec4.lua
--
-- LikeC4 (https://likec4.dev) support: filetype detection + language server.
--
-- Syntax highlighting, indent and buffer options live in the runtimepath
-- overlay at the config root: syntax/likec4.vim, indent/likec4.vim,
-- ftplugin/likec4.lua. Those are hand-written rather than pulled from
-- likec4/likec4.nvim, whose ftdetect only matches *.c4 and whose ftplugin
-- overwrites root_markers globally for every LSP server.

-- Runs while lazy.setup() imports this spec directory from init.lua, i.e.
-- before Neovim reads any file argument, so detection is registered in time.
vim.filetype.add({
  extension = {
    c4 = "likec4",
    likec4 = "likec4",
    ["like-c4"] = "likec4",
  },
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Standalone server: `npm install -g @likec4/lsp`.
        -- Provides diagnostics, completion, go-to-definition, hover, rename
        -- and semantic tokens (the context-aware colours the regex syntax
        -- file cannot produce, e.g. distinguishing a user-declared colour
        -- name from an arbitrary identifier).
        likec4 = {
          -- Absent from Mason's registry, so LazyVim falls through to
          -- vim.lsp.config() + vim.lsp.enable() itself. No lsp/likec4.lua
          -- file and no mason entry are needed.
          mason = false,
          -- Without this guard, every .c4 buffer would try to spawn a missing
          -- binary. LazyVim honours enabled=false by skipping setup entirely.
          enabled = vim.fn.executable("likec4-lsp") == 1,
          cmd = { "likec4-lsp", "--stdio" },
          filetypes = { "likec4" },
          root_markers = {
            "likec4.config.json",
            ".likec4.config.json",
            ".likec4rc",
            ".git",
          },
        },
      },
    },
  },
}
