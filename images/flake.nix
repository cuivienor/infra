{
  description = "Infrastructure images - LXC templates, VMs, etc.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      ...
    }:
    let
      system = "x86_64-linux";

      # Snapshot of the infra repo to bake in
      infraRepo = builtins.path {
        path = ./..;
        name = "infra-repo";
        # Exclude .git and other large/unnecessary dirs
        filter =
          path: type:
          let
            baseName = baseNameOf path;
          in
          !(baseName == ".git" || baseName == "result" || baseName == ".direnv");
      };
    in
    {
      packages.${system} = {
        lxc-devbox-bootstrap = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox-lxc";
          modules = [
            ../nixos/hosts/bootstrap/configuration.nix
            (
              { pkgs, ... }:
              {
                # Fix for networkd requiring interface on defaultGateway
                networking.defaultGateway = {
                  address = "192.168.1.1";
                  interface = "eth0";
                };

                # Bake the repo into /home/cuiv/infra
                system.activationScripts.infraRepo = ''
                  mkdir -p /home/cuiv
                  if [ ! -d /home/cuiv/infra ]; then
                    cp -r ${infraRepo} /home/cuiv/infra
                    chown -R cuiv:users /home/cuiv/infra
                    chmod -R u+w /home/cuiv/infra
                  fi
                '';
              }
            )
          ];
        };

        # Convenience alias
        default = self.packages.${system}.lxc-devbox-bootstrap;
      };
    };
}
