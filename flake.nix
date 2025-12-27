{
  description = "Personal infrastructure monorepo - NixOS and Home-Manager configurations";

  inputs = {
    # NixOS 24.11 stable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Home-Manager (matching NixOS version)
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust packaging
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      naersk,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # Overlay that adds zesh package
      zeshOverlay = final: prev: {
        zesh =
          let
            naersk' = prev.callPackage naersk { };
          in
          naersk'.buildPackage {
            src = ./apps/zesh;
            nativeBuildInputs = [ prev.pkg-config ];
            buildInputs = [ prev.openssl ];
          };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ zeshOverlay ];
      };

      # Allow unfree packages (terraform)
      pkgsUnfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ zeshOverlay ];
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
              # Apply overlay so pkgs.zesh is available
              nixpkgs.overlays = [ zeshOverlay ];

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.cuiv = import ./home/users/cuiv/default.nix;
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
        # Default: infrastructure work (terraform, ansible, etc.)
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
            pre-commit

            # Secret scanning
            trufflehog
            gitleaks
          ];

          shellHook = ''
            echo "🏗️  Infra devShell loaded"
            echo "   Terraform: $(terraform version -json | jq -r '.terraform_version')"
            echo "   Ansible:   $(ansible --version | head -1)"
            echo ""
          '';
        };

        # Go development for media-pipeline
        media-pipeline = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            gotools
            go-tools # staticcheck
          ];

          shellHook = ''
            echo "🎬 Media Pipeline devShell loaded"
            echo "   Go: $(go version | cut -d' ' -f3)"
            echo ""
          '';
        };

        # Bash development for session-manager
        session-manager = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            shellcheck
            shfmt
          ];

          shellHook = ''
            echo "📺 Session Manager devShell loaded"
            echo ""
          '';
        };

        # Rust development for zesh
        zesh = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain
            rustc
            cargo
            rust-analyzer
            clippy
            rustfmt

            # Build dependencies
            pkg-config
            openssl

            # Runtime deps for testing
            zellij
            fzf
          ];

          shellHook = ''
            echo "🎯 Zesh devShell loaded"
            echo "   Rust: $(rustc --version | cut -d' ' -f2)"
            echo "   Cargo: $(cargo --version | cut -d' ' -f2)"
            echo ""
          '';
        };
      };
    };
}
