return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- TODO: Move to a utilities place
		local function should_disable_markdown_lint()
			local excluded_base_path = vim.fn.expand("~/.local/share/nvim/gp/chats/")
			local current_file_path = vim.fn.expand("%:p") -- Get full path to current file

			return vim.startswith(current_file_path, excluded_base_path)
		end

		lint.linters_by_ft = {
			markdown = { "markdownlint" },
			sh = { "shellcheck" },
			bash = { "shellcheck" },
			zsh = { "shellcheck" },
			-- Ruby diagnostics handled by RuboCop LSP in shadowenv.lua
			-- ruby = { "rubocop" },
			eruby = { "erb_lint" },
			swift = { "swiftlint" },
		}

		local markdownlint = require("lint").linters.markdownlint
		markdownlint.args = {
			"--disable",
			"MD013",
			"--",
		}
		
		-- Note: Ruby linting is handled by RuboCop LSP server in shadowenv.lua
		-- for shadowenv projects with bin/rubocop

		-- Create autocommand which carries out the actual linting
		-- on the specified events.
		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				if should_disable_markdown_lint() then
					lint.linters_by_ft.markdown = {}
				end
				require("lint").try_lint()
			end,
		})
		
		-- Create commands for manual linting
		vim.api.nvim_create_user_command("LintInfo", function()
			local filetype = vim.bo.filetype
			local linters = lint.linters_by_ft[filetype] or {}
			
			if #linters > 0 then
				local lines = { "Active linters for " .. filetype .. ":" }
				for _, linter_name in ipairs(linters) do
					table.insert(lines, "  - " .. linter_name)
					local linter = lint.linters[linter_name]
					if linter then
						local cmd = type(linter.cmd) == "function" and linter.cmd() or linter.cmd
						table.insert(lines, "    Command: " .. tostring(cmd))
						if linter.cwd then
							local cwd = type(linter.cwd) == "function" and linter.cwd() or linter.cwd
							table.insert(lines, "    Working dir: " .. tostring(cwd))
						end
					end
				end
				vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
			else
				vim.notify("No linters configured for filetype: " .. filetype, vim.log.levels.WARN)
			end
		end, { desc = "Show lint info for current buffer" })
		
		vim.api.nvim_create_user_command("Lint", function()
			require("lint").try_lint()
			vim.notify("Linting triggered", vim.log.levels.INFO)
		end, { desc = "Manually trigger linting" })
	end,
}
