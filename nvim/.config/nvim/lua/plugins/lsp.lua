local Plugin = {
  'neovim/nvim-lspconfig',
  dependencies = {
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'stevearc/conform.nvim',
  },
}

function Plugin.config()
  -- Setup Mason first
  require('mason').setup({
    ui = {
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗"
      }
    }
  })

  -- LSP capabilities for autocompletion
  local lsp_capabilities = vim.lsp.protocol.make_client_capabilities()

  -- Setup mason-lspconfig with handlers
  require('mason-lspconfig').setup({
    ensure_installed = {
      'lua_ls',        -- Lua (vim, vimdoc)
      'pyright',       -- Python
      'ruby_lsp',      -- Ruby
      'ts_ls',         -- JavaScript, TypeScript
      'bashls',        -- Bash
      'clangd',        -- C
      'html',          -- HTML
      'jsonls',        -- JSON, JSONC
    },
    automatic_installation = true,
    handlers = {
      -- Default handler for all servers
      function(server_name)
        require('lspconfig')[server_name].setup({
          capabilities = lsp_capabilities,
        })
      end,

      -- Special config for lua_ls
      ['lua_ls'] = function()
        require('lspconfig').lua_ls.setup({
          capabilities = lsp_capabilities,
          settings = {
            Lua = {
              runtime = {
                version = 'LuaJIT'
              },
              diagnostics = {
                globals = { 'vim' },
              },
              workspace = {
                library = {
                  vim.env.VIMRUNTIME,
                }
              }
            }
          }
        })
      end,
    },
  })

  -- Setup formatters with conform.nvim
  require('conform').setup({
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'isort', 'black' },
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },
      json = { 'prettier' },
      jsonc = { 'prettier' },
      html = { 'prettier' },
      css = { 'prettier' },
      markdown = { 'prettier' },
      ruby = { 'rubocop' },
      bash = { 'shfmt' },
      sh = { 'shfmt' },
    },
    
    -- Format on save
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  })

  -- Auto-install formatters
  local mason_registry = require('mason-registry')
  local formatters = {
    'stylua',
    'black',
    'isort',
    'prettier',
    'rubocop',
    'shfmt',
  }

  for _, formatter in ipairs(formatters) do
    local package = mason_registry.get_package(formatter)
    if not package:is_installed() then
      package:install()
    end
  end

  -- Keymaps (set when LSP attaches to buffer)
  vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'LSP actions',
    callback = function(event)
      local opts = { buffer = event.buf }

      vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
      vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
      vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
      vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
      vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
      vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
      vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
      vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
      vim.keymap.set({'n', 'x'}, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
      vim.keymap.set('n', '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
      vim.keymap.set('n', 'gl', '<cmd>lua vim.diagnostic.open_float()<cr>', opts)
      vim.keymap.set('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<cr>', opts)
      vim.keymap.set('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<cr>', opts)
    end
  })
end

return Plugin