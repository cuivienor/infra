---
name: nix-development
description: Use when working with Nix, flakes, or NixOS configurations
---

# Nix Development

## When to Use

Use this skill when:
- Modifying flake.nix or NixOS configurations
- Adding packages to devShells
- Troubleshooting Nix build issues
- Working on the devbox container

## DevShell Selection

Choose the right shell for your task:

| Task | Shell | Command |
|------|-------|---------|
| Infrastructure (terraform, ansible) | default | `nix develop` |
| Go development (media-pipeline) | media-pipeline | `nix develop .#media-pipeline` |
| Bash development (session-manager) | session-manager | `nix develop .#session-manager` |

**With direnv:** Shells load automatically based on `.envrc` in each directory.

## Modifying flake.nix

### Add Package to DevShell

1. Find the relevant devShell in `flake.nix`
2. Add package to `buildInputs`:

```nix
devShells.${system} = {
  default = pkgsUnfree.mkShell {
    buildInputs = with pkgsUnfree; [
      # existing packages...
      newpackage    # Add here
    ];
  };
};
```

3. Reload environment:
```bash
direnv reload
# or exit and re-enter nix develop
```

### Add New DevShell

```nix
devShells.${system} = {
  # existing shells...

  new-shell = pkgs.mkShell {
    buildInputs = with pkgs; [
      package1
      package2
    ];
    shellHook = ''
      echo "New shell loaded"
    '';
  };
};
```

### Unfree Packages

Terraform and some other packages are unfree. Use `pkgsUnfree`:

```nix
# This is already defined in flake.nix
pkgsUnfree = import nixpkgs {
  inherit system;
  config.allowUnfree = true;
};

# Use pkgsUnfree instead of pkgs
default = pkgsUnfree.mkShell {
  buildInputs = with pkgsUnfree; [
    terraform  # unfree
  ];
};
```

## NixOS Configuration (devbox)

### Modify System Config

1. Edit `nixos/hosts/devbox/configuration.nix`
2. Rebuild:
```bash
# On devbox
sudo nixos-rebuild switch --flake .#devbox
```

### Modify User Config (Home-Manager)

1. Edit `home/users/cuiv.nix`
2. Rebuild (same command - Home-Manager is integrated):
```bash
sudo nixos-rebuild switch --flake .#devbox
```

## Debugging

### Check Flake Outputs

```bash
nix flake show
```

### Evaluate Expression

```bash
nix eval .#nixosConfigurations.devbox.config.services.openssh.enable
```

### Build Without Switching

```bash
nixos-rebuild build --flake .#devbox
```

### Why Is Package Included?

```bash
nix why-depends .#devShells.x86_64-linux.default nixpkgs#terraform
```

### Update Dependencies

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

## Common Patterns

### Format Nix Code

```bash
nixpkgs-fmt flake.nix
nixpkgs-fmt nixos/hosts/devbox/configuration.nix
```

### Check Syntax

```bash
nix flake check
```

### Rollback

If a rebuild breaks things:
```bash
sudo nixos-rebuild switch --rollback
```

## Workflow for flake.nix Changes

1. Make changes to flake.nix
2. Format: `nixpkgs-fmt flake.nix`
3. Check: `nix flake check`
4. Test shell: `nix develop` (or specific shell)
5. Commit flake.nix AND flake.lock together

## Never Do

- Edit flake.lock manually (it's auto-generated)
- Commit flake.nix without testing the shell first
- Forget to run rebuild after NixOS config changes
- Mix pkgs and pkgsUnfree for same package (use one consistently)
- Ignore flake check errors
