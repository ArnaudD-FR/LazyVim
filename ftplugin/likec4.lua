-- Buffer-local settings for LikeC4 files.
--
-- Deliberately does NOT touch LSP config or highlight groups. The upstream
-- likec4.nvim ftplugin calls vim.lsp.config("*", { root_markers = { ".git" } }),
-- which clobbers root resolution for every server in the config, and links 22
-- @lsp.type.* groups -- redundant on Neovim 0.12, which already links the
-- standard semantic token types and resolves @lsp.type.keyword.likec4 to
-- @keyword through @-group dot-hierarchy fallback.
--
-- The language server is registered in lua/plugins/likec4.lua instead.

vim.bo.commentstring = "// %s"
vim.bo.comments = "s1:/*,mb:*,ex:*/,://"

-- LikeC4 identifiers and tags may contain hyphens (#epic-12, tech:api-gateway),
-- so treat them as part of a word for w/*/iw motions.
vim.opt_local.iskeyword:append("-")

vim.b.undo_ftplugin = "setlocal commentstring< comments< iskeyword<"
