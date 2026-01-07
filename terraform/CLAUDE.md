# Terraform Zone

Four independent root modules, each with own state. Run `terraform init` in each separately.

## STRUCTURE

```
terraform/
├── proxmox-homelab/    # LXC containers (MOST COMMON)
├── tailscale/          # VPN ACLs, DNS, auth keys
├── cloudflare/         # DNS records, tunnels
└── lldap/              # LDAP user/group management
```

## PROVIDERS

| Module | Provider | Version |
|--------|----------|---------|
| proxmox-homelab | bpg/proxmox | ~0.50.0 |
| tailscale | tailscale/tailscale | ~0.16 |
| cloudflare | cloudflare/cloudflare | ~4.0 |
| all | carlpett/sops | ~1.1 |

## SECRETS (SOPS)

```bash
sops terraform/proxmox-homelab/secrets.sops.yaml    # Edit
sops -d terraform/proxmox-homelab/secrets.sops.yaml # Decrypt (debug only)
```

Key: `terraform/.sops-key` (gitignored → Bitwarden)

HCL access:
```hcl
data "sops_file" "secrets" { source_file = "secrets.sops.yaml" }
# Use: data.sops_file.secrets.data["key_name"]
```

## CONTAINER PATTERN

Standard `proxmox-homelab/*.tf` structure:

```hcl
resource "proxmox_virtual_environment_container" "name" {
  description   = "Purpose"
  node_name     = "homelab"
  vm_id         = XXX              # See docs/reference/current-state.md
  started       = true
  unprivileged  = false            # Privileged for bind mounts

  initialization {
    hostname = "name"
    ip_config { ipv4 { address = "192.168.1.XXX/24"; gateway = "192.168.1.1" } }
    user_account { keys = [for k in local.ssh_keys : trimspace(k)] }
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type = "debian"                # or "unmanaged" for NixOS
  }

  cpu { cores = X }
  memory { dedicated = XXXX }      # MB
  disk { datastore_id = "local-lvm"; size = XX }  # GB
  features { nesting = true }      # Required for systemd
}
```

## TESTING

**Use CTID 199** for testing:
```bash
terraform apply -target=proxmox_virtual_environment_container.test
ssh root@192.168.1.199
terraform destroy -target=proxmox_virtual_environment_container.test
```

## ANTI-PATTERNS

- **Manual state edits** → Work with Peter to fix corruption
- **terraform.tfvars in git** → Contains secrets
- **Skipping plan** → Always `terraform plan` first
- **Upgrading providers without testing** → Lock in `versions.tf`

## GPU PASSTHROUGH

See `transcoder.tf` (Intel Arc) or `jellyfin.tf` (dual GPU) for patterns.

## BIND MOUNTS

Container must be privileged:
```hcl
mount_point { volume = "/mnt/storage/media"; path = "/mnt/media" }
```

## KEY FILES

- `proxmox-homelab/locals.tf` - SSH keys from `ansible/files/ssh-keys/`
- `*/versions.tf` - Provider constraints
- `*/secrets.sops.yaml` - Encrypted secrets
