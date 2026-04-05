local Plugin = { "nvim-treesitter/nvim-treesitter", branch = "main" }

Plugin.main = "nvim-treesitter"

Plugin.dependencies = {
	{ "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
}

-- See :help nvim-treesitter-modules
Plugin.opts = {
	auto_install = false,

	highlight = {
		enable = true,
	},

	-- :help nvim-treesitter-textobjects-modules
	textobjects = {
		select = {
			enable = true,
			lookahead = true,
			keymaps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
			},
		},
	},

	ensure_installed = {
		"vim",
		"vimdoc",
		"python",
		"ruby",
		"javascript",
		"typescript",
		"bash",
		"c",
		"diff",
		"html",
		"jsdoc",
		"json",
		"jsonc",
		"lua",
		"luadoc",
		"luap",
		"markdown",
		"markdown_inline",
		"printf",
		"query",
		"regex",
		"swift",
		"toml",
		"tsx",
		"typescript",
		"xml",
		"yaml",
	},
}

return Plugin
