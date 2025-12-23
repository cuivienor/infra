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
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.cuiv = import ./home/users/cuiv.nix;
            }
          ];
        };
      };

      # Development shell for working with this repo
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixpkgs-fmt
          nil  # Nix LSP
        ];
      };
    };
}
