# Images Zone

Build infrastructure for creating machine images (LXC templates, VMs, Docker images).

## Current Outputs

- `lxc-devbox-bootstrap` - Minimal NixOS LXC template for devbox recovery

## Building Locally

```bash
# Build the devbox bootstrap template
nix build ./images#lxc-devbox-bootstrap

# Output: result/tarball/nixos-system-devbox-*.tar.xz
```

## How It Works

1. `flake.nix` uses nixos-generators to build LXC templates
2. Templates reference NixOS configs from `../nixos/hosts/`
3. GitHub Actions builds on push and uploads to releases
4. Terraform downloads from releases for provisioning

## Adding New Templates

1. Create NixOS config in `nixos/hosts/<name>/configuration.nix`
2. Add output to `images/flake.nix`
3. Update GitHub Actions workflow if needed
