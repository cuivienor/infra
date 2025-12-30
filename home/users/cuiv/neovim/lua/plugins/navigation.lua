-- Navigation plugins: telescope, oil
return {
	-- Telescope - fuzzy finder
	{
		"telescope.nvim",
		enabled = nixCats("navigation") or false,
		event = "VimEnter",
		load = function(name)
			vim.cmd.packadd(name)
			vim.cmd.packadd("telescope-fzf-native.nvim")
			vim.cmd.packadd("telescope-ui-select.nvim")
		end,
		after = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")

			telescope.setup({
				defaults = {
					mappings = {
						i = {
							["<C-k>"] = actions.move_selection_previous,
							["<C-j>"] = actions.move_selection_next,
							["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
						},
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown(),
					},
				},
			})

			-- Load extensions
			pcall(telescope.load_extension, "fzf")
			pcall(telescope.load_extension, "ui-select")

			local builtin = require("telescope.builtin")

			-- File pickers
			vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
			vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
			vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
			vim.keymap.set("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
			vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = "[S]earch Recent Files" })
			vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })

			-- Git pickers
			vim.keymap.set("n", "<leader>gf", builtin.git_files, { desc = "Search [G]it [F]iles" })

			-- Vim pickers
			vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
			vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
			vim.keymap.set("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
			vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })

			-- Current buffer search
			vim.keymap.set("n", "<leader>/", function()
				builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					winblend = 10,
					previewer = false,
				}))
			end, { desc = "[/] Fuzzily search in current buffer" })

			-- Search in open files
			vim.keymap.set("n", "<leader>s/", function()
				builtin.live_grep({
					grep_open_files = true,
					prompt_title = "Live Grep in Open Files",
				})
			end, { desc = "[S]earch [/] in Open Files" })

			-- Search neovim config
			vim.keymap.set("n", "<leader>sn", function()
				builtin.find_files({ cwd = vim.fn.stdpath("config") })
			end, { desc = "[S]earch [N]eovim files" })
		end,
	},

	-- Zellij-nav - seamless navigation between neovim and zellij panes
	{
		"zellij-nav.nvim",
		enabled = nixCats("navigation") or false,
		event = "DeferredUIEnter",
		keys = {
			{ "<c-h>", "<cmd>ZellijNavigateLeftTab<cr>", desc = "Navigate left or tab" },
			{ "<c-j>", "<cmd>ZellijNavigateDown<cr>", desc = "Navigate down" },
			{ "<c-k>", "<cmd>ZellijNavigateUp<cr>", desc = "Navigate up" },
			{ "<c-l>", "<cmd>ZellijNavigateRightTab<cr>", desc = "Navigate right or tab" },
		},
		after = function()
			require("zellij-nav").setup()
		end,
	},

	-- Oil - file explorer as buffer
	{
		"oil.nvim",
		enabled = nixCats("navigation") or false,
		-- Load on VimEnter so it handles `nvim .` properly
		event = "VimEnter",
		keys = {
			{ "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
		},
		after = function()
			require("oil").setup({
				default_file_explorer = true,
				columns = {
					"icon",
				},
				view_options = {
					show_hidden = true,
				},
				keymaps = {
					["g?"] = "actions.show_help",
					["<CR>"] = "actions.select",
					["<C-v>"] = "actions.select_vsplit",
					["<C-s>"] = "actions.select_split",
					["<C-t>"] = "actions.select_tab",
					["<C-p>"] = "actions.preview",
					["<C-c>"] = "actions.close",
					["<C-r>"] = "actions.refresh",
					["-"] = "actions.parent",
					["_"] = "actions.open_cwd",
					["`"] = "actions.cd",
					["~"] = "actions.tcd",
					["gs"] = "actions.change_sort",
					["gx"] = "actions.open_external",
					["g."] = "actions.toggle_hidden",
				},
			})
		end,
	},
}
