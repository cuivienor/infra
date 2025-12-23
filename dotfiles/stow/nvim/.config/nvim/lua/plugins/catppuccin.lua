return {
	"catppuccin/nvim",
	opts = {},
	name = "catppuccin",
	priority = 1000, -- Make sure to load this before all the other start plugins.
	init = function()
		-- Load the colorscheme here.
		vim.cmd.colorscheme("catppuccin-mocha")
	end,
}
