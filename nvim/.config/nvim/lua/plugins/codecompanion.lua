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

function Plugin.config()
	require("codecompanion").setup({
		adapters = {
			anthropic = function()
				local anthropic_key = vim.fn.getenv("ANTHROPIC_API_KEY")
				-- print("ANTHROPIC_API_KEY exists: " .. tostring(anthropic_key ~= nil))
  			-- if anthropic_key then
    			-- print("ANTHROPIC_API_KEY length: " .. string.len(anthropic_key))
  			-- end
				return require("codecompanion.adapters").extend("anthropic", {
					env = {
						api_key = anthropic_key,
					},
				})
			end,
		},
		strategies = {
			chat = { adapter = "anthropic", },
			inline = { adapter = "anthropic" },
			agent = { adapter = "anthropic" },
		},
	})
end

return Plugin
