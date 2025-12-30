-- Formatting and linting plugins
return {
	-- Conform - formatter
	{
		"conform.nvim",
		enabled = nixCats("format") or false,
		event = { "BufWritePre" },
		keys = {
			{
				"<leader>f",
				function()
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				desc = "[F]ormat buffer",
			},
		},
		after = function()
			require("conform").setup({
				formatters_by_ft = {
					lua = { "stylua" },
					nix = { "nixfmt" },
					sh = { "shfmt" },
					bash = { "shfmt" },
					python = { "ruff_format" },
					javascript = { "prettierd", "prettier", stop_after_first = true },
					typescript = { "prettierd", "prettier", stop_after_first = true },
					json = { "prettierd", "prettier", stop_after_first = true },
					yaml = { "yamlfix" },
					markdown = { "prettierd", "prettier", stop_after_first = true },
				},
				format_on_save = {
					timeout_ms = 500,
					lsp_fallback = true,
				},
			})
		end,
	},

	-- nvim-lint - linter
	{
		"nvim-lint",
		enabled = nixCats("format") or false,
		event = { "BufReadPre", "BufNewFile" },
		after = function()
			local lint = require("lint")

			lint.linters_by_ft = {
				sh = { "shellcheck" },
				bash = { "shellcheck" },
				yaml = { "yamllint" },
				terraform = { "tflint" },
				markdown = { "markdownlint" },
			}

			-- Lint on save and insert leave
			vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
				group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
				callback = function()
					lint.try_lint()
				end,
			})
		end,
	},
}
