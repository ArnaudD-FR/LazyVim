-- lua/plugins/review.lua
--
-- code-review.nvim: annotate lines/ranges with review comments, saved to
-- .code-review.md in the project root. Claude Code's /review skill
-- (installed separately via the plugin's skills/install_skill.sh) reads that
-- file, applies each comment, and clears it.
--
-- Default keymaps: <leader>ra add comment, <leader>rd delete, <leader>rl list
-- (quickfix), <leader>rs save, <leader>rx clear.

return {
  { "scristobal/code-review.nvim", opts = {} },
}
