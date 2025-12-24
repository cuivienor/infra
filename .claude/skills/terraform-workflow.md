---
name: terraform-workflow
description: Use when making Terraform changes - enforces plan/review/apply workflow
---

# Terraform Workflow

## When to Use

Use this skill when:
- Creating or modifying Terraform resources
- Adding new containers to proxmox-homelab
- Changing Tailscale ACLs or DNS
- Working with SOPS-encrypted secrets

## Workflow Checklist

### 1. Identify the Module

Determine which module you're working in:
- `terraform/proxmox-homelab/` - LXC containers
- `terraform/tailscale/` - Tailscale configuration
- `terraform/cloudflare/` - DNS records
- `terraform/lldap/` - LLDAP users/groups

### 2. Make Changes

Edit the appropriate `.tf` files. Follow patterns:
- One container per file in proxmox-homelab
- Use `locals.tf` for shared values
- Encrypt secrets with SOPS

### 3. Format

```bash
cd terraform/<module>
terraform fmt
```

### 4. Validate

```bash
terraform validate
```

### 5. Plan (REQUIRED)

**Always plan before apply:**

```bash
terraform plan
```

Review the plan output carefully:
- Check resources being created/modified/destroyed
- Verify no unexpected changes
- Note any data sources being refreshed

### 6. Present Plan to User

Before applying, summarize:
- Resources to be created
- Resources to be modified
- Resources to be destroyed
- Any concerns or warnings

Ask: "Does this plan look correct?"

### 7. Apply

Only after user approval:

```bash
terraform apply
```

### 8. Verify

After apply:
- Check resources exist (SSH to container, verify DNS, etc.)
- Update `docs/reference/current-state.md` if infrastructure changed
- Commit changes including any state-related updates

## Common Patterns

### New Container

1. Create `terraform/proxmox-homelab/<name>.tf`
2. Use existing container as template (e.g., `backup.tf`)
3. Assign next available CTID from current-state.md
4. Run workflow above
5. Add to Ansible inventory after Terraform completes

### SOPS Secret

```bash
# Edit secrets
sops terraform/proxmox-homelab/secrets.sops.yaml

# In HCL
data "sops_file" "secrets" {
  source_file = "secrets.sops.yaml"
}
resource "..." {
  password = data.sops_file.secrets.data["password"]
}
```

## Never Do

- Apply without planning first
- Skip user approval for destructive changes
- Edit terraform.tfstate manually
- Commit .tfstate files
- Run terraform in wrong module directory
