-- Register lze handlers
require("lze").register_handlers(require("lzextras").lsp)

-- Set up colorscheme first
vim.cmd.colorscheme("catppuccin")

-- Load all plugin specs
require("lze").load({
	-- Import plugin modules
	require("plugins.completion"),
	require("plugins.lsp"),
	require("plugins.treesitter"),
	require("plugins.ui"),
	require("plugins.navigation"),
	require("plugins.format"),
	require("plugins.git"),
	require("plugins.debug"),
	require("plugins.editor"),
})
