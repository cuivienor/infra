# Terraform Infrastructure Configuration

This directory contains Terraform configurations for deploying and managing LXC containers on Proxmox.

## Structure

```
terraform/
├── main.tf                    # Provider configuration
├── variables.tf               # Variable definitions
├── terraform.tfvars.example   # Example variables file
├── terraform.tfvars           # Your variables (git-ignored)
└── containers/
    └── ct300-backup.tf        # CT300 backup container
```

## Prerequisites

1. **Terraform installed**: Version 1.5.0 or later
   ```bash
   # Check version
   terraform version
   ```

2. **Proxmox API access**: Ensure you have credentials

3. **Debian 12 template**: Available on Proxmox host
   ```bash
   # On Proxmox host, verify template exists
   pveam list local
   # Should show: debian-12-standard_12.7-1_amd64.tar.zst
   ```

## Initial Setup

### 1. Configure Variables

Copy the example file and fill in your credentials:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Required variables:
- `proxmox_password` - Your Proxmox root password
- `ssh_public_key` (optional) - For SSH access to containers

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the Proxmox provider.

## Usage

### Plan Changes

Preview what Terraform will do:

```bash
terraform plan
```

### Apply Changes

Create or update infrastructure:

```bash
terraform apply
```

Review the plan and type `yes` to confirm.

### View Current State

```bash
# List all resources
terraform state list

# Show specific resource
terraform show
```

### Destroy Resources

**Warning**: This will delete containers!

```bash
# Destroy specific container
terraform destroy -target=proxmox_virtual_environment_container.backup

# Destroy everything
terraform destroy
```

## Containers

### CT300: Backup Container

**Purpose**: Restic-based backups of /mnt/storage to Backblaze B2

**Resources**:
- **CTID**: 300
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 20GB
- **OS**: Debian 12
- **Network**: DHCP on vmbr0

**Features**:
- Mounts `/mnt/storage` from host
- Runs restic backup scripts (managed by Ansible)
- Includes Backrest web UI for monitoring
- Unprivileged container (no special hardware access needed)

**After Terraform Apply**:
1. Note the IP address from Terraform output
2. Configure with Ansible:
   ```bash
   export CT300_IP="<ip-from-terraform>"
   ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file ~/.vault_pass
   ```

## Post-Container Creation Steps

### Mount /mnt/storage in Container

After Terraform creates the container, the `/mnt/storage` mount needs additional configuration on the Proxmox host:

```bash
# On Proxmox host
pct set 300 -mp0 /mnt/storage,mp=/mnt/storage

# Start container
pct start 300

# Verify mount
pct exec 300 -- df -h /mnt/storage
```

**Note**: This step will be automated via Ansible in future updates.

## Workflow

### Creating a New Container

1. **Create Terraform file**: `containers/ct3XX-name.tf`
2. **Plan**: `terraform plan`
3. **Apply**: `terraform apply`
4. **Get IP**: Check Terraform output or Proxmox UI
5. **Configure**: Run Ansible playbook for the container

### Updating a Container

1. **Edit .tf file**: Modify resource configuration
2. **Plan**: `terraform plan` (review changes)
3. **Apply**: `terraform apply`

**Note**: Some changes require container restart or recreation.

### Importing Existing Containers

To bring existing containers under Terraform management:

```bash
# Example: Import CT200
terraform import proxmox_virtual_environment_container.ripper homelab/lxc/200
```

Then create the corresponding `.tf` file matching current state.

## Troubleshooting

### "Container already exists"

If Terraform fails because container exists:

```bash
# Option 1: Import existing container
terraform import proxmox_virtual_environment_container.backup homelab/lxc/300

# Option 2: Delete container manually and retry
pct stop 300
pct destroy 300
terraform apply
```

### "Template not found"

Download the Debian template:

```bash
# On Proxmox host
pveam update
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

### "Authentication failed"

Check your `terraform.tfvars`:
- Correct Proxmox endpoint
- Correct username (usually `root@pam`)
- Correct password

### Container has no network

1. **Check DHCP**: Ensure your router is running DHCP
2. **Manual IP**: Modify container to use static IP
3. **Restart container**: `pct stop 300 && pct start 300`

## Best Practices

1. **Always run `terraform plan` first** - Review changes before applying
2. **Use version control** - Commit `.tf` files, not `terraform.tfvars`
3. **Document changes** - Add comments to `.tf` files
4. **Test with CT300s first** - Don't touch production containers (CT200s) yet
5. **Backup state** - `terraform.tfstate` is critical (consider remote backend)

## Next Steps

- [ ] Deploy CT300 backup container
- [ ] Test full Terraform + Ansible workflow
- [ ] Add more containers (CT301, CT302, etc.)
- [ ] Import existing production containers (CT200-202)
- [ ] Set up remote state backend (Terraform Cloud or S3)

## Reference

- **Proxmox Provider Docs**: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- **Terraform Docs**: https://www.terraform.io/docs
- **Container Resource**: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container

---

**Last Updated**: 2025-11-11
