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
			"swift",
			-- Zine languages
			"ziggy",
			"ziggy_schema",
			"supermd",
			"supermd_inline",
			"superhtml",
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

		-- Register Zine language parsers
		local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

		parser_config.ziggy = {
			install_info = {
				url = "~/dev/ziggy/tree-sitter-ziggy",
				files = { "src/parser.c" },
				branch = "main",
			},
		}

		parser_config.ziggy_schema = {
			install_info = {
				url = "~/dev/ziggy/tree-sitter-ziggy-schema",
				files = { "src/parser.c" },
				branch = "main",
			},
		}

		parser_config.supermd = {
			install_info = {
				url = "~/dev/supermd/tree-sitter/supermd",
				files = { "src/parser.c", "src/scanner.c" },
				branch = "main",
			},
		}

		parser_config.supermd_inline = {
			install_info = {
				url = "~/dev/supermd/tree-sitter/supermd-inline",
				files = { "src/parser.c", "src/scanner.c" },
				branch = "main",
			},
		}

		parser_config.superhtml = {
			install_info = {
				url = "~/dev/superhtml/tree-sitter-superhtml",
				files = { "src/parser.c", "src/scanner.c" },
				branch = "main",
			},
		}

		-- Set up Zine file type mappings
		vim.filetype.add({
			extension = {
				smd = "supermd",
				shtml = "superhtml",
				ziggy = "ziggy",
				["ziggy-schema"] = "ziggy_schema",
			},
		})

		---@diagnostic disable-next-line: missing-fields
		require("nvim-treesitter.configs").setup(opts)
	end,
}
