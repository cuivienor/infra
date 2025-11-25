# Terraform Infrastructure Configuration

This directory contains Terraform configurations for managing homelab infrastructure, organized into separate root modules.

## Structure

```
terraform/
├── proxmox-homelab/           # Proxmox LXC containers
│   ├── main.tf                # Proxmox provider config
│   ├── variables.tf           # Container-related variables
│   ├── outputs.tf             # Container IDs and IPs
│   ├── ssh_keys.tf            # SSH key management
│   ├── terraform.tfvars       # Proxmox secrets (gitignored)
│   └── *.tf                   # Individual container definitions
├── tailscale/                 # Tailscale configuration
│   ├── main.tf                # Tailscale provider config
│   ├── variables.tf           # Tailscale variables
│   ├── outputs.tf             # Auth key outputs
│   ├── tailscale.tf           # ACLs, DNS, auth keys
│   └── terraform.tfvars       # Tailscale secrets (gitignored)
├── modules/                   # Shared modules (future use)
├── .tflint.hcl                # Shared linting config
├── terraform.tfvars.example   # Example variables file
└── README.md                  # This file
```

## Why Separate Modules?

Each module has its own state file for:
- **State isolation**: Tailscale changes can't accidentally affect containers
- **Independent workflows**: Apply Tailscale ACLs without touching Proxmox
- **Future growth**: Easy to add new modules (aws/, cloudflare/, proxmox-lab2/)

## Prerequisites

1. **Terraform**: Version 1.5.0+
2. **Proxmox API access**: Root credentials or API token
3. **Tailscale OAuth**: Client ID and secret from Tailscale admin console
4. **Debian 12 template**: On Proxmox host (`pveam list local`)

## Quick Start

### Proxmox Containers

```bash
cd terraform/proxmox-homelab
cp ../terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials

terraform init
terraform plan
terraform apply
```

### Tailscale Configuration

```bash
cd terraform/tailscale
# Create terraform.tfvars with:
# tailscale_oauth_client_id     = "..."
# tailscale_oauth_client_secret = "..."
# tailscale_tailnet             = "..."

terraform init
terraform plan
terraform apply
```

## Common Operations

### View Current State

```bash
# Proxmox containers
cd terraform/proxmox-homelab
terraform state list
terraform output

# Tailscale
cd terraform/tailscale
terraform state list
terraform output tailscale_pi4_auth_key
```

### Add a New Container

1. Create `terraform/proxmox-homelab/<name>.tf`
2. Run `terraform plan` to preview
3. Run `terraform apply` to create
4. Add to Ansible inventory and configure

### Update Tailscale ACLs

1. Edit `terraform/tailscale/tailscale.tf`
2. Run `cd terraform/tailscale && terraform apply`

### Format All Files

```bash
terraform fmt -recursive terraform/
```

## Container Inventory

| CTID | File        | Hostname   | IP              | Purpose            |
|------|-------------|------------|-----------------|---------------------|
| 300  | backup.tf   | backup     | 192.168.1.120   | Restic backups      |
| 301  | samba.tf    | samba      | 192.168.1.121   | SMB file shares     |
| 302  | ripper.tf   | ripper     | 192.168.1.131   | MakeMKV ripper      |
| 303  | analyzer.tf | analyzer   | 192.168.1.133   | FileBot analyzer    |
| 304  | transcoder.tf | transcoder | 192.168.1.132 | FFmpeg transcoding  |
| 305  | jellyfin.tf | jellyfin   | 192.168.1.130   | Media server        |
| 307  | wishlist.tf | wishlist   | 192.168.1.186   | Gift registry       |
| 310  | dns.tf      | dns        | 192.168.1.110   | AdGuard Home        |
| 311  | proxy.tf    | proxy      | 192.168.1.111   | Caddy reverse proxy |

## Linting

TFLint is configured with `.tflint.hcl`:

```bash
cd terraform/proxmox-homelab && tflint
cd terraform/tailscale && tflint
```

Pre-commit hooks run TFLint automatically.

## Troubleshooting

### "Container already exists"

```bash
# Import existing container
cd terraform/proxmox-homelab
terraform import proxmox_virtual_environment_container.backup homelab/lxc/300
```

### "Template not found"

```bash
# On Proxmox host
pveam update
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

### "Authentication failed"

Check `terraform.tfvars`:
- Correct Proxmox endpoint (https://192.168.1.100:8006)
- Correct credentials (root@pam with password, or API token)

## Known Issues

### Mount point drift (analyzer, jellyfin)

`terraform plan` shows mount_points wanting to be removed from analyzer and jellyfin containers, but `terraform apply` doesn't actually remove them. This is a **known bug** in the bpg/proxmox provider ([Issue #1392](https://github.com/bpg/terraform-provider-proxmox/issues/1392)).

**Root cause:** The provider can't reliably track which physical mount point (mp0, mp1, etc.) each config item maps to. When you remove one, indices shift and the wrong mount gets updated.

**Current state:** These containers have extra mount_points that were added manually and aren't in Terraform config. The drift is cosmetic - infrastructure works fine.

**Fix timeline:** Targeted for provider v2.0 (requires Plugin Framework migration).

**Options if it bothers you:**
1. Add `mount_point` to `lifecycle.ignore_changes` to silence the warnings
2. Add the extra mounts to the `.tf` files to match reality
3. Recreate the containers (nuclear option)

## Reference

- [Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Tailscale Provider](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [Terraform Docs](https://www.terraform.io/docs)

---

**Last Updated**: 2025-11-25
