return {
	"coder/claudecode.nvim",
	event = "VeryLazy",
	config = function()
		require("claudecode").setup({
			-- Start server automatically when Neovim starts
			auto_start = true,

			-- Disable internal terminal - using external Claude in separate tmux tab
			terminal = {
				provider = "none",
			},

			-- Log level for debugging (optional)
			-- log_level = "debug",
		})

		-- Keymaps for external Claude integration
		vim.keymap.set("n", "<leader>cs", ":ClaudeCodeStatus<CR>", { desc = "[C]laude [S]tatus" })
		vim.keymap.set("n", "<leader>ca", ":ClaudeCodeAdd %<CR>", { desc = "[C]laude [A]dd current file" })
		vim.keymap.set("v", "<leader>cs", ":ClaudeCodeSend<CR>", { desc = "[C]laude [S]end selection" })

		-- Optional: Add keymap to quickly show connection info
		vim.keymap.set("n", "<leader>ci", function()
			local claudecode = require("claudecode")
			local is_connected = claudecode.is_claude_connected()
			local status = is_connected and "✓ Connected" or "✗ Not connected"
			print("Claude: " .. status)
		end, { desc = "[C]laude [I]nfo" })
	end,
}
