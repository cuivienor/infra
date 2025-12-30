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
      system = "x86_64-linux";

      # Rust overlay to get latest stable Rust (supports edition 2024)
      rustOverlay = import rust-overlay;

      # Overlay that adds zesh package
      zeshOverlay = final: prev: {
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
            nativeBuildInputs = [ prev.pkg-config ];
            buildInputs = [ prev.openssl ];
          };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rustOverlay
          zeshOverlay
        ];
      };

      # Allow unfree packages (terraform)
      pkgsUnfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          rustOverlay
          zeshOverlay
        ];
      };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        devbox = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/hosts/devbox/configuration.nix
            home-manager.nixosModules.home-manager
            {
              # Apply overlays so pkgs.zesh is available
              nixpkgs.overlays = [
                rustOverlay
                zeshOverlay
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

      # Make zesh buildable standalone
      packages.${system} = {
        inherit (pkgs) zesh;
        default = pkgs.zesh;
      };

      # Development shells
      devShells.${system} = {
        # Default: unified shell supporting all zones
        default = pkgsUnfree.mkShell {
          buildInputs = with pkgsUnfree; [
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
            pkg-config
            openssl

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
            echo ""
          '';
        };

      };
    };
}
