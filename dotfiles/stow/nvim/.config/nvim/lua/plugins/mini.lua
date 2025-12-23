return {
	"echasnovski/mini.nvim",
	config = function()
		-- better around/inside textobjects
		--
		-- examples:
		--  - va)  - visually select around [)]paren
		--  - yinq - yank inside next quote
		--  - ci'  - change inside quote
		require("mini.ai").setup({
			n_lines = 500,
			custom_textobjects = {
				o = require("mini.ai").gen_spec.treesitter({
					a = { "@block.outer", "@conditional.outer", "@loop.outer" },
					i = { "@block.inner", "@conditional.inner", "@loop.inner" },
				}),
				f = require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
				["="] = require("mini.ai").gen_spec.treesitter({ a = "@assignment.outer", i = "@assignment.inner" }),
			},
		})

		-- Add/delete/replace surroundings (brackets, quotes, etc.)
		--
		-- - saiw) - Surround Add Inner Word Paren
		-- - sd'   - Surround Delete 'quotes
		-- - sr)'  - Surround Replace ) '
		require("mini.surround").setup()

		-- Simple and easy statusline.
		--  You could remove this setup call if you don't like it,
		--  and try some other statusline plugin
		local statusline = require("mini.statusline")
		-- set use_icons to true if you have a Nerd Font
		statusline.setup({ use_icons = vim.g.have_nerd_font })

		-- You can configure sections in the statusline by overriding their
		-- default behavior. For example, here we set the section for
		-- cursor location to LINE:COLUMN
		---@diagnostic disable-next-line: duplicate-set-field
		statusline.section_location = function()
			return "%2l:%-2v"
		end

		-- ... and there is more!
		--  Check out: https://github.com/echasnovski/mini.nvim
	end,
}
