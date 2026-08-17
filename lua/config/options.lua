-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Set the terminal/window title to the name of the directory Neovim was opened in
-- (re-evaluated on :cd, so it tracks the current working directory)
vim.opt.title = true
vim.opt.titlestring = '%{fnamemodify(getcwd(), ":t")}'
