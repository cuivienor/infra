# Devbox GitHub SSH Key Provisioning

## Overview

Provision a GitHub SSH key to devbox declaratively using sops-nix, enabling git push operations from the dev container.

## Architecture

```
encrypted key in repo
        │
        ▼
sops-nix decrypts at NixOS activation
        │
        ▼
/run/secrets/github-ssh-key (mode 0400, owner cuiv)
        │
        ▼
SSH config uses key for github.com
```

## Components

1. **sops-nix** - Flake input providing NixOS module for secret decryption
2. **Age key derivation** - Devbox's SSH host key converted to age for decryption
3. **Encrypted secret** - GitHub SSH private key encrypted with sops
4. **SSH configuration** - Home Manager config pointing to decrypted key

## Implementation

### 1. Flake Input

Add sops-nix to `flake.nix`:
```nix
sops-nix = {
  url = "github:Mic92/sops-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 2. Sops Configuration

Create `/.sops.yaml` at repo root:
```yaml
keys:
  - &terraform age1tsqhkhhvqk9m5d4480f9m0jhdecfa5puyrpt6ye07kaeg6453v8sfdcuyx
  - &devbox <devbox-host-age-key>

creation_rules:
  # Terraform secrets - terraform key only
  - path_regex: ^terraform/.*\.sops\.yaml$
    key_groups:
      - age:
          - *terraform

  # NixOS secrets - host keys
  - path_regex: ^secrets/.*\.yaml$
    key_groups:
      - age:
          - *terraform
          - *devbox
```

### 3. Secret File

`secrets/devbox.yaml` (encrypted with sops, contains `github-ssh-key` field)

### 4. NixOS Configuration

In `nixos/hosts/devbox/configuration.nix`:
```nix
sops = {
  defaultSopsFile = ../../../secrets/devbox.yaml;
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  secrets.github-ssh-key = {
    owner = "cuiv";
    mode = "0400";
    path = "/home/cuiv/.ssh/github-devbox";
  };
};
```

### 5. SSH Configuration

In `home/users/cuiv/git.nix` or new `ssh.nix`:
```nix
programs.ssh = {
  enable = true;
  matchBlocks."github.com" = {
    hostname = "github.com";
    user = "git";
    identityFile = "/home/cuiv/.ssh/github-devbox";
    identitiesOnly = true;
  };
};
```

## Security Considerations

- Private key never stored unencrypted in repo
- Decrypted only at runtime to `/run/secrets/` (tmpfs)
- Key readable only by cuiv user (mode 0400)
- Host key used for decryption already exists on devbox

## Manual Step

After deployment, add the public key to GitHub:
1. Get pubkey: `cat /home/cuiv/.ssh/github-devbox.pub` (or from secrets)
2. Add at: https://github.com/settings/ssh/new
