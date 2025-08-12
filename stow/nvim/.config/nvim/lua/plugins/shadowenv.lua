-- ============================================================================
-- Ruby Shadowenv LSP Integration for Shopify Development
-- ============================================================================
-- Integrates Ruby LSP with shadowenv to support multiple projects with
-- different Ruby environments in a single Neovim session.
--
-- This configuration allows ruby-lsp to work correctly with Shopify's
-- nix-based shadowenv environments, ensuring each project uses its own
-- Ruby version and gem dependencies.
-- ============================================================================

return {
	"Shopify/shadowenv.vim", -- Shopify shadowenv integration
	config = function()
		-- ============================================================================
		-- Shadowenv Module - Handles all shadowenv operations
		-- ============================================================================
		local shadowenv = {}

		-- Check if a directory has shadowenv configuration
		shadowenv.has_shadowenv = function(dir)
			return vim.fn.isdirectory(dir .. "/.shadowenv.d") == 1
		end

		-- Load shadowenv environment for a directory
		shadowenv.load_environment = function(directory)
			if not shadowenv.has_shadowenv(directory) then
				return nil
			end

			local original_cwd = vim.fn.getcwd()

			-- Change to directory and load shadowenv
			vim.cmd("cd " .. vim.fn.fnameescape(directory))
			local ok, _ = pcall(function()
				vim.cmd("ShadowenvHook")
			end)

			if not ok then
				vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
				return nil
			end

			-- Capture environment
			local env = vim.fn.environ()

			-- Restore directory
			vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

			return env
		end

		-- Extract Ruby-specific paths from shadowenv environment
		shadowenv.get_ruby_paths = function(environment)
			if not environment or not environment.GEM_PATH then
				return nil
			end

			local gem_path = environment.GEM_PATH
			local shadowenv_gem_dir = gem_path:match("(/[^:]*%.dev/gem/[^:]+)")

			if shadowenv_gem_dir then
				return {
					ruby_lsp = shadowenv_gem_dir .. "/bin/ruby-lsp",
					gem_home = shadowenv_gem_dir,
					gem_path = gem_path,
					bundle_app_config = shadowenv_gem_dir,
					path = environment.PATH,
				}
			end

			return nil
		end

		-- ============================================================================
		-- LSP Module - Handles all LSP operations
		-- ============================================================================
		local lsp = {}

		-- Create capabilities for LSP
		lsp.make_capabilities = function()
			local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			if has_cmp then
				return cmp_nvim_lsp.default_capabilities()
			else
				return vim.lsp.protocol.make_client_capabilities()
			end
		end

		-- Create and start an LSP client
		lsp.create_client = function(config)
			-- Remove bufnr from initial start to avoid premature attachment
			local start_config = vim.deepcopy(config)
			start_config.bufnr = nil
			
			local client_id = vim.lsp.start_client(start_config)
			
			if client_id then
				-- Wait for client to initialize before attaching
				vim.defer_fn(function()
					local client = vim.lsp.get_client_by_id(client_id)
					if client and client.initialized and vim.api.nvim_buf_is_valid(config.bufnr) then
						vim.lsp.buf_attach_client(config.bufnr, client_id)
					end
				end, 100)
			end
			
			return client_id
		end

		-- Attach existing client to buffer
		lsp.attach_client = function(client_id, bufnr)
			local client = vim.lsp.get_client_by_id(client_id)
			if client and client.initialized then
				vim.lsp.buf_attach_client(bufnr, client_id)
				return true
			end
			return false
		end

		-- Stop an LSP client
		lsp.stop_client = function(client_id)
			local client = vim.lsp.get_client_by_id(client_id)
			if client then
				client:stop()
			end
		end

		-- Check if client is active
		lsp.is_client_active = function(client_id)
			local client = vim.lsp.get_client_by_id(client_id)
			return client and client.initialized
		end

		-- ============================================================================
		-- Ruby Project Module - Business logic for Ruby projects
		-- ============================================================================
		local ruby_project = {}

		-- State tracking
		ruby_project.state = {
			projects = {}, -- project_root -> { client_id, env_type }
			buffers = {}, -- buffer_number -> project_root
		}

		-- Find Ruby project root from a file path
		ruby_project.find_root = function(filepath)
			local dir = vim.fn.fnamemodify(filepath, ":p:h")

			while dir ~= "/" do
				-- Check for Ruby project markers
				if
					vim.fn.filereadable(dir .. "/Gemfile") == 1
					or vim.fn.filereadable(dir .. "/.ruby-version") == 1
					or vim.fn.filereadable(dir .. "/config.ru") == 1
					or shadowenv.has_shadowenv(dir)
				then
					return dir
				end
				dir = vim.fn.fnamemodify(dir, ":h")
			end

			return nil
		end

		-- Build LSP configuration for a Ruby project
		ruby_project.build_lsp_config = function(project_root, bufnr)
			local config = {
				name = "ruby_lsp_" .. project_root:gsub("[/\\]", "_"),
				cmd = { "ruby-lsp" },
				root_dir = project_root,
				bufnr = bufnr,
				capabilities = lsp.make_capabilities(),
				init_options = {
					formatter = "auto",
					experimentalFeaturesEnabled = true,
				},
				on_attach = function(_, attached_bufnr)
					-- Ruby-specific keybindings
					vim.keymap.set("n", "<leader>lcr", function()
						vim.lsp.buf_request(attached_bufnr, "workspace/executeCommand", {
							command = "rubyLsp/showRailsRoutes",
							arguments = {},
						})
					end, { buffer = attached_bufnr, desc = "Show Rails routes" })
				end,
			}

			-- Try to load shadowenv
			local env_type = "system"
			local environment = shadowenv.load_environment(project_root)

			if environment then
				local ruby_paths = shadowenv.get_ruby_paths(environment)
				if ruby_paths then
					-- Check if ruby-lsp exists in the shadowenv path
					local ruby_lsp_exists = vim.fn.filereadable(ruby_paths.ruby_lsp) == 1
					
					if not ruby_lsp_exists then
						-- Try to use the ruby-lsp from the project's .ruby-lsp directory
						-- This requires running bundle install in .ruby-lsp first
						vim.notify(
							"ruby-lsp not found in shadowenv. Please run:\n" ..
							"cd " .. project_root .. "/.ruby-lsp && bundle install",
							vim.log.levels.WARN
						)
						
						-- Use the shadowenv ruby to run ruby-lsp
						config.cmd = { 
							environment.PATH:match("([^:]+)/bin") .. "/ruby",
							"-S", "ruby-lsp"
						}
					else
						config.cmd = { ruby_paths.ruby_lsp }
					end
					
					config.cmd_env = {
						GEM_HOME = ruby_paths.gem_home,
						GEM_PATH = ruby_paths.gem_path,
						BUNDLE_APP_CONFIG = ruby_paths.bundle_app_config,
						BUNDLE_GEMFILE = project_root .. "/.ruby-lsp/Gemfile",
						PATH = ruby_paths.path,
					}
					env_type = "shadowenv"
				end
			end

			return config, env_type
		end

		-- Ensure a project has an LSP client
		ruby_project.ensure_lsp = function(project_root, bufnr)
			local project = ruby_project.state.projects[project_root]

			-- Try to reuse existing client
			if project and lsp.is_client_active(project.client_id) then
				if lsp.attach_client(project.client_id, bufnr) then
					return
				end
			end

			-- Create new client
			local config, env_type = ruby_project.build_lsp_config(project_root, bufnr)
			local client_id = lsp.create_client(config)

			if client_id then
				ruby_project.state.projects[project_root] = {
					client_id = client_id,
					env_type = env_type,
				}
				vim.notify(
					string.format(
						"Ruby LSP started for %s (env: %s)",
						vim.fn.fnamemodify(project_root, ":~"),
						env_type
					),
					vim.log.levels.INFO
				)
			end
		end

		-- Clean up unused projects
		ruby_project.cleanup = function()
			local active_projects = {}
			for _, project_root in pairs(ruby_project.state.buffers) do
				active_projects[project_root] = true
			end

			for project_root, project in pairs(ruby_project.state.projects) do
				if not active_projects[project_root] then
					lsp.stop_client(project.client_id)
					ruby_project.state.projects[project_root] = nil
				end
			end
		end

		-- ============================================================================
		-- Main Setup
		-- ============================================================================
		-- Handle Ruby files
		vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
			pattern = { "*.rb", "*.rake", "Gemfile", "Rakefile", "*.gemspec", "*.ru", "*.erb" },
			callback = function(args)
				local filepath = args.file
				if not filepath or filepath == "" then
					return
				end

				-- Debug logging
				if vim.g.ruby_shadowenv_debug then
					vim.notify(string.format("Ruby file opened: %s", filepath), vim.log.levels.INFO)
				end

				local project_root = ruby_project.find_root(filepath)
				if project_root then
					if vim.g.ruby_shadowenv_debug then
						vim.notify(string.format("Found project root: %s", project_root), vim.log.levels.INFO)
					end
					ruby_project.state.buffers[args.buf] = project_root
					ruby_project.ensure_lsp(project_root, args.buf)
				else
					if vim.g.ruby_shadowenv_debug then
						vim.notify("No Ruby project root found", vim.log.levels.WARN)
					end
				end
			end,
			group = vim.api.nvim_create_augroup("ruby_shadowenv_lsp", { clear = true }),
			desc = "Setup Ruby LSP with shadowenv support",
		})

		-- Cleanup when buffers close
		vim.api.nvim_create_autocmd("BufDelete", {
			callback = function(args)
				ruby_project.state.buffers[args.buf] = nil
				vim.defer_fn(ruby_project.cleanup, 1000)
			end,
			group = vim.api.nvim_create_augroup("ruby_shadowenv_lsp_cleanup", { clear = true }),
			desc = "Cleanup unused Ruby LSP instances",
		})

		-- Status command
		vim.api.nvim_create_user_command("RubyShadowenvStatus", function()
			local lines = { "Ruby Shadowenv LSP Status:", "" }

			for root, project in pairs(ruby_project.state.projects) do
				local active = lsp.is_client_active(project.client_id)

				table.insert(lines, string.format("• %s", vim.fn.fnamemodify(root, ":~")))
				table.insert(lines, string.format("  Status: %s", active and "active" or "inactive"))
				table.insert(lines, string.format("  Environment: %s", project.env_type))
				table.insert(lines, "")
			end

			if vim.tbl_isempty(ruby_project.state.projects) then
				table.insert(lines, "No active Ruby projects")
			end

			vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
		end, { desc = "Show Ruby shadowenv LSP status" })

		-- Force reload shadowenv for current buffer
		vim.api.nvim_create_user_command("RubyShadowenvReload", function()
			local bufnr = vim.api.nvim_get_current_buf()
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			if not filepath or filepath == "" then
				vim.notify("No file in current buffer", vim.log.levels.WARN)
				return
			end

			local project_root = ruby_project.find_root(filepath)
			if not project_root then
				vim.notify("No Ruby project found", vim.log.levels.WARN)
				return
			end

			-- Stop existing client if any
			local project = ruby_project.state.projects[project_root]
			if project then
				lsp.stop_client(project.client_id)
			end

			-- Restart LSP
			ruby_project.ensure_lsp(project_root, bufnr)
		end, { desc = "Reload Ruby shadowenv LSP for current buffer" })

		-- Install ruby-lsp in the current project
		vim.api.nvim_create_user_command("RubyShadowenvInstallLsp", function()
			local bufnr = vim.api.nvim_get_current_buf()
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			if not filepath or filepath == "" then
				vim.notify("No file in current buffer", vim.log.levels.WARN)
				return
			end

			local project_root = ruby_project.find_root(filepath)
			if not project_root then
				vim.notify("No Ruby project found", vim.log.levels.WARN)
				return
			end

			-- Check if .ruby-lsp directory exists
			local ruby_lsp_dir = project_root .. "/.ruby-lsp"
			if vim.fn.isdirectory(ruby_lsp_dir) == 1 then
				vim.notify("Installing ruby-lsp in " .. ruby_lsp_dir .. "...", vim.log.levels.INFO)
				vim.fn.jobstart(
					"cd " .. vim.fn.shellescape(ruby_lsp_dir) .. " && bundle install",
					{
						on_exit = function(_, exit_code)
							if exit_code == 0 then
								vim.notify("ruby-lsp installed successfully! Reloading LSP...", vim.log.levels.INFO)
								-- Reload LSP
								local project = ruby_project.state.projects[project_root]
								if project then
									lsp.stop_client(project.client_id)
								end
								ruby_project.ensure_lsp(project_root, bufnr)
							else
								vim.notify("Failed to install ruby-lsp", vim.log.levels.ERROR)
							end
						end,
					}
				)
			else
				-- Create .ruby-lsp directory with Gemfile
				vim.notify("Creating .ruby-lsp directory...", vim.log.levels.INFO)
				vim.fn.mkdir(ruby_lsp_dir, "p")
				
				local gemfile_content = {
					'source "https://rubygems.org"',
					'',
					'gem "ruby-lsp", require: false, group: :development',
					'gem "ruby-lsp-rails", require: false, group: :development',
				}
				
				vim.fn.writefile(gemfile_content, ruby_lsp_dir .. "/Gemfile")
				vim.notify("Created .ruby-lsp/Gemfile. Run :RubyShadowenvInstallLsp again to install.", vim.log.levels.INFO)
			end
		end, { desc = "Install ruby-lsp in current project" })

		-- Toggle debug mode
		vim.api.nvim_create_user_command("RubyShadowenvDebugToggle", function()
			vim.g.ruby_shadowenv_debug = not vim.g.ruby_shadowenv_debug
			vim.notify("Ruby Shadowenv debug mode: " .. tostring(vim.g.ruby_shadowenv_debug), vim.log.levels.INFO)
		end, { desc = "Toggle Ruby shadowenv debug mode" })

		-- Debug command to check shadowenv setup
		vim.api.nvim_create_user_command("RubyShadowenvDebug", function()
			local bufnr = vim.api.nvim_get_current_buf()
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			
			local lines = { "Ruby Shadowenv Debug Info:", "" }
			
			-- Check current file
			table.insert(lines, "Current file: " .. (filepath or "none"))
			table.insert(lines, "")
			
			-- Check for shadowenv.vim plugin
			local has_shadowenv_plugin = vim.fn.exists(":ShadowenvHook") == 2
			table.insert(lines, "Shadowenv.vim plugin loaded: " .. tostring(has_shadowenv_plugin))
			table.insert(lines, "")
			
			if filepath and filepath ~= "" then
				-- Find project root
				local project_root = ruby_project.find_root(filepath)
				table.insert(lines, "Project root: " .. (project_root or "not found"))
				
				if project_root then
					-- Check for shadowenv
					local has_shadowenv = shadowenv.has_shadowenv(project_root)
					table.insert(lines, "Has .shadowenv.d: " .. tostring(has_shadowenv))
					
					-- Try to load environment
					table.insert(lines, "")
					table.insert(lines, "Loading shadowenv environment...")
					local env = shadowenv.load_environment(project_root)
					
					if env then
						table.insert(lines, "Environment loaded successfully")
						
						-- Check for Ruby paths
						local ruby_paths = shadowenv.get_ruby_paths(env)
						if ruby_paths then
							table.insert(lines, "")
							table.insert(lines, "Ruby paths found:")
							table.insert(lines, "  ruby-lsp: " .. ruby_paths.ruby_lsp)
							table.insert(lines, "  gem_home: " .. ruby_paths.gem_home)
							
							-- Check if ruby-lsp exists
							local ruby_lsp_exists = vim.fn.filereadable(ruby_paths.ruby_lsp) == 1
							table.insert(lines, "  ruby-lsp executable exists: " .. tostring(ruby_lsp_exists))
						else
							table.insert(lines, "No Ruby paths found in environment")
							table.insert(lines, "GEM_PATH: " .. (env.GEM_PATH or "not set"))
						end
					else
						table.insert(lines, "Failed to load shadowenv environment")
					end
					
					-- Check project state
					table.insert(lines, "")
					local project = ruby_project.state.projects[project_root]
					if project then
						table.insert(lines, "Project registered in state")
						table.insert(lines, "  Client ID: " .. tostring(project.client_id))
						table.insert(lines, "  Environment: " .. project.env_type)
						table.insert(lines, "  Client active: " .. tostring(lsp.is_client_active(project.client_id)))
					else
						table.insert(lines, "Project not registered in state")
					end
				end
			end
			
			-- Show all buffers tracked
			table.insert(lines, "")
			table.insert(lines, "Tracked buffers:")
			for buf, root in pairs(ruby_project.state.buffers) do
				table.insert(lines, string.format("  Buffer %d -> %s", buf, root))
			end
			
			vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
		end, { desc = "Debug Ruby shadowenv LSP setup" })
	end,
}