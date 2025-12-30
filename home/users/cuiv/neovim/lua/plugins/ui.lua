-- UI plugins: noice, which-key, mini, indent-blankline
return {
	-- Noice - better UI for messages, cmdline, popups
	{
		"noice.nvim",
		enabled = nixCats("ui") or false,
		event = "DeferredUIEnter",
		load = function(name)
			vim.cmd.packadd(name)
			vim.cmd.packadd("nvim-notify")
			vim.cmd.packadd("nui.nvim")
		end,
		after = function()
			require("noice").setup({
				lsp = {
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["vim.lsp.util.stylize_markdown"] = true,
						["cmp.entry.get_documentation"] = true,
					},
				},
				presets = {
					bottom_search = true,
					command_palette = true,
					long_message_to_split = true,
					inc_rename = false,
					lsp_doc_border = false,
				},
			})
		end,
	},

	-- Which-key - keybinding hints
	{
		"which-key.nvim",
		enabled = nixCats("ui") or false,
		event = "DeferredUIEnter",
		after = function()
			require("which-key").setup({})
			require("which-key").add({
				{ "<leader>c", group = "[C]ode" },
				{ "<leader>d", group = "[D]iagnostics/[D]ocument" },
				{ "<leader>r", group = "[R]ename" },
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>w", group = "[W]orkspace" },
				{ "<leader>g", group = "[G]it" },
				{ "<leader>h", group = "Git [H]unk" },
			})
		end,
	},

	-- Mini.nvim - statusline, surround, ai textobjects
	{
		"mini.nvim",
		enabled = nixCats("ui") or false,
		event = "DeferredUIEnter",
		after = function()
			-- Statusline
			require("mini.statusline").setup({
				use_icons = vim.g.have_nerd_font,
			})

			-- Surround operations
			require("mini.surround").setup()

			-- Better around/inside textobjects
			require("mini.ai").setup({ n_lines = 500 })
		end,
	},

	-- Indent guides
	{
		"indent-blankline.nvim",
		enabled = nixCats("ui") or false,
		event = { "BufReadPre", "BufNewFile" },
		after = function()
			require("ibl").setup({
				indent = { char = "│" },
				scope = { enabled = true },
			})
		end,
	},
}
