return {
	"robitx/gp.nvim",
	config = function()
		local conf = {
			providers = {
				shopify_llm_gateway = {
					endpoint = "https://proxy-shopify-ai.local.shop.dev/v1/chat/completions",
					secret = "",
				},
			},
			agents = {
				{
					name = "O3",
					provider = "shopify_llm_gateway",
					chat = true,
					command = true,
					model = { model = "o3" },
					system_prompt = "You are a helpful AI assistant with advanced reasoning capabilities.\n",
				},
				{
					name = "Opus4",
					provider = "shopify_llm_gateway",
					chat = true,
					command = true,
					model = { model = "claude-opus-4" },
					system_prompt = "You are Claude Opus, a helpful AI assistant.\n",
				},
				{
					name = "Sonnet4",
					provider = "shopify_llm_gateway",
					chat = true,
					command = true,
					model = { model = "claude-sonnet-4" },
					system_prompt = "You are Claude Sonnet, a helpful AI assistant.\n",
				},
				{
					name = "Gemini2.5Pro",
					provider = "shopify_llm_gateway",
					chat = true,
					command = true,
					model = { model = "google:gemini-2.5-pro" },
					system_prompt = "You are Gemini, Google's helpful AI assistant.\n",
				},
			},
			chat_template = require("gp.defaults").short_chat_template,
		}
		require("gp").setup(conf)
	end,
}
