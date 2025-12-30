-- LSP configuration (no Mason - tools provided by Nix)

-- LSP on_attach function
local function on_attach(client, bufnr)
	local map = function(keys, func, desc)
		vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
	end

	map("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
	map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
	map("gr", vim.lsp.buf.references, "[G]oto [R]eferences")
	map("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
	map("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
	map("<leader>ds", vim.lsp.buf.document_symbol, "[D]ocument [S]ymbols")
	map("<leader>ws", vim.lsp.buf.workspace_symbol, "[W]orkspace [S]ymbols")
	map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
	map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
	map("K", vim.lsp.buf.hover, "Hover Documentation")
	map("<C-k>", vim.lsp.buf.signature_help, "Signature Help")

	-- Workspace folders
	map("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
	map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
	map("<leader>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, "[W]orkspace [L]ist Folders")
end

return {
	-- nvim-lspconfig base
	{
		"nvim-lspconfig",
		enabled = nixCats("lsp") or false,
		event = { "BufReadPre", "BufNewFile" },
		load = function(name)
			vim.cmd.packadd(name)
			vim.cmd.packadd("fidget.nvim")
		end,
		before = function()
			-- Global LSP config
			vim.lsp.config("*", {
				on_attach = on_attach,
			})
		end,
		after = function()
			-- Set up fidget for LSP progress
			require("fidget").setup({})

			-- Get capabilities from cmp
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
			if ok then
				capabilities = vim.tbl_deep_extend("force", capabilities, cmp_lsp.default_capabilities())
			end

			-- Server configurations
			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							runtime = { version = "LuaJIT" },
							workspace = {
								checkThirdParty = false,
								library = { vim.env.VIMRUNTIME },
							},
							diagnostics = {
								globals = { "vim", "nixCats" },
								disable = { "missing-fields" },
							},
							telemetry = { enabled = false },
						},
					},
				},
				nil_ls = {
					settings = {
						["nil"] = {
							formatting = { command = { "nixfmt" } },
						},
					},
				},
				bashls = {},
				pyright = {},
				ruff = {},
				clangd = {},
				terraformls = {},
				cmake = {},
			}

			-- Configure and enable servers
			for name, config in pairs(servers) do
				config.capabilities = capabilities
				vim.lsp.config(name, config)
			end
			vim.lsp.enable(vim.tbl_keys(servers))
		end,
	},

	-- lazydev for Lua/Neovim development
	{
		"lazydev.nvim",
		enabled = nixCats("lsp") or false,
		ft = "lua",
		after = function()
			require("lazydev").setup({
				library = {
					{ words = { "nixCats" }, path = (nixCats.nixCatsPath or "") .. "/lua" },
				},
			})
		end,
	},
}
