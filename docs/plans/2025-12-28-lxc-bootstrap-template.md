# LXC Bootstrap Template Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a custom NixOS LXC template with SSH keys and infra repo baked in, ensuring devbox is never inaccessible after a failed nixos-rebuild.

**Architecture:** A minimal NixOS configuration (`nixos/hosts/bootstrap/`) defines the recovery environment. A separate `images/` zone uses nixos-generators to build the LXC template. GitHub Actions builds on push and uploads to a public release. Terraform downloads the template and uses it for devbox provisioning.

**Tech Stack:** NixOS, nixos-generators, GitHub Actions, Terraform (bpg/proxmox provider)

---

## Task 1: Create Bootstrap NixOS Configuration

**Files:**
- Create: `nixos/hosts/bootstrap/configuration.nix`

**Step 1: Create the bootstrap configuration**

```nix
{ modulesPath, pkgs, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  # Container basics
  boot.isContainer = true;
  system.stateVersion = "24.11";

  # Static networking (matches devbox)
  networking = {
    hostName = "devbox";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.1.140";
      prefixLength = 24;
    }];
    defaultGateway = "192.168.1.1";
    nameservers = [ "192.168.1.102" "192.168.1.110" "1.1.1.1" ];
  };

  # SSH - the critical part
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Users with SSH keys
  users.users = {
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
    ];
    cuiv = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
      ];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  # Minimal packages for comfortable recovery
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    ripgrep
    fd
    tree
    jq
  ];

  # Nix with flakes
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "cuiv" ];
  };
}
```

**Step 2: Verify syntax**

Run: `nix-instantiate --parse nixos/hosts/bootstrap/configuration.nix`
Expected: No errors, outputs parsed expression

**Step 3: Commit**

```bash
git add nixos/hosts/bootstrap/configuration.nix
git commit -m "feat(nixos): add bootstrap configuration for LXC template"
```

---

## Task 2: Create Images Zone Structure

**Files:**
- Create: `images/CLAUDE.md`
- Create: `images/flake.nix`

**Step 1: Create images zone CLAUDE.md**

```markdown
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
```

**Step 2: Create images flake.nix**

```nix
{
  description = "Infrastructure images - LXC templates, VMs, etc.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      system = "x86_64-linux";

      # Snapshot of the infra repo to bake in
      infraRepo = builtins.path {
        path = ./..;
        name = "infra-repo";
        # Exclude .git and other large/unnecessary dirs
        filter = path: type:
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
            ({ pkgs, ... }: {
              # Bake the repo into /home/cuiv/infra
              system.activationScripts.infraRepo = ''
                mkdir -p /home/cuiv
                if [ ! -d /home/cuiv/infra ]; then
                  cp -r ${infraRepo} /home/cuiv/infra
                  chown -R cuiv:users /home/cuiv/infra
                  chmod -R u+w /home/cuiv/infra
                fi
              '';
            })
          ];
        };
      };

      # Convenience alias
      packages.${system}.default = self.packages.${system}.lxc-devbox-bootstrap;
    };
}
```

**Step 3: Verify flake builds (dry-run)**

Run: `nix flake check ./images`
Expected: No errors

**Step 4: Commit**

```bash
git add images/CLAUDE.md images/flake.nix
git commit -m "feat(images): add images zone with nixos-generators flake"
```

---

## Task 3: Test Local Template Build

**Files:**
- None (verification only)

**Step 1: Build the template locally**

Run: `nix build ./images#lxc-devbox-bootstrap --print-out-paths`
Expected: Outputs path like `/nix/store/...-tarball/nixos-system-devbox-....tar.xz`

Note: First build may take 5-10 minutes. Subsequent builds use cache.

**Step 2: Verify tarball exists**

Run: `ls -lh result/tarball/`
Expected: `.tar.xz` file, typically 300-500MB

**Step 3: Commit (no changes, just verification checkpoint)**

No commit needed - this was verification only.

---

## Task 4: Create GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/build-lxc-templates.yml`

**Step 1: Create the workflow file**

