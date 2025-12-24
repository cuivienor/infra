# NixOS Zone

Zone-specific guidance for working with Nix, NixOS, and Home-Manager in this monorepo.

## Flake Structure

The root `flake.nix` defines everything:

```
infra/
├── flake.nix              # Main flake - NixOS configs + devShells
├── flake.lock             # Pinned dependency versions
├── nixos/
│   └── hosts/
│       └── devbox/
│           └── configuration.nix    # NixOS system config
└── home/
    ├── users/
    │   └── cuiv.nix       # Home-Manager user config
    └── profiles/          # Modular config profiles (future)
```

## DevShells

Three development shells are available:

| Shell | Use Case | Tools |
|-------|----------|-------|
| `default` | Infrastructure work | terraform, ansible, sops, age, shellcheck |
| `media-pipeline` | Go development | go, gopls, gotools |
| `session-manager` | Bash development | bash, shellcheck, shfmt |

Enter shells:
```bash
# Default (auto via direnv in repo root)
direnv allow
# or
nix develop

# Zone-specific
nix develop .#media-pipeline
nix develop .#session-manager
```

## NixOS Configuration

**devbox** is the only NixOS host currently:

```nix
# nixos/hosts/devbox/configuration.nix
{
  boot.isContainer = true;           # Required for LXC
  networking = {
    hostName = "devbox";
    interfaces.eth0.ipv4.addresses = [...];
  };
  services.openssh.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

## Home-Manager Integration

Home-Manager is integrated as a NixOS module:

```nix
# In flake.nix
home-manager.nixosModules.home-manager
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.cuiv = import ./home/users/cuiv.nix;
}
```

User config in `home/users/cuiv.nix`:
```nix
{ config, pkgs, ... }: {
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";
  programs.git = { ... };
  programs.direnv.enable = true;
  home.stateVersion = "24.11";
}
```

## Rebuilding

From the devbox container:

```bash
# Switch to new configuration
sudo nixos-rebuild switch --flake .#devbox

# Build without switching (test)
nixos-rebuild build --flake .#devbox

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

## Common Patterns

### Adding a Package to DevShell

```nix
# In flake.nix, find the relevant devShell
devShells.${system} = {
  default = pkgsUnfree.mkShell {
    buildInputs = with pkgsUnfree; [
      # Add new package here
      newpackage
    ];
  };
};
```

Then: `direnv reload` or re-enter `nix develop`

### Adding a System Package (devbox)

```nix
# In nixos/hosts/devbox/configuration.nix
environment.systemPackages = with pkgs; [
  newpackage
];
```

Then: `sudo nixos-rebuild switch --flake .#devbox`

### Adding a User Package (Home-Manager)

```nix
# In home/users/cuiv.nix
home.packages = with pkgs; [
  newpackage
];
```

Then: `sudo nixos-rebuild switch --flake .#devbox`

## Allowing Unfree Packages

Terraform is unfree. The flake handles this:

```nix
pkgsUnfree = import nixpkgs {
  inherit system;
  config.allowUnfree = true;
};
```

Use `pkgsUnfree` instead of `pkgs` when adding unfree packages.

## Debugging

### Check Flake Outputs
```bash
nix flake show
```

### Evaluate Without Building
```bash
nix eval .#nixosConfigurations.devbox.config.system.stateVersion
```

### Build Specific Output
```bash
nix build .#nixosConfigurations.devbox.config.system.build.toplevel
```

### Check Why Package Is Included
```bash
nix why-depends .#nixosConfigurations.devbox.config.system.build.toplevel nixpkgs#package
```

## Common Pitfalls

1. **Flake not updating**: Run `nix flake update` to update flake.lock, or `nix flake lock --update-input nixpkgs` for specific input.

2. **Permission denied on rebuild**: Must run `nixos-rebuild` with `sudo` for system changes.

3. **Home-Manager conflicts**: If both NixOS and Home-Manager try to manage same file, one wins. Use `home-manager.useGlobalPkgs = true` for consistency.

4. **Unfree package blocked**: Add to `pkgsUnfree` instead of `pkgs` in flake.

5. **Old generation still active**: After rebuild, old configs persist until reboot for some services. Check `nixos-rebuild switch` output for warnings.

## Key Files

- `flake.nix` - Main entry point, devShells, NixOS configs
- `flake.lock` - Pinned versions (commit changes to this)
- `nixos/hosts/devbox/configuration.nix` - devbox system config
- `home/users/cuiv.nix` - User environment config
