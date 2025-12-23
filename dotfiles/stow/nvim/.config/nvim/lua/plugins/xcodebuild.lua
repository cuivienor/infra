return {
	"wojciech-kulik/xcodebuild.nvim",
	dependencies = {
		"nvim-telescope/telescope.nvim",
		"MunifTanjim/nui.nvim",
	},
	ft = { "swift", "objc", "objcpp" },
	config = function()
		require("xcodebuild").setup({
			-- General settings
			restore_on_start = true, -- logs, diagnostics, and marks will be loaded on VimEnter
			auto_save = true, -- save all buffers before running build or tests

			-- Test search
			test_search = {
				file_matching = "filename_lsp", -- filename|lsp|filename_lsp
				target_matching = true, -- checks if file is in the test target
				lsp_client = "sourcekit", -- name of the LSP client
				lsp_timeout = 200, -- LSP timeout in milliseconds
			},

			-- Logs
			logs = {
				auto_open_on_success_tests = false, -- open logs when tests succeed
				auto_open_on_failed_tests = false, -- open logs when tests fail
				auto_open_on_success_build = false, -- open logs when build succeeds
				auto_open_on_failed_build = true, -- open logs when build fails
				auto_close_on_app_launch = false, -- close logs when app launches
				auto_close_on_success_build = false, -- close logs when build succeeds
				auto_focus = true, -- focus logs buffer when opened
				filetype = "objc", -- file type of logs buffer
				open_command = "silent botright 20split {path}", -- command to open logs buffer
				logs_formatter = "xcbeautify", -- xcbeautify
				only_summary = false, -- only show summary in logs
				live_logs = true, -- stream logs as they appear
				show_warnings = true, -- show warnings in logs
				notify = function(message, severity)
					vim.notify(message, severity) -- use vim.notify for notifications
				end,
				notify_progress = function(message) end, -- suppress progress notifications
			},

			-- Code Coverage
			code_coverage = {
				enabled = false, -- generate code coverage report (requires Xcode 13+)
			},

			-- Diagnostics
			diagnostics = {
				auto_generate = true, -- generate diagnostics on build
				auto_open_on_failure = true, -- open diagnostics when build/tests fail
				show_warnings = true, -- show warnings in diagnostics
				show_errors = true, -- show errors in diagnostics
			},

			-- Integrations
			integrations = {
				nvim_tree = {
					enabled = false, -- enable nvim-tree integration
				},
			},
		})

		-- Keybindings
		vim.keymap.set("n", "<leader>X", "<cmd>XcodebuildPicker<cr>", { desc = "Show Xcodebuild Actions" })
		vim.keymap.set("n", "<leader>xb", "<cmd>XcodebuildBuild<cr>", { desc = "Build Project" })
		vim.keymap.set("n", "<leader>xB", "<cmd>XcodebuildBuildForTesting<cr>", { desc = "Build For Testing" })
		vim.keymap.set("n", "<leader>xr", "<cmd>XcodebuildBuildRun<cr>", { desc = "Build & Run Project" })
		
		vim.keymap.set("n", "<leader>xt", "<cmd>XcodebuildTest<cr>", { desc = "Run Tests" })
		vim.keymap.set("n", "<leader>xT", "<cmd>XcodebuildTestClass<cr>", { desc = "Run This Test Class" })
		vim.keymap.set("n", "<leader>x.", "<cmd>XcodebuildTestRepeat<cr>", { desc = "Repeat Last Test Run" })
		
		vim.keymap.set("n", "<leader>xl", "<cmd>XcodebuildToggleLogs<cr>", { desc = "Toggle Xcodebuild Logs" })
		vim.keymap.set("n", "<leader>xc", "<cmd>XcodebuildToggleCodeCoverage<cr>", { desc = "Toggle Code Coverage" })
		vim.keymap.set("n", "<leader>xC", "<cmd>XcodebuildShowCodeCoverageReport<cr>", { desc = "Show Code Coverage Report" })
		vim.keymap.set("n", "<leader>xe", "<cmd>XcodebuildTestExplorerToggle<cr>", { desc = "Toggle Test Explorer" })
		
		vim.keymap.set("n", "<leader>xs", "<cmd>XcodebuildSelectScheme<cr>", { desc = "Select Scheme" })
		vim.keymap.set("n", "<leader>xd", "<cmd>XcodebuildSelectDevice<cr>", { desc = "Select Device" })
		vim.keymap.set("n", "<leader>xp", "<cmd>XcodebuildSelectTestPlan<cr>", { desc = "Select Test Plan" })
		
		vim.keymap.set("n", "[x", "<cmd>XcodebuildPreviousError<cr>", { desc = "Previous Xcode Error" })
		vim.keymap.set("n", "]x", "<cmd>XcodebuildNextError<cr>", { desc = "Next Xcode Error" })
	end,
}