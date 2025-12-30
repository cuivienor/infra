-- Completion configuration (nvim-cmp + LuaSnip)
return {
	{
		"nvim-cmp",
		enabled = nixCats("completion") or false,
		event = "InsertEnter",
		load = function(name)
			vim.cmd.packadd(name)
			vim.cmd.packadd("cmp-nvim-lsp")
			vim.cmd.packadd("cmp-path")
			vim.cmd.packadd("cmp_luasnip")
			vim.cmd.packadd("luasnip")
			vim.cmd.packadd("friendly-snippets")
		end,
		after = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			-- Load friendly-snippets
			require("luasnip.loaders.from_vscode").lazy_load()

			luasnip.config.setup({})

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				completion = { completeopt = "menu,menuone,noinsert" },
				mapping = cmp.mapping.preset.insert({
					-- Select next/prev item
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),

					-- Scroll docs
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),

					-- Accept completion
					["<C-y>"] = cmp.mapping.confirm({ select = true }),

					-- Trigger completion manually
					["<C-Space>"] = cmp.mapping.complete({}),

					-- Snippet navigation
					["<C-l>"] = cmp.mapping(function()
						if luasnip.expand_or_locally_jumpable() then
							luasnip.expand_or_jump()
						end
					end, { "i", "s" }),
					["<C-h>"] = cmp.mapping(function()
						if luasnip.locally_jumpable(-1) then
							luasnip.jump(-1)
						end
					end, { "i", "s" }),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "path" },
				},
			})
		end,
	},
}
