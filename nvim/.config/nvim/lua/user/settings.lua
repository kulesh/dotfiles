-- You can read the description of each option in the help page
-- use :help 'option_name' command
-- For example, :help 'hlsearch'

vim.opt.number = true
vim.opt.cursorline = true
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.wrap = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = false
vim.opt.signcolumn = 'yes'
vim.opt.termguicolors = true

-- Text wrapping and display settings
vim.opt.textwidth = 80
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.showbreak = "↪ "  -- Show a symbol at the beginning of wrapped lines
vim.opt.list = true
vim.opt.listchars = "tab:→ ,eol:↲,trail:·,extends:»,precedes:«"  -- Show whitespace
vim.cmd([[highlight ColorColumn ctermbg=238 guibg=#444444]])
