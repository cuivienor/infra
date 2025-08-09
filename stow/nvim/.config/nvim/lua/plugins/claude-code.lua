return {
	"greggh/claude-code.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	lazy = false,
	priority = 100,
	config = function()
		require("claude-code").setup({
			window = {
				split_ratio = 0.3,
				position = "botright",
				enter_insert = true,
			},
			keymaps = {
				toggle = {
					normal = "<C-,>",
					terminal = "<C-,>",
				},
			},
		})
	end,
}