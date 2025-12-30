-- Git plugins: gitsigns, octo
return {
	-- Gitsigns - git signs in gutter, hunk operations
	{
		"gitsigns.nvim",
		enabled = nixCats("git") or false,
		event = { "BufReadPre", "BufNewFile" },
		after = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "+" },
					change = { text = "~" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
				},
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns

					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end

					-- Navigation
					map("n", "]h", function()
						if vim.wo.diff then
							return "]h"
						end
						vim.schedule(function()
							gs.next_hunk()
						end)
						return "<Ignore>"
					end, { expr = true, desc = "Next git hunk" })

					map("n", "[h", function()
						if vim.wo.diff then
							return "[h"
						end
						vim.schedule(function()
							gs.prev_hunk()
						end)
						return "<Ignore>"
					end, { expr = true, desc = "Previous git hunk" })

					-- Actions
					map("n", "<leader>hs", gs.stage_hunk, { desc = "Git [h]unk [s]tage" })
					map("n", "<leader>hr", gs.reset_hunk, { desc = "Git [h]unk [r]eset" })
					map("v", "<leader>hs", function()
						gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, { desc = "Git [h]unk [s]tage" })
					map("v", "<leader>hr", function()
						gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, { desc = "Git [h]unk [r]eset" })
					map("n", "<leader>hS", gs.stage_buffer, { desc = "Git [h]unk [S]tage buffer" })
					map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Git [h]unk [u]ndo stage" })
					map("n", "<leader>hR", gs.reset_buffer, { desc = "Git [h]unk [R]eset buffer" })
					map("n", "<leader>hp", gs.preview_hunk, { desc = "Git [h]unk [p]review" })
					map("n", "<leader>hb", function()
						gs.blame_line({ full = false })
					end, { desc = "Git [h]unk [b]lame line" })
					map("n", "<leader>hd", gs.diffthis, { desc = "Git [h]unk [d]iff" })
					map("n", "<leader>hD", function()
						gs.diffthis("~")
					end, { desc = "Git [h]unk [D]iff against ~" })

					-- Toggles
					map("n", "<leader>tb", gs.toggle_current_line_blame, { desc = "[T]oggle git [b]lame line" })
					map("n", "<leader>td", gs.toggle_deleted, { desc = "[T]oggle git show [d]eleted" })

					-- Text object
					map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select git hunk" })
				end,
			})
		end,
	},

	-- Octo - GitHub PRs and issues
	{
		"octo.nvim",
		enabled = nixCats("git") or false,
		cmd = { "Octo" },
		after = function()
			require("octo").setup({
				enable_builtin = true,
			})
		end,
	},
}
