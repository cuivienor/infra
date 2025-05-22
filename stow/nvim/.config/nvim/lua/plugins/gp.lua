return {
	"robitx/gp.nvim",
	config = function()
		local conf =
			{ openai_api_key = os.getenv("OPEN_API_KEY"), chat_template = require("gp.defaults").short_chat_template }
		require("gp").setup(conf)
	end,
}
