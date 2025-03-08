-- https://github.com/ibhagwan/fzf-lua
local Plugin = {'ibhagwan/fzf-lua'}

Plugin.opts = {
		options = {
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons" },
		-- or if using mini.icons/mini.nvim
		-- dependencies = { "echasnovski/mini.icons" },
		opts = {}
	}
}
 return Plugin
