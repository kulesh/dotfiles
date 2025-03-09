-- https://github.com/greggh/claude-code.nvim

local Plugin = {'greggh/claude-code.nvim'}

Plugin.opts = {
	options = {
		dependencies = {
			"nvim-lua/plenary.nvim", -- Required for git operations
		},
		config = function()
			require("claude-code").setup()
		end
	}
}

return Plugin
