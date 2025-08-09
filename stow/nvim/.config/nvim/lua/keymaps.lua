-- Clear highlight from search on escape
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Go to next [D]iagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Disable arrow navigation
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Source lua code maps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<space>x", ":.lua<CR>")
vim.keymap.set("v", "<space>x", ":lua<CR>")

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

-- Custom keymaps
-- Move file keybinding and logic
-- TODO: Move this function in a separate appropriate place
vim.keymap.set("n", "<leader>mv", function()
	local current_file = vim.fn.expand("%:p")
	local current_file_name = vim.fn.fnamemodify(current_file, ":t")

	require("telescope.builtin").find_files({
		prompt_title = "Select Folder to Move File",
		cwd = vim.fn.getcwd(), -- Start from the current working directory
		find_command = { "find", ".", "-type", "d", "-not", "-path", "./.git/*" }, -- Use find to get directories
		attach_mappings = function(prompt_bufnr, map)
			map("i", "<CR>", function()
				local new_dir = require("telescope.actions.state").get_selected_entry().path
				require("telescope.actions").close(prompt_bufnr)

				-- Ask for confirmation/edit of new filename
				vim.ui.input({ prompt = "New filename: ", default = current_file_name }, function(new_file_name)
					if new_file_name and #new_file_name > 0 then
						local new_file_path = new_dir .. "/" .. new_file_name
						vim.fn.mkdir(new_dir, "p") -- Ensure the directory exists
						vim.fn.rename(current_file, new_file_path) -- Move the file
						vim.cmd("e " .. new_file_path) -- Open the new file
						vim.cmd("bw " .. current_file) -- Close the old file
					else
						print("Move cancelled")
					end
				end)
			end)
			return true
		end,
	})
end, { desc = "Move file to a new directory" })
