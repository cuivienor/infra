# Terraform Zone

Zone-specific guidance for working with Terraform in this monorepo.

## Module Organization

Each subdirectory is an **independent root module** with its own state:

```
terraform/
├── proxmox-homelab/    # LXC containers on Proxmox (most common)
├── tailscale/          # Tailscale ACLs, DNS, auth keys
├── cloudflare/         # Cloudflare DNS records
├── lldap/              # LLDAP user/group management
└── modules/            # Shared modules (future use)
```

**Important:** Modules do NOT share state. Run `terraform init` in each module separately.

## Provider Versions

| Module | Provider | Version |
|--------|----------|---------|
| proxmox-homelab | bpg/proxmox | ~0.50.0 |
| tailscale | tailscale/tailscale | ~0.16 |
| cloudflare | cloudflare/cloudflare | ~4.0 |
| all | carlpett/sops | ~1.1 |

Check `versions.tf` in each module for current constraints.

## Secrets with SOPS

Secrets are encrypted with SOPS using age encryption:

```bash
# Edit encrypted secrets
sops terraform/proxmox-homelab/secrets.sops.yaml

# Decrypt for debugging (don't commit decrypted!)
sops -d terraform/proxmox-homelab/secrets.sops.yaml
```

**Key location:** `terraform/.sops-key` (gitignored, restore from Bitwarden)

Access in HCL:
```hcl
data "sops_file" "secrets" {
  source_file = "secrets.sops.yaml"
}

# Use: data.sops_file.secrets.data["key_name"]
```

## Container Definition Pattern

Standard pattern for `proxmox-homelab/*.tf`:

```hcl
resource "proxmox_virtual_environment_container" "name" {
  description   = "Purpose description"
  node_name     = "homelab"
  vm_id         = XXX        # See current-state.md for assignments
  started       = true
  unprivileged  = false      # Most need privileged for bind mounts

  initialization {
    hostname = "name"
    ip_config {
      ipv4 {
        address = "192.168.1.XXX/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      keys = [for k in local.ssh_keys : trimspace(k)]
    }
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"    # or "unmanaged" for NixOS
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  cpu { cores = X }
  memory { dedicated = XXXX }      # In MB
  disk {
    datastore_id = "local-lvm"
    size         = XX              # In GB
  }

  features {
    nesting = true                 # Required for systemd
  }
}
```

## Testing New Containers

**Always test with CTID 199** before touching production:

```bash
# Create test container
terraform apply -target=proxmox_virtual_environment_container.test

# Verify via SSH
ssh root@192.168.1.199

# Destroy when done
terraform destroy -target=proxmox_virtual_environment_container.test
```

## Common Pitfalls

1. **State conflicts**: Never edit state manually. If state is corrupted, work with Peter to fix.

2. **Provider upgrades**: Lock versions in `versions.tf`. Upgrade deliberately, test first.

3. **Bind mounts**: Container must be privileged. Add mount_point blocks:
   ```hcl
   mount_point {
     volume = "/mnt/storage/media"
     path   = "/mnt/media"
   }
   ```

4. **GPU passthrough**: Requires features in container config + host setup. See `transcoder.tf` or `jellyfin.tf` for examples.

5. **DNS**: Containers use local DNS (Pi4: 192.168.1.102, backup: 192.168.1.110). Verify after provisioning.

## Key Files

- `proxmox-homelab/locals.tf` - SSH keys loaded from ansible/files/ssh-keys/
- `proxmox-homelab/provider.tf` - Provider configuration and SOPS setup
- `*/versions.tf` - Provider version constraints
- `*/terraform.tfvars` - Variable values (gitignored)
- `*/secrets.sops.yaml` - Encrypted secrets
