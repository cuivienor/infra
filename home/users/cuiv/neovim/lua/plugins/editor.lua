-- Editor polish plugins: autopairs, comment, sleuth, todo-comments
return {
	-- Autopairs - auto-close brackets
	{
		"nvim-autopairs",
		enabled = nixCats("editor") or false,
		event = "InsertEnter",
		after = function()
			local autopairs = require("nvim-autopairs")
			autopairs.setup({})

			-- Integrate with cmp if available
			local ok, cmp = pcall(require, "cmp")
			if ok then
				local cmp_autopairs = require("nvim-autopairs.completion.cmp")
				cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
			end
		end,
	},

	-- Comment - comment toggling
	{
		"comment.nvim",
		enabled = nixCats("editor") or false,
		event = { "BufReadPre", "BufNewFile" },
		after = function()
			require("Comment").setup()
		end,
	},

	-- vim-sleuth - auto-detect indent settings
	{
		"vim-sleuth",
		enabled = nixCats("editor") or false,
		event = { "BufReadPre", "BufNewFile" },
	},

	-- Todo-comments - highlight TODO, FIXME, etc.
	{
		"todo-comments.nvim",
		enabled = nixCats("editor") or false,
		event = { "BufReadPre", "BufNewFile" },
		after = function()
			require("todo-comments").setup({
				signs = true,
			})

			-- Keymaps
			vim.keymap.set("n", "]t", function()
				require("todo-comments").jump_next()
			end, { desc = "Next todo comment" })

			vim.keymap.set("n", "[t", function()
				require("todo-comments").jump_prev()
			end, { desc = "Previous todo comment" })

			vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "[S]earch [T]odos" })
		end,
	},
}
