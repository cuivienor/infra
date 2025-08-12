return {
	"ravitemer/mcphub.nvim",
	version = "*", -- Use latest stable version
	config = function()
		require("mcphub").setup({
			-- Explicit port configuration for Claude Code integration
			port = 37373,
			
			-- Server configuration paths
			config = vim.fn.expand("~/.config/mcphub/servers.json"),
			
			-- Auto-shutdown after 10 minutes of inactivity
			shutdown_delay = 10 * 60 * 1000,
			
			-- MCP request timeout (60 seconds default)
			mcp_request_timeout = 5000,
			
			-- Workspace configuration for project-local MCP servers
			workspace = {
				enabled = true,
				look_for = { ".mcphub/servers.json", ".vscode/mcp.json" },
				reload_on_dir_changed = true,
				port_range = { 40000, 41000 },
			},
			
			-- Chat plugin integration settings
			auto_approve = false, -- Require manual approval for tool calls
			auto_toggle_mcp_servers = true, -- Allow LLMs to manage servers
			
			-- UI configuration
			ui = {
				window = {
					width = "80%",
					height = "80%",
					border = "rounded",
				},
			},
			
			-- Logging configuration
			log = {
				level = 1, -- 0=trace, 1=debug, 2=info, 3=warn, 4=error
			},
		})
	end,
	cmd = "MCPHub", -- Lazy load on command
	keys = {
		{ "<leader>mh", "<cmd>MCPHub<cr>", desc = "Open MCP Hub" },
	},
}
