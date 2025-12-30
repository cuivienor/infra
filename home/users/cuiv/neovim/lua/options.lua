-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Enable mouse mode
vim.opt.mouse = "a"

-- Don't show mode (shown in statusline)
vim.opt.showmode = false

-- Clipboard via OSC 52 (works over SSH/terminal)
-- Only use OSC 52 for copying - paste via terminal (Ctrl+Shift+V)
vim.g.clipboard = {
	name = "OSC 52",
	copy = {
		["+"] = require("vim.ui.clipboard.osc52").copy("+"),
		["*"] = require("vim.ui.clipboard.osc52").copy("*"),
	},
	paste = {
		-- Return empty to avoid OSC 52 read timeout
		-- Use terminal paste (Ctrl+Shift+V) instead
		["+"] = function() return {} end,
		["*"] = function() return {} end,
	},
}
vim.opt.clipboard = "unnamedplus"

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or capital letters
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on
vim.opt.signcolumn = "yes"

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time (shows which-key sooner)
vim.opt.timeoutlen = 300

-- Configure splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Whitespace display
vim.opt.list = false
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live
vim.opt.inccommand = "split"

-- Show cursor line
vim.opt.cursorline = true

-- Scroll offset
vim.opt.scrolloff = 10

-- Search highlighting
vim.opt.hlsearch = true

-- Default formatting
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

-- Swap file configuration
vim.opt.swapfile = true
vim.opt.directory = vim.fn.expand("~/.local/state/nvim/swap//")
vim.opt.updatecount = 100

-- Terminal colors
vim.opt.termguicolors = true
