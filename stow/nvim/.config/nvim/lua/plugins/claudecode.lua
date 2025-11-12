return {
	"coder/claudecode.nvim",
	event = "VeryLazy",
	config = function()
		require("claudecode").setup({
			-- Start server automatically when Neovim starts
			auto_start = true,

			-- Terminal configuration for when using :ClaudeCode command
			terminal = {
				provider = "native", -- Use native Neovim terminal
				split_side = "right",
				split_width_percentage = 0.30,
			},

			-- Log level for debugging (optional)
			-- log_level = "debug",
		})

		-- Optional keymaps
		vim.keymap.set("n", "<leader>cc", ":ClaudeCode<CR>", { desc = "[C]laude [C]ode toggle" })
		vim.keymap.set("n", "<leader>cs", ":ClaudeCodeStatus<CR>", { desc = "[C]laude [S]tatus" })
		vim.keymap.set("n", "<leader>ca", ":ClaudeCodeAdd %<CR>", { desc = "[C]laude [A]dd current file" })
		vim.keymap.set("v", "<leader>cs", ":ClaudeCodeSend<CR>", { desc = "[C]laude [S]end selection" })
	end,
}
