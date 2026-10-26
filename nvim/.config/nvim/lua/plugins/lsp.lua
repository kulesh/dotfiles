-- Language servers and formatting.
--
-- The editor uses each project's own tools at the project's versions, so
-- nvim, the project's checks, and coding agents agree. Mason puts its
-- binaries at the END of PATH: a project's .venv (ruff, basedpyright) or
-- node_modules (biome, prettier) wins, and Mason's copy is the fallback.
-- Rust and Swift use their toolchain's own servers, never Mason's.

local Plugin = {
  'neovim/nvim-lspconfig', -- provides the server definitions vim.lsp.enable() uses
  dependencies = {
    'mason-org/mason.nvim',
    'mason-org/mason-lspconfig.nvim',
    'stevearc/conform.nvim',
    'hrsh7th/cmp-nvim-lsp',
  },
}

-- A server starts when its binary is on PATH, whoever installed it. Servers
-- whose cmd is a function find their own binary and decide in root_dir.
local servers = {
  'basedpyright', 'ruff',          -- project .venv, else Mason
  'tsc',                           -- TypeScript 7+: the project's own `tsc --lsp`
  'ts_ls', 'ruby_lsp',             -- Mason; older TypeScript, the project's RuboCop
  'rust_analyzer', 'sourcekit',    -- Rust toolchain, Xcode; never Mason
  'lua_ls', 'bashls', 'jsonls', 'html', 'clangd',
}
-- What Mason installs: servers no toolchain provides, and fallbacks.
local mason_servers = { 'lua_ls', 'bashls', 'jsonls', 'html', 'clangd', 'ts_ls', 'ruby_lsp', 'basedpyright', 'ruff' }
local mason_formatters = { 'stylua', 'prettier', 'shfmt' }

local function configure_servers()
  vim.lsp.config('*', {
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
  })

  -- Ruff owns imports and formatting; basedpyright owns types and hover.
  vim.lsp.config('basedpyright', {
    settings = { basedpyright = { disableOrganizeImports = true } },
  })

  vim.lsp.config('lua_ls', {
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
    -- Outside a project with its own .luarc.json, assume nvim config code.
    on_init = function(client)
      local folder = client.workspace_folders and client.workspace_folders[1]
      if folder and (vim.uv.fs_stat(folder.name .. '/.luarc.json') or vim.uv.fs_stat(folder.name .. '/.luarc.jsonc')) then
        return
      end
      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = { version = 'LuaJIT' },
        diagnostics = { globals = { 'vim' } },
        workspace = { library = { vim.env.VIMRUNTIME, '${3rd}/luv/library' } },
      })
    end,
  })

  -- TypeScript 7 drops tsserver, so ts_ls would run a different TypeScript
  -- than the project; leave those projects to `tsc`.
  local ts_ls_root = vim.lsp.config.ts_ls.root_dir
  vim.lsp.config('ts_ls', {
    root_dir = function(bufnr, on_dir)
      ts_ls_root(bufnr, function(root)
        local tsc = vim.fs.joinpath(root, 'node_modules', '.bin', 'tsc')
        local version = vim.fn.executable(tsc) == 1 and vim.version.parse(vim.system({ tsc, '--version' }, { text = true }):wait().stdout or '')
        if not (version and version.major >= 7) then
          on_dir(root)
        end
      end)
    end,
  })

  for _, name in ipairs(servers) do
    local cmd = vim.lsp.config[name] and vim.lsp.config[name].cmd
    if type(cmd) == 'function' or (type(cmd) == 'table' and vim.fn.executable(cmd[1]) == 1) then
      vim.lsp.enable(name)
    end
  end
end

local function configure_formatting()
  local web = { 'biome', 'prettier', stop_after_first = true }
  require('conform').setup({
    -- Languages not listed here (Rust, Swift, Ruby) are formatted by their
    -- language server, which runs the project's rustfmt, swift-format, or RuboCop.
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_organize_imports', 'ruff_format' },
      javascript = web,
      typescript = web,
      javascriptreact = web,
      typescriptreact = web,
      json = web,
      jsonc = web,
      css = web,
      html = { 'prettier' },
      markdown = { 'prettier' },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
    },
    -- Biome only where the project has a biome.json; Prettier otherwise.
    formatters = { biome = { require_cwd = true } },
    format_on_save = { timeout_ms = 500, lsp_format = 'fallback' },
  })
end

local function set_keymaps()
  vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'LSP actions',
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client.name == 'ruff' then
        client.server_capabilities.hoverProvider = false -- basedpyright's hover is richer
      end

      local function map(mode, lhs, rhs)
        vim.keymap.set(mode, lhs, rhs, { buffer = event.buf })
      end
      map('n', 'K', vim.lsp.buf.hover)
      map('n', 'gd', vim.lsp.buf.definition)
      map('n', 'gD', vim.lsp.buf.declaration)
      map('n', 'gi', vim.lsp.buf.implementation)
      map('n', 'go', vim.lsp.buf.type_definition)
      map('n', 'gr', vim.lsp.buf.references)
      map('n', 'gs', vim.lsp.buf.signature_help)
      map('n', '<F2>', vim.lsp.buf.rename)
      map({ 'n', 'x' }, '<F3>', function() require('conform').format({ async = true, lsp_format = 'fallback' }) end)
      map('n', '<F4>', vim.lsp.buf.code_action)
      map('n', 'gl', vim.diagnostic.open_float)
      map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end)
      map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end)
    end,
  })
end

function Plugin.config()
  require('mason').setup({
    PATH = 'append',
    ui = { icons = { package_installed = '✓', package_pending = '➜', package_uninstalled = '✗' } },
  })

  configure_servers()
  -- Also enables what Mason installs mid-session, without waiting for a restart.
  require('mason-lspconfig').setup({ ensure_installed = mason_servers })
  configure_formatting()
  set_keymaps()

  local registry = require('mason-registry')
  registry.refresh(function(success)
    if not success then return end -- offline: try again next start
    for _, name in ipairs(mason_formatters) do
      if registry.has_package(name) and not registry.is_installed(name) then
        registry.get_package(name):install()
      end
    end
  end)
end

return Plugin
