return {
	"pwntester/octo.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("octo").setup({
			picker = "telescope",
		})

		-- Key mappings for common octo operations
		vim.keymap.set("n", "<leader>gh", function()
			vim.cmd("Octo actions")
		end, { desc = "[G]it[H]ub actions" })

		vim.keymap.set("n", "<leader>gp", function()
			vim.cmd("Octo pr list")
		end, { desc = "[G]it [P]R list" })

		vim.keymap.set("n", "<leader>gi", function()
			vim.cmd("Octo issue list")
		end, { desc = "[G]it [I]ssue list" })

		-- Quick command to open PR for current commit
		vim.keymap.set("n", "<leader>gpc", function()
			local commit = vim.fn.expand("<cword>")
			if commit:match("^%x+$") and #commit >= 7 then
				vim.cmd("Octo search " .. commit .. " type:pr")
			else
				print("No valid commit hash under cursor")
			end
		end, { desc = "[G]it [P]R from [C]ommit" })
	end,
}