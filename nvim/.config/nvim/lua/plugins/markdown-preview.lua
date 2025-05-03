
-- https://github.com/iamcco/markdown-preview.nvim

local Plugin = {
  'iamcco/markdown-preview.nvim',
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = { "markdown" },
  build ="cd app && npm install",
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
  config = function()
    -- Ensure the plugin's commands are registered
    vim.cmd([[
      command! -nargs=0 MarkdownPreview call mkdp#util#open_preview_page()
      command! -nargs=0 MarkdownPreviewStop call mkdp#util#stop_preview()
      command! -nargs=0 MarkdownPreviewToggle call mkdp#util#toggle_preview()
    ]])
  end
}

return Plugin
