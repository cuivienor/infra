return { -- Autoformat
	"stevearc/conform.nvim",
	lazy = false,
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true, lsp_fallback = true })
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
		{
			"<leader>fi",
			":ConformInfo<CR>",
			mode = "n",
			desc = "[F]ormat [I]nfo - show active formatters",
		},
	},
	opts = {
		notify_on_error = false,
		-- Configure formatters
		formatters = {
			rubocop = {
				-- Dynamically determine the rubocop command and args
				command = function(ctx)
					-- Get the directory from context or current file
					local dir = ctx.dirname or vim.fn.expand("%:p:h")
					
					-- Check if we're in a shadowenv project
					local shadowenv_dir = vim.fn.finddir(".shadowenv.d", dir .. ";")
					if shadowenv_dir ~= "" then
						local project_root = vim.fn.fnamemodify(shadowenv_dir, ":h")
						local bin_rubocop = project_root .. "/bin/rubocop"
						
						-- If there's a bin/rubocop, use it (it will use bundler and shadowenv)
						if vim.fn.filereadable(bin_rubocop) == 1 then
							return bin_rubocop
						end
						
						-- Fallback - don't use global rubocop for shadowenv projects
						-- This prevents conflicts with project-specific cops
						vim.notify("RuboCop not found in project. Run: bundle install", vim.log.levels.WARN)
						return nil
					end
					
					-- For non-shadowenv projects, use global rubocop if available
					return "rubocop"
				end,
				args = function(ctx)
					-- Get the directory from context or current file
					local dir = ctx.dirname or vim.fn.expand("%:p:h")
					
					-- Check if we're using project rubocop (no --server for binstubs)
					local shadowenv_dir = vim.fn.finddir(".shadowenv.d", dir .. ";")
					if shadowenv_dir ~= "" then
						local project_root = vim.fn.fnamemodify(shadowenv_dir, ":h")
						local bin_rubocop = project_root .. "/bin/rubocop"
						
						if vim.fn.filereadable(bin_rubocop) == 1 then
							-- Don't use --server with binstub, it handles its own optimization
							return {
								"--auto-correct-all",
								"--stderr",
								"--force-exclusion",
								"--stdin",
								"$FILENAME",
							}
						end
					end
					
					-- For global rubocop, use server mode
					return {
						"--server",
						"--auto-correct-all",
						"--stderr",
						"--force-exclusion",
						"--stdin",
						"$FILENAME",
					}
				end,
				stdin = true,
				cwd = function(ctx)
					-- Get the directory from context or current file
					local dir = ctx.dirname or vim.fn.expand("%:p:h")
					
					-- Find the project root (where .rubocop.yml likely is)
					local rubocop_config = vim.fn.findfile(".rubocop.yml", dir .. ";")
					if rubocop_config ~= "" then
						return vim.fn.fnamemodify(rubocop_config, ":h")
					end
					return dir
				end,
				condition = function(ctx)
					-- Get the directory from context or current file
					local dir = ctx.dirname or vim.fn.expand("%:p:h")
					
					-- Only run if we have a valid command
					local shadowenv_dir = vim.fn.finddir(".shadowenv.d", dir .. ";")
					if shadowenv_dir ~= "" then
						local project_root = vim.fn.fnamemodify(shadowenv_dir, ":h")
						local bin_rubocop = project_root .. "/bin/rubocop"
						return vim.fn.filereadable(bin_rubocop) == 1
					end
					-- For non-shadowenv projects, check global rubocop
					return vim.fn.executable("rubocop") == 1
				end,
			},
			ruff_format = {
				command = "ruff",
				args = { "format", "--stdin-filename", "$FILENAME", "-" },
				stdin = true,
			},
			swiftformat = {
				-- Use system SwiftFormat installed via Homebrew
				command = "swiftformat",
				args = { 
					"--quiet",
					"stdin",
					"--stdinpath", "$FILENAME",
					-- Match SwiftLint rules
					"--maxwidth", "120",  -- Line length limit
					"--swift-version", "5.9",  -- Swift version
					-- Note: trailing commas are allowed (personal preference)
				},
				stdin = true,
				condition = function()
					return vim.fn.executable("swiftformat") == 1
				end,
			},
		},
		-- format_on_save = function(bufnr)
		-- 	-- Disable "format_on_save lsp_fallback" for languages that don't
		-- 	-- have a well standardized coding style. You can add additional
		-- 	-- languages here or re-enable it for the disabled ones.
		-- 	local disable_filetypes = { yaml = true, c = true, cpp = true }
		-- 	return {
		-- 		timeout_ms = 500,
		-- 		lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
		-- 	}
		-- end,
		formatters_by_ft = {
			lua = { "stylua" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			yaml = { "yamlfix" },
			tf = { "terraform_fmt" },
			markdown = { "prettierd" },
			-- Ruby formatting: use rubocop command, but prefer LSP if available
			-- When RuboCop LSP is attached (shadowenv projects), it will be used
			-- When no LSP, the rubocop formatter will be used (non-shadowenv projects)
			ruby = { lsp_format = "first", "rubocop" },
			eruby = { "erb_format" },
			-- JavaScript/TypeScript formatting
			javascript = { { "prettierd", "prettier" } },
			typescript = { { "prettierd", "prettier" } },
			javascriptreact = { { "prettierd", "prettier" } },
			typescriptreact = { { "prettierd", "prettier" } },
			json = { { "prettierd", "prettier" } },
			-- Python formatting
			python = { "ruff_format" },
			-- Swift formatting
			swift = { "swiftformat" },
			-- Conform can also run multiple formatters sequentially
			-- python = { "isort", "black" },
			--
			-- You can use a sub-list to tell conform to run *until* a formatter
			-- is found.
		},
	},
	config = function(_, opts)
		local conform = require("conform")
		conform.setup(opts)
		
		-- Create a command to show format info
		vim.api.nvim_create_user_command("ConformInfo", function()
			local info = conform.list_formatters_for_buffer(0)
			if #info > 0 then
				local lines = { "Active formatters for this buffer:" }
				for _, formatter_name in ipairs(info) do
					table.insert(lines, "  - " .. formatter_name)
					-- Get the formatter info
					local formatter_info = conform.get_formatter_info(formatter_name, vim.api.nvim_get_current_buf())
					if formatter_info and formatter_info.available then
						table.insert(lines, "    Command: " .. formatter_info.command)
						if formatter_info.cwd then
							table.insert(lines, "    Working dir: " .. formatter_info.cwd)
						end
					elseif formatter_info then
						table.insert(lines, "    Status: Not available")
						if formatter_info.available_msg then
							table.insert(lines, "    Reason: " .. formatter_info.available_msg)
						end
					end
				end
				vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
			else
				vim.notify("No formatters configured for this filetype", vim.log.levels.WARN)
			end
		end, { desc = "Show conform formatter info" })
	end,
}
