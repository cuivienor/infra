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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      naersk,
      rust-overlay,
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
      };

      # Generate pkgs for a given system
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            rustOverlay
            localPackagesOverlay
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
            home-manager.nixosModules.home-manager
            {
              # Apply overlays so local packages (pkgs.zesh, etc.) are available
              nixpkgs.overlays = [
                rustOverlay
                localPackagesOverlay
              ];

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.cuiv = import ./home/users/cuiv/default.nix;
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
          inherit (pkgs) zesh gramofonche-downloader;
          default = pkgs.zesh;
        }
      );

      # Development shells (Linux only - infra tools)
      devShells.x86_64-linux = {
        # Default: unified shell supporting all zones
        default = (pkgsUnfreeFor "x86_64-linux").mkShell {
          buildInputs = with (pkgsUnfreeFor "x86_64-linux"); [
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

            # Go development (media-pipeline)
            go
            gopls
            gotools
            go-tools # staticcheck

            # Rust development (zesh)
            rust-bin.stable.latest.default
            rust-bin.stable.latest.rust-analyzer

            # Python development (gramofonche-downloader)
            python3
            python3Packages.ruff
            python3Packages.mypy
            python3Packages.pytest
            python3Packages.types-requests
            python3Packages.types-beautifulsoup4

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
      };
    };
}
