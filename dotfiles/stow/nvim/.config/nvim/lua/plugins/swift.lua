return {
	{
		"m-housh/swift.nvim",
		ft = "swift",
		dependencies = {
			"neovim/nvim-lspconfig",
			"akinsho/toggleterm.nvim",
		},
		config = function()
			require("swift").setup({
				lsp = {
					enabled = false, -- We're already setting up sourcekit-lsp in lsp.lua
				},
				formatter = {
					enabled = false, -- We're using conform.nvim for formatting
				},
				package_info = {
					auto_show_package_info = false, -- Don't auto-show, use keybind instead
				},
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "swift",
				callback = function()
					-- Swift indentation settings
					vim.opt_local.tabstop = 4
					vim.opt_local.shiftwidth = 4
					vim.opt_local.softtabstop = 4
					vim.opt_local.expandtab = true
				end,
			})
		end,
	},
}