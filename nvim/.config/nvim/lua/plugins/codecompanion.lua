-- https://github.com/olimorris/codecompanion.nvim

local Plugin = {'olimorris/codecompanion.nvim'}

Plugin.opts = {
	options = {
		config = true,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		}
	}
}

return Plugin
