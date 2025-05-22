return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"rcarriga/nvim-dap-ui",
		"nvim-neotest/nvim-nio",
		"williamboman/mason.nvim",
		"jay-babu/mason-nvim-dap.nvim",

		-- Debuggers
		"leoluz/nvim-dap-go",
		"mfussenegger/nvim-dap-python",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		require("mason-nvim-dap").setup({
			-- Makes a best effort to setup the various debuggers with
			-- reasonable debug configurations
			automatic_setup = true,

			-- You can provide additional configuration to the handlers,
			-- see mason-nvim-dap README for more information
			handlers = {},

			-- You'll need to check that you have the required things installed
			-- online, please don't ask me how to install them :)
			ensure_installed = {
				-- Update this to ensure that you have the debuggers for the langs you want
				"delve",
				"codelldb",
				"debugpy",
				"python",
			},
		})

		-- Basic debugging keymaps, feel free to change to your liking!
		vim.keymap.set("n", "dc", dap.continue, { desc = "Debug: Start/Continue" })
		vim.keymap.set("n", "di", dap.step_into, { desc = "Debug: Step Into" })
		vim.keymap.set("n", "dv", dap.step_over, { desc = "Debug: Step Over" })
		vim.keymap.set("n", "do", dap.step_out, { desc = "Debug: Step Out" })
		vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
		vim.keymap.set("n", "<leader>B", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end, { desc = "Debug: Set Breakpoint" })

		-- Dap UI setup
		-- For more information, see |:help nvim-dap-ui|
		dapui.setup({
			-- Set icons to characters that are more likely to work in every terminal.
			--    Feel free to remove or use ones that you like more! :)
			--    Don't feel like these are good choices.
			icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
			controls = {
				icons = {
					pause = "⏸",
					play = "▶",
					step_into = "⏎",
					step_over = "⏭",
					step_out = "⏮",
					step_back = "b",
					run_last = "▶▶",
					terminate = "⏹",
					disconnect = "⏏",
				},
			},
		})

		-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
		vim.keymap.set("n", "dr", dapui.toggle, { desc = "Debug: See last session result." })
		vim.keymap.set("n", "dq", dapui.close, { desc = "Debug: Close ui" })

		dap.listeners.after.event_initialized["dapui_config"] = dapui.open
		dap.listeners.before.event_terminated["dapui_config"] = dapui.close
		dap.listeners.before.event_exited["dapui_config"] = dapui.close

		-- Install golang specific config
		require("dap-go").setup()
		require("dap-python").setup("uv")
		require("dap-python").test_runner = "pytest"

		-- Setup codelldb
		dap.adapters.codelldb = {
			type = "server",
			port = "${port}",
			executable = {
				command = "codelldb",
				args = { "--port", "${port}" },
			},
		}

		dap.configurations.cpp = {
			{
				name = "Launch file",
				type = "codelldb",
				request = "launch",
				program = function()
					return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
				end,
				cwd = "${workspaceFolder}",
				stopOnEntry = false,
			},
		}

		local function get_project_root()
			local root_markers = { ".git", "setup.py", "pyproject.toml", "requirements.txt", "package.json" }
			local path = vim.fn.getcwd()

			for _, marker in ipairs(root_markers) do
				local candidate = path .. "/" .. marker
				if vim.fn.glob(candidate) ~= "" then
					return path
				elseif vim.fn.isdirectory(path .. "/.git") == 1 then
					return path
				end
			end

			return vim.fn.getcwd() -- Fallback to current directory
		end

		dap_python = require("dap-python")

		vim.keymap.set("n", "dpm", dap_python.test_method, { desc = "Debug: Debug Python method" })
		vim.keymap.set("n", "dpc", dap_python.test_class, { desc = "Debug: Debug Python class" })

		table.insert(dap.configurations.python, {
			type = "python",
			request = "launch",
			name = "Run file from root",
			program = "${file}",
			cwd = get_project_root(),
			pythonPath = "python",
		})
		table.insert(dap.configurations.python, {
			name = "Pytest: Current File",
			type = "python",
			request = "launch",
			module = "pytest",
			args = {
				"${file}",
				"-sv",
				"--log-cli-level=INFO",
				"--log-file=test_out.log",
			},
			-- console = "integratedTerminal",
		})
	end,
}
