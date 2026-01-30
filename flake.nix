{
  description = "Personal infrastructure monorepo - NixOS and Home-Manager configurations";

  inputs = {
    # NixOS 25.11 stable (current as of Dec 2025)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Home-Manager (matching NixOS version)
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust packaging
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust overlay for latest stable Rust (supports edition 2024)
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zjstatus - zellij status bar plugin
    zjstatus = {
      url = "github:dj95/zjstatus";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixCats - Neovim configuration framework
    nixCats.url = "github:BirdeeHub/nixCats-nvim";

    # sops-nix - Secrets management for NixOS
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code - pre-built native binaries from official releases
    claude-code-overlay = {
      url = "github:ryoppippi/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      naersk,
      rust-overlay,
      sops-nix,
      claude-code-overlay,
      ...
    }@inputs:
    let
      # Supported systems for Home Manager portability
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Helper to generate attrs for all systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Rust overlay to get latest stable Rust (supports edition 2024)
      rustOverlay = import rust-overlay;

      # Local packages overlay - all custom packages defined in this repo
      # Use this pattern instead of per-app overlays for simplicity
      localPackagesOverlay = final: prev: {
        # Rust: zellij session manager
        zesh =
          let
            rustToolchain = prev.rust-bin.stable.latest.default;
            naersk' = prev.callPackage naersk {
              cargo = rustToolchain;
              rustc = rustToolchain;
            };
          in
          naersk'.buildPackage {
            src = ./apps/zesh;
          };

        # Python: Bulgarian audiobook downloader
        gramofonche-downloader = prev.python3Packages.buildPythonApplication {
          pname = "gramofonche-downloader";
          version = "0.1.0";
          src = ./apps/gramofonche-downloader;
          format = "pyproject";

          build-system = [ prev.python3Packages.setuptools ];

          dependencies = with prev.python3Packages; [
            requests
            beautifulsoup4
            mutagen
          ];

          # Tests run during nix build
          nativeCheckInputs = with prev.python3Packages; [
            pytestCheckHook
            pytest
          ];

          meta = {
            description = "Download Bulgarian audiobooks from gramofonche.chitanka.info";
            mainProgram = "gramofonche-downloader";
          };
        };

        # Python: Personal health data library (Garmin + Strava)
        healthlib = prev.python3Packages.buildPythonApplication {
          pname = "healthlib";
          version = "0.1.0";
          src = ./apps/healthlib;
          format = "pyproject";

          build-system = [ prev.python3Packages.setuptools ];

          dependencies = with prev.python3Packages; [
            garminconnect
            garth
            requests
            pyyaml
          ];

          # Tests run during nix build
          nativeCheckInputs = with prev.python3Packages; [
            pytestCheckHook
            pytest
          ];

          meta = {
            description = "Personal library for interacting with Garmin and Strava APIs";
            mainProgram = "healthlib";
          };
        };
      };

      # Generate pkgs for a given system
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            rustOverlay
            localPackagesOverlay
            claude-code-overlay.overlays.default
          ];
        };

      # Generate pkgs with unfree allowed for a given system
      pkgsUnfreeFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            rustOverlay
            localPackagesOverlay
            claude-code-overlay.overlays.default
          ];
        };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        devbox = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/hosts/devbox/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              # Apply overlays so local packages (pkgs.zesh, etc.) are available
              nixpkgs.overlays = [
                rustOverlay
                localPackagesOverlay
                claude-code-overlay.overlays.default
              ];

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.cuiv = {
                  imports = [
                    ./home/users/cuiv/default.nix
                    ./home/profiles/ai-tools/default.nix
                    ./home/profiles/identity/personal.nix
                  ];
                };
                extraSpecialArgs = { inherit inputs; };
              };
            }
          ];
        };
      };

      # Standalone Home Manager configurations (for non-NixOS: Arch, macOS, etc.)
      homeConfigurations = {
        # Universal config - works on any system
        # Usage: home-manager switch --flake .#cuiv
        cuiv = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-linux"; # Default, can override with --override-input
          modules = [
            ./home/users/cuiv/default.nix
            ./home/profiles/ai-tools/default.nix
            ./home/profiles/identity/personal.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/home/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        # Explicit per-system configs if needed
        "cuiv@x86_64-linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-linux";
          modules = [
            ./home/users/cuiv/default.nix
            ./home/profiles/ai-tools/default.nix
            ./home/profiles/identity/personal.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/home/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        "cuiv@aarch64-darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "aarch64-darwin";
          modules = [
            ./home/users/cuiv/default.nix
            ./home/profiles/ai-tools/default.nix
            ./home/profiles/identity/personal.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/Users/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        # Work MacBook with Shopify profile
        # No ai-tools - Claude managed by Shopify
        "cuiv@work-macbook" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "aarch64-darwin";
          modules = [
            ./home/users/cuiv/default.nix
            ./home/profiles/identity/shopify.nix
            ./home/profiles/shell-env/shopify.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/Users/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };

        "cuiv@x86_64-darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-darwin";
          modules = [
            ./home/users/cuiv/default.nix
            ./home/profiles/ai-tools/default.nix
            ./home/profiles/identity/personal.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/Users/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Make packages buildable standalone (for all systems)
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs) zesh gramofonche-downloader healthlib;
          default = pkgs.zesh;
        }
      );

      # Development shells
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsUnfreeFor system;

          # Script to restore secrets from Bitwarden
          infra-setup-secrets = pkgs.writeShellApplication {
            name = "infra-setup-secrets";
            runtimeInputs = with pkgs; [
              bitwarden-cli
              coreutils
            ];
            text = ''
              set -euo pipefail

              REPO_ROOT="''${INFRA_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"
              SOPS_KEY="$REPO_ROOT/terraform/.sops-key"
              VAULT_PASS="$REPO_ROOT/ansible/.vault_pass"

              # Check for BW_SESSION
              if [[ -z "''${BW_SESSION:-}" ]]; then
                echo "Error: BW_SESSION environment variable not set."
                echo ""
                echo "Run these commands first:"
                echo "  bw login                              # if not logged in"
                echo "  export BW_SESSION=\$(bw unlock --raw)  # unlock vault"
                echo ""
                echo "Then run this script again."
                exit 1
              fi

              # Verify session is valid
              if ! bw status --session "$BW_SESSION" 2>/dev/null | grep -q '"status":"unlocked"'; then
                echo "Error: Bitwarden session is invalid or expired."
                echo ""
                echo "Run: export BW_SESSION=\$(bw unlock --raw)"
                echo "Then run this script again."
                exit 1
              fi

              echo "Restoring secrets from Bitwarden..."
              echo ""

              # SOPS age key
              if [[ -f "$SOPS_KEY" ]]; then
                echo "✓ SOPS age key already exists (terraform/.sops-key)"
              else
                echo "  Fetching SOPS age key..."
                if bw get notes "homelab-sops-age-key" --session "$BW_SESSION" > "$SOPS_KEY" 2>/dev/null; then
                  chmod 600 "$SOPS_KEY"
                  echo "✓ Restored SOPS age key to terraform/.sops-key"
                else
                  echo "✗ Could not find 'homelab-sops-age-key' in Bitwarden"
                fi
              fi

              # Ansible vault password
              if [[ -f "$VAULT_PASS" ]]; then
                echo "✓ Ansible vault password already exists (ansible/.vault_pass)"
              else
                echo "  Fetching Ansible vault password..."
                if bw get notes "homelab-ansible-vault-pass" --session "$BW_SESSION" > "$VAULT_PASS" 2>/dev/null; then
                  chmod 600 "$VAULT_PASS"
                  echo "✓ Restored Ansible vault password to ansible/.vault_pass"
                else
                  echo "✗ Could not find 'homelab-ansible-vault-pass' in Bitwarden"
                fi
              fi

              echo ""
              echo "Done! Run 'direnv allow' to load environment variables."
            '';
          };
        in
        {
          # Default: unified shell supporting all zones
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              # Infra scripts
              infra-setup-secrets

              # Infrastructure as Code
              terraform
              ansible
              ansible-lint

              # Secrets management
              sops
              age

              # Nix tooling
              deadnix
              statix
              nixfmt-rfc-style
              nil # Nix LSP

              # Utilities
              jq
              yq-go
              shellcheck
              shfmt
              pre-commit
              stow

              # Secret scanning
              trufflehog
              gitleaks

              # Password management (for pulling secrets)
              bitwarden-cli

              # Go development (media-pipeline)
              go
              gopls
              gotools
              go-tools # staticcheck

              # Rust development (zesh)
              rust-bin.stable.latest.default
              rust-bin.stable.latest.rust-analyzer

              # Python development (gramofonche-downloader, healthlib)
              python3
              python3Packages.ruff
              python3Packages.mypy
              python3Packages.pytest
              python3Packages.types-requests
              python3Packages.types-beautifulsoup4
              python3Packages.garminconnect
              python3Packages.garth
              python3Packages.pyyaml

              # Network debugging (infra-specific)
              openssl
              dnsutils

              # Runtime deps for zesh testing
              zellij
              fzf
            ];

            shellHook = ''
              echo "🏗️  Infra devShell loaded (unified)"
              echo "   Terraform: $(terraform version -json | jq -r '.terraform_version')"
              echo "   Ansible:   $(ansible --version | head -1)"
              echo "   Go:        $(go version | cut -d' ' -f3)"
              echo "   Rust:      $(rustc --version | cut -d' ' -f2)"
              echo "   Python:    $(python3 --version | cut -d' ' -f2)"
              echo ""
            '';
          };
        }
      );
    };
}
