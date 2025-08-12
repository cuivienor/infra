return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-telescope/telescope.nvim", -- Optional
		{
			"stevearc/dressing.nvim", -- Optional: Improves the default vim.ui interfaces
			opts = {},
		},
	},
	config = function()
		require("codecompanion").setup({
			adapters = {
				-- Shopify LLM Gateway with OpenAI-compatible interface
				shopify_llm = function()
					return require("codecompanion.adapters").extend("openai_compatible", {
						env = {
							url = "https://proxy-shopify-ai.local.shop.dev",
							api_key = "dummy", -- CodeCompanion requires a non-empty value
							chat_url = "/v1/chat/completions",
							models_endpoint = "/v1/models",
						},
						schema = {
							model = {
								default = "gpt-5",
								choices = {
									"gpt-5",
									"gpt-5-mini",
									"gpt-5-nano",
									"o3",
									"claude-opus-4",
									"claude-sonnet-4",
									"google:gemini-2.5-pro",
								},
							},
						},
					})
				end,
			},
			strategies = {
				chat = {
					adapter = "shopify_llm",
				},
				inline = {
					adapter = "shopify_llm",
				},
				agent = {
					adapter = "shopify_llm",
				},
			},
			display = {
				diff = {
					provider = "mini_diff",
				},
			},
			opts = {
				log_level = "ERROR",
				send_code = true,
				use_default_actions = true,
				use_default_prompts = true,
			},
			extensions = {
				mcphub = {
					callback = "mcphub.extensions.codecompanion",
					opts = {
						make_tools = true, -- Make individual tools and server groups
						show_server_tools_in_chat = true,
						add_mcp_prefix_to_tool_names = false,
						show_result_in_chat = true,
						make_vars = true, -- Convert MCP resources to #variables
						make_slash_commands = true, -- Add MCP prompts as /slash commands
					},
				},
			},
		})
	end,
	cmd = {
		"CodeCompanion",
		"CodeCompanionActions",
		"CodeCompanionChat",
	},
	keys = {
		{ "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "CodeCompanion Chat" },
		{ "<leader>ca", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion Actions" },
		{ "<leader>cp", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "CodeCompanion Prompt" },
		{ "<C-a>", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion Actions" },
		{
			"<leader>cs",
			"<cmd>CodeCompanionChat Add<cr>",
			mode = { "v" },
			desc = "CodeCompanion Send to Chat",
		},
	},
}
