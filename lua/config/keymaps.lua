-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- Move to window using the <ctrl> arrow keys
map("n", "<C-Left>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-Down>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-Up>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-Right>", "<C-w>l", { desc = "Go to right window" })

-- Move to window using the <ctrl> arrow keys
map("t", "<C-Left>", "<C-\\><C-n>:wincmd h<CR>", { desc = "Go to left window" })
map("t", "<C-Down>", "<C-\\><C-n>:wincmd j<CR>", { desc = "Go to lower window" })
map("t", "<C-Up>", "<C-\\><C-n>:wincmd k<CR>", { desc = "Go to upper window" })
map("t", "<C-Right>", "<C-\\><C-n>:wincmd l<CR>", { desc = "Go to right window" })

-- Clear terminal
map("n", "<C-l>", ":set scrollback=1<CR>:set scrollback=100000<cr>", { desc = "Clear terminal" })
map("t", "<C-l>", "<C-\\><C-n>:set scrollback=1<CR>:set scrollback=100000<cr>i", { desc = "Clear terminal" })
