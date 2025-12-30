-- Highlight when yanking text
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Set filetype for .t files (tmux sessionizer scripts)
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = ".t",
	command = "set filetype=bash",
})
