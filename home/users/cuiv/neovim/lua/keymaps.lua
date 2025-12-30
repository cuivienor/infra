-- Clear highlight from search on escape
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Go to next [D]iagnostic message" })
vim.keymap.set("n", "<leader>de", vim.diagnostic.open_float, { desc = "[D]iagnostic [E]rror float" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Disable arrow navigation
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Split navigation with CTRL+hjkl
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Source lua code maps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>", { desc = "Source current file" })
vim.keymap.set("n", "<space>x", ":.lua<CR>", { desc = "Execute current line as Lua" })
vim.keymap.set("v", "<space>x", ":lua<CR>", { desc = "Execute selection as Lua" })

-- Diagnostics to quickfix/location list
vim.keymap.set("n", "<leader>dq", function()
	vim.diagnostic.setqflist()
	vim.cmd("copen")
end, { desc = "[D]iagnostics to [Q]uickfix list" })

vim.keymap.set("n", "<leader>dl", function()
	vim.diagnostic.setloclist()
	vim.cmd("lopen")
end, { desc = "[D]iagnostics to [L]ocation list" })

-- Swap file management
vim.keymap.set("n", "<leader>wsd", function()
	local swap_dir = vim.fn.expand("~/.local/state/nvim/swap/")
	vim.cmd("!rm -f " .. swap_dir .. "*")
	print("Cleared all swap files")
end, { desc = "[W]orkspace [S]wap [D]elete all" })

vim.keymap.set("n", "<leader>wsr", "<cmd>recover<CR>", { desc = "[W]orkspace [S]wap [R]ecover" })
vim.keymap.set("n", "<leader>wsc", function()
	local current_swap = vim.fn.swapname(vim.fn.expand("%"))
	if current_swap ~= "" then
		vim.fn.delete(current_swap)
		print("Deleted swap file: " .. current_swap)
	else
		print("No swap file for current buffer")
	end
end, { desc = "[W]orkspace [S]wap [C]lear current" })

-- Copy path keymaps
vim.keymap.set("n", "<leader>cp", function()
	local path = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
	vim.fn.setreg("+", path)
	print("Copied to clipboard: " .. path)
end, { desc = "[C]opy relative [P]ath to clipboard" })

vim.keymap.set("n", "<leader>cP", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	print("Copied to clipboard: " .. path)
end, { desc = "[C]opy absolute [P]ath to clipboard" })

vim.keymap.set("n", "<leader>cf", function()
	local filename = vim.fn.expand("%:t")
	vim.fn.setreg("+", filename)
	print("Copied to clipboard: " .. filename)
end, { desc = "[C]opy [F]ilename to clipboard" })
