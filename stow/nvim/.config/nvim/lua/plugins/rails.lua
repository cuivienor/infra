return {
	-- Rails.vim - Essential Rails navigation and utilities
	{
		"tpope/vim-rails",
		ft = { "ruby", "eruby", "haml", "slim" },
		dependencies = {
			"tpope/vim-bundler",
		},
		config = function()
			-- Enable syntax highlighting for Rails files
			vim.g.rails_syntax = 1
			vim.g.rails_projections = {
				["app/controllers/*_controller.rb"] = {
					test = {
						"spec/controllers/{}_controller_spec.rb",
						"spec/requests/{}_spec.rb",
					},
				},
				["app/models/*.rb"] = {
					test = "spec/models/{}_spec.rb",
				},
				["app/helpers/*.rb"] = {
					test = "spec/helpers/{}_spec.rb",
				},
				["app/views/*.html.erb"] = {
					test = "spec/views/{}_spec.rb",
				},
			}
		end,
	},

	-- Enhanced Ruby support
	{
		"vim-ruby/vim-ruby",
		ft = "ruby",
		config = function()
			vim.g.ruby_indent_access_modifier_style = "normal"
			vim.g.ruby_indent_assignment_style = "variable"
			vim.g.ruby_indent_block_style = "do"
		end,
	},

	-- RSpec integration
	{
		"thoughtbot/vim-rspec",
		ft = { "ruby", "eruby" },
		config = function()
			vim.g.rspec_command = "!bundle exec rspec {spec}"
			
			-- RSpec keymaps
			vim.keymap.set("n", "<leader>tt", ":call RunCurrentSpecFile()<CR>", { desc = "Run current spec file" })
			vim.keymap.set("n", "<leader>ts", ":call RunNearestSpec()<CR>", { desc = "Run nearest spec" })
			vim.keymap.set("n", "<leader>tl", ":call RunLastSpec()<CR>", { desc = "Run last spec" })
			vim.keymap.set("n", "<leader>ta", ":call RunAllSpecs()<CR>", { desc = "Run all specs" })
		end,
	},

	-- Enhanced end completion
	{
		"tpope/vim-endwise",
		ft = { "ruby", "eruby", "sh", "zsh", "vim", "lua" },
	},

	-- Sorbet syntax highlighting
	{
		"sorbet/sorbet",
		rtp = "editors/vim",
		ft = "ruby",
	},
}