```yaml
name: Build LXC Templates

on:
  push:
    branches: [main]
    paths:
      - 'images/**'
      - 'nixos/hosts/bootstrap/**'
      - '.github/workflows/build-lxc-templates.yml'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@main

      - name: Setup Nix cache
        uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Build LXC template
        run: |
          nix build ./images#lxc-devbox-bootstrap
          cp result/tarball/*.tar.xz nixos-devbox-bootstrap.tar.xz

      - name: Get short SHA
        id: sha
        run: echo "short=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

      - name: Create/Update Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: lxc-templates-latest
          name: LXC Templates (Latest)
          body: |
            Auto-built LXC templates from commit ${{ steps.sha.outputs.short }}

            **Templates:**
            - `nixos-devbox-bootstrap.tar.xz` - Minimal NixOS devbox template

            **Derivation:** Built with nixos-generators proxmox-lxc format
          files: nixos-devbox-bootstrap.tar.xz
          make_latest: true
```

**Step 2: Verify workflow syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-lxc-templates.yml'))"`
Expected: No errors

**Step 3: Commit**

```bash
git add .github/workflows/build-lxc-templates.yml
git commit -m "ci: add GitHub Actions workflow for LXC template builds"
```

---

## Task 5: Create Terraform Template Resource

**Files:**
- Create: `terraform/proxmox-homelab/templates.tf`
- Modify: `terraform/proxmox-homelab/devbox.tf`

**Step 1: Create templates.tf**

```hcl
# LXC Templates downloaded from GitHub Releases
# These are built by GitHub Actions and stored as release assets

resource "proxmox_virtual_environment_download_file" "nixos_devbox_bootstrap" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "homelab"

  # Public release URL - built by .github/workflows/build-lxc-templates.yml
  url       = "https://github.com/peterhajas/infra/releases/download/lxc-templates-latest/nixos-devbox-bootstrap.tar.xz"
  file_name = "nixos-devbox-bootstrap.tar.xz"

  # Re-download when content changes
  overwrite = true
}
```

Note: Replace `peterhajas/infra` with the actual GitHub repo path.

**Step 2: Update devbox.tf to use new template**

Change the `operating_system` block from:

```hcl
operating_system {
  template_file_id = "local:vztmpl/nixos-24.11-proxmox.tar.xz"
  type             = "unmanaged"
}
```

To:

```hcl
operating_system {
  template_file_id = proxmox_virtual_environment_download_file.nixos_devbox_bootstrap.id
  type             = "unmanaged"
}
```

**Step 3: Validate Terraform**

Run: `terraform -chdir=terraform/proxmox-homelab validate`
Expected: "Success! The configuration is valid."

**Step 4: Commit**

```bash
git add terraform/proxmox-homelab/templates.tf terraform/proxmox-homelab/devbox.tf
git commit -m "feat(terraform): use custom NixOS template from GitHub releases"
```

---

## Task 6: Update Root Flake (Optional)

**Files:**
- Modify: `flake.nix` (root)

**Step 1: Consider if images should be part of root flake**

The `images/flake.nix` is currently standalone. This is intentional - it has different inputs (nixos-generators) and builds artifacts, not system configurations.

No changes needed to root flake. The images zone is self-contained.

**Step 2: Commit (no changes)**

No commit needed.

---

## Task 7: Documentation Update

**Files:**
- Modify: `docs/reference/current-state.md` (if exists)
- This plan file serves as documentation

**Step 1: Commit plan document**

```bash
git add docs/plans/2025-12-28-lxc-bootstrap-template.md
git commit -m "docs: add LXC bootstrap template implementation plan"
```

---

## Deployment Sequence

After all tasks are complete:

1. **Push to main** - Triggers GitHub Actions to build template
2. **Verify release** - Check GitHub releases for `lxc-templates-latest`
3. **Run Terraform** - `terraform apply` downloads new template
4. **Test** - Destroy and recreate devbox to verify template works:
   ```bash
   terraform destroy -target=proxmox_virtual_environment_container.devbox
   terraform apply
   ```
5. **Verify SSH** - `ssh devbox` should work immediately on fresh container

---

## Recovery Workflow (After Implementation)

When devbox becomes inaccessible:

1. Reprovision: `terraform destroy -target=...devbox && terraform apply`
2. SSH in: `ssh devbox` (works immediately)
3. Update repo: `cd ~/infra && git pull`
4. Rebuild full config: `sudo nixos-rebuild switch --flake .#devbox`
