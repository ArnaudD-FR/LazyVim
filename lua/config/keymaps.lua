-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Switch between windows with Ctrl+arrows (replaces default Ctrl+hjkl)
-- vim.keymap.set({ "n", "i" }, "<C-Up>", "<C-w>k", { desc = "Go to upper window", remap = true })
-- vim.keymap.set({ "n", "i" }, "<C-Down>", "<C-w>j", { desc = "Go to lower window", remap = true })
-- vim.keymap.set({ "n", "i" }, "<C-Left>", "<C-w>h", { desc = "Go to left window", remap = true })
-- vim.keymap.set({ "n", "i" }, "<C-Right>", "<C-w>l", { desc = "Go to right window", remap = true })
--
-- -- Move to window using the <ctrl> arrow keys
-- vim.keymap.set("t", "<C-Left>", "<C-\\><C-n>:wincmd h<CR>", { desc = "Go to left window" })
-- vim.keymap.set("t", "<C-Down>", "<C-\\><C-n>:wincmd j<CR>", { desc = "Go to lower window" })
-- vim.keymap.set("t", "<C-Up>", "<C-\\><C-n>:wincmd k<CR>", { desc = "Go to upper window" })
-- vim.keymap.set("t", "<C-Right>", "<C-\\><C-n>:wincmd l<CR>", { desc = "Go to right window" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Clear terminal
-- vim.keymap.set("n", "<C-l>", ":set scrollback=1<CR>:set scrollback=100000<cr>", { desc = "Clear terminal" })
vim.keymap.set("t", "<C-l>", "<C-\\><C-n>:set scrollback=1<CR>:set scrollback=100000<cr>i", { desc = "Clear terminal" })
