vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- Ruby-specific keymaps for Rails development
local map = function(keys, func, desc)
	vim.keymap.set("n", keys, func, { buffer = true, desc = "Ruby: " .. desc })
end

-- Rails-specific navigation
map("<leader>ra", ":A<CR>", "Alternate file (spec/implementation)")
map("<leader>rr", ":R<CR>", "Related file")
map("<leader>rv", ":AV<CR>", "Alternate file in vertical split")
map("<leader>rs", ":AS<CR>", "Alternate file in horizontal split")

-- Sorbet type checking
map("<leader>tc", ":!bundle exec srb tc<CR>", "Run Sorbet type check")
map("<leader>tw", ":!bundle exec srb tc --watch<CR>", "Watch Sorbet type check")

-- Rails console and server
map("<leader>rc", ":!bundle exec rails console<CR>", "Rails console")
map("<leader>rS", ":!bundle exec rails server<CR>", "Rails server")

-- Test running
map("<leader>tf", ":!bundle exec rspec %<CR>", "Run current test file")
map("<leader>tl", ":!bundle exec rspec %:" .. vim.fn.line('.') .. "<CR>", "Run test at current line")
map("<leader>ta", ":!bundle exec rspec<CR>", "Run all tests")