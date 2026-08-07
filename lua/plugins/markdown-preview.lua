return {
  "iamcco/markdown-preview.nvim",
  init = function()
    -- Reuse a single preview window across markdown buffers and refresh it
    -- to whichever markdown buffer becomes current, instead of opening a new
    -- preview per buffer.
    vim.g.mkdp_combine_preview = 1
    vim.g.mkdp_combine_preview_auto_refresh = 1
    -- Required for combine mode: don't close the preview when switching buffers.
    vim.g.mkdp_auto_close = 0
  end,
}
