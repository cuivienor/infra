-- Set leader keys before plugins load
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Nerd font available
vim.g.have_nerd_font = true

-- Disable unused providers
vim.g.loaded_node_provider = 0
vim.g.loaded_python_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Disable netrw (oil.nvim replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Load core configuration
require("options")
require("keymaps")
require("autocommands")

-- Load plugins via lze
require("plugins")
