return {
	"nvimtools/none-ls.nvim",
	enabled = false,
	dependencies = { "nvim-lua/plenary.nvim", "davidmh/cspell.nvim" },
	config = function()
		local null_ls = require("null-ls")
		local cspell = require("cspell")
		local config = {
			config_file_preferred_name = "cspell.json",
			cspell_config_dirs = { "~/.config/cspell/" },
		}
		null_ls.setup({
			sources = {
				cspell.diagnostics.with({ config = config }),
				cspell.code_actions.with({ config = config }),
			},
		})
	end,
}
