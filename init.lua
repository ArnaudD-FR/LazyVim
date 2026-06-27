-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.lsp.set_log_level("trace")
vim.cmd("packadd termdebug")
vim.g.termdebug_wide = 1

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.scrollback = 100000
vim.opt.ignorecase = false

vim.wo.relativenumber = false

-- Search visual selection using '*'
vim.keymap.set("v", "*", [[y/\V<C-R>=escape(@",'/\')<CR><CR>]], { desc = "Search visual selection" })

-- Search and replace visual selection
vim.keymap.set("v", "<C-r>", [["hy:%s/<C-r>h//gc<left><left><left>]], { desc = "Search and replace visual selection" })
