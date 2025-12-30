# Neovim configuration using nixCats
# See: https://nixcats.org/
{
  config,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixCats) utils;
in
{
  imports = [
    inputs.nixCats.homeModule
  ];

  config = {
    nixCats = {
      enable = true;

      # Add standard plugin overlay
      addOverlays = [
        (utils.standardPluginOverlay inputs)
      ];

      # Install this package
      packageNames = [ "nvim" ];

      # Point to our Lua config directory
      luaPath = ./neovim;

      # Category definitions - what plugins/tools are available
      categoryDefinitions.replace =
        {
          pkgs,
          settings,
          categories,
          extra,
          name,
          mkPlugin,
          ...
        }:
        {
          # LSP servers and runtime tools (available in PATH within neovim)
          lspsAndRuntimeDeps = {
            core = with pkgs; [
              # Build tools
              gcc
              gnumake

              # Search tools (for telescope)
              ripgrep
              fd
            ];

            lsp = with pkgs; [
              # Lua
              lua-language-server
              # Nix
              nil
              # Bash
              bash-language-server
              # Python
              pyright
              ruff
              # C/C++
              clang-tools # includes clangd
              # Infrastructure
              terraform-ls
              # ansible-language-server removed from nixpkgs
              cmake-language-server
            ];

            formatters = with pkgs; [
              stylua
              shfmt
              prettierd
              nodePackages.prettier
              yamlfix
              ruff
              nixfmt-rfc-style
            ];

            linters = with pkgs; [
              shellcheck
              yamllint
              tflint
              markdownlint-cli
            ];

            debug = with pkgs; [
              delve # Go debugger
              lldb # C/C++/Rust debugger
              python3Packages.debugpy
            ];
          };

          # Plugins loaded at startup
          startupPlugins = {
            core = with pkgs.vimPlugins; [
              # Required by many plugins
              plenary-nvim
              nvim-web-devicons

              # Lazy loading
              lze
              lzextras

              # Theme
              catppuccin-nvim
            ];

            completion = with pkgs.vimPlugins; [
              nvim-cmp
              cmp-nvim-lsp
              cmp-path
              cmp_luasnip
              luasnip
              friendly-snippets
            ];

            lsp = with pkgs.vimPlugins; [
              nvim-lspconfig
              fidget-nvim
              lazydev-nvim
            ];

            treesitter = with pkgs.vimPlugins; [
              nvim-treesitter.withAllGrammars
              nvim-treesitter-textobjects
            ];
          };

          # Plugins that can be lazy-loaded
          optionalPlugins = {
            ui = with pkgs.vimPlugins; [
              noice-nvim
              nvim-notify
              nui-nvim
              which-key-nvim
              indent-blankline-nvim
              mini-nvim
            ];

            navigation = with pkgs.vimPlugins; [
              telescope-nvim
              telescope-fzf-native-nvim
              telescope-ui-select-nvim
              oil-nvim
              zellij-nav-nvim
            ];

            git = with pkgs.vimPlugins; [
              gitsigns-nvim
              octo-nvim
            ];

            format = with pkgs.vimPlugins; [
              conform-nvim
              nvim-lint
            ];

            debug = with pkgs.vimPlugins; [
              nvim-dap
              nvim-dap-ui
              nvim-nio
              nvim-dap-go
              nvim-dap-python
              nvim-dap-virtual-text
            ];

            editor = with pkgs.vimPlugins; [
              nvim-autopairs
              comment-nvim
              vim-sleuth
              todo-comments-nvim
            ];
          };

          # Shared libraries for LD_LIBRARY_PATH
          sharedLibraries = {
            general = with pkgs; [ ];
          };

          # Environment variables
          environmentVariables = { };

          # Python libraries
          python3.libraries = { };

          # Extra wrapper args
          extraWrapperArgs = { };
        };

      # Package definitions - how to build the neovim package
      packageDefinitions.replace = {
        nvim =
          { pkgs, name, ... }:
          {
            settings = {
              # Add tools to PATH
              suffix-path = true;
              suffix-LD = true;
              # Wrap our Lua config
              wrapRc = true;
              # Aliases
              aliases = [
                "vim"
                "vi"
              ];
              # Enable host programs
              hosts.python3.enable = true;
              hosts.node.enable = true;
            };

            # Enable these categories
            categories = {
              # Core functionality
              core = true;
              completion = true;
              lsp = true;
              treesitter = true;

              # UI enhancements
              ui = true;

              # Navigation
              navigation = true;

              # Git integration
              git = true;

              # Formatting and linting
              format = true;
              formatters = true;
              linters = true;

              # Debugging
              debug = true;

              # Editor polish
              editor = true;
            };

            # Extra values accessible via nixCats.extra()
            extra = {
              # For nixd LSP configuration
              nixdExtras.nixpkgs = ''import ${pkgs.path} {}'';
            };
          };
      };
    };
  };
}
