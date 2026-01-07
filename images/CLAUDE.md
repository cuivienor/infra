# Images Zone

Nix LXC template builds via nixos-generators.

## BUILD

```bash
nix build ./images#lxc-devbox-bootstrap
# Output: result/tarball/nixos-system-devbox-*.tar.xz
```

## WORKFLOW

1. `images/flake.nix` → nixos-generators
2. References `nixos/hosts/` configs
3. Terraform downloads for provisioning

## ADDING TEMPLATES

1. Create `nixos/hosts/<name>/configuration.nix`
2. Add output to `images/flake.nix`
