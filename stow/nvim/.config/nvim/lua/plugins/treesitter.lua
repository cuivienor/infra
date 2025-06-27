return { -- Highlight, edit, and navigate code
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	opts = {
		ensure_installed = {
			"bash",
			"c",
			"cpp",
			"diff",
			"gitcommit",
			"html",
			"lua",
			"luadoc",
			"markdown",
			"markdown_inline",
			"regex",
			"vim",
			"vimdoc",
			"ruby",
			"embedded_template", -- For ERB files
		},
		-- Auto install languages that are not installed
		auto_install = true,
		highlight = {
			enable = true,
		},
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "gnn",
				node_incremental = "gnn",
				scope_incremental = "grc",
				node_decremental = "gnm",
			},
		},
		-- textobjects = require("utils.plugins.textobjects"),
		indent = { enable = true, disable = { "ruby" } },
	},
	config = function(_, opts)
		require("nvim-treesitter.install").prefer_git = true

		-- There is no treesitter zsh support so use bash instead
		vim.treesitter.language.register("bash", "zsh")

		---@diagnostic disable-next-line: missing-fields
		require("nvim-treesitter.configs").setup(opts)
	end,
}
