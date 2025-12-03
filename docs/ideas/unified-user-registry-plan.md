# Unified User Registry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a single `terraform/users.yaml` file as the source of truth for users/groups, driving both LLDAP (SSO) and Tailscale ACLs (network access).

**Architecture:** A YAML config file defines users and their group memberships. Terraform reads this file to provision LLDAP users/groups and generate Tailscale ACL groups. Authelia references LLDAP groups for per-service access control.

**Tech Stack:** Terraform (LLDAP provider, Tailscale provider), YAML, Ansible (Authelia config)

---

## Access Model

| Access Type | How it works |
|-------------|--------------|
| **SSO via Tunnel** | Default. User in service group (e.g., `jellyfin_users`) can access via Cloudflare Tunnel |
| **SSO via Tailscale** | User also in `tailscale` group gets VPN access to home network |
| **Per-service** | Each service has a group. User must be in group to access that service |

## Reference: Final Config Structure

### `terraform/users.yaml`

```yaml
groups:
  # Meta groups (control infrastructure access)
  admins: {}           # Full access to everything
  tailscale: {}        # VPN access to home network
  service_accounts: {} # System accounts (no user access)

  # Service groups (control SSO access per service)
  jellyfin_users: {}
  wishlist_users: {}
  immich_users: {}     # Future

users:
  # Admin - full access
  peter:
    email: peter@petrovs.io
    display_name: Peter Petrov
    groups: [admins]

  # Friends - you'll decide each user's groups during implementation
  # Options: tailscale (VPN), jellyfin_users, wishlist_users, immich_users
  william:
    email: williamrgoldstein@gmail.com
    display_name: William Goldstein
    groups: [...]  # TO DECIDE

  sweir:
    email: sweir27@gmail.com
    display_name: Sarah Weir
    groups: [...]  # TO DECIDE

  ani:
    email: stefanova.ani@gmail.com
    display_name: Ani Stefanova
    groups: [...]  # TO DECIDE

  alastair:
    email: alastairdglennie@gmail.com
    display_name: Alastair Glennie
    groups: [...]  # TO DECIDE

  maria:
    email: maria.stef.ivanova@gmail.com
    display_name: Maria Ivanova
    groups: [...]  # TO DECIDE

  ivo:
    email: tomov90@gmail.com
    display_name: Ivo Tomov
    groups: [...]  # TO DECIDE

  # Service accounts
  authelia:
    email: authelia@paniland.com
    display_name: Authelia Service Account
    groups: [service_accounts]
    is_service_account: true
```

### Group Reference

| Group | What it grants |
|-------|----------------|
| `admins` | Full access to everything (Tailscale admin + all services) |
| `tailscale` | VPN access to home network |
| `jellyfin_users` | SSO access to Jellyfin |
| `wishlist_users` | SSO access to Wishlist |
| `immich_users` | SSO access to Immich (future) |

### Example Configurations

**Full friend (VPN + all services):**
```yaml
groups: [tailscale, jellyfin_users, wishlist_users]
```

**Media-only via tunnel (no VPN):**
```yaml
groups: [jellyfin_users]
```

**Tunnel access to multiple services:**
```yaml
groups: [jellyfin_users, wishlist_users]
```

### Data Flow

```
terraform/users.yaml
        │
        ├──► terraform/lldap/
        │    ├── Creates all groups defined in users.yaml
        │    ├── Creates LLDAP users with for_each
        │    └── Creates group memberships based on user.groups[]
        │
        ├──► terraform/tailscale/
        │    ├── Extracts emails of users in 'tailscale' or 'admins' group
        │    └── Generates ACL group:tailscale with those emails
        │
        └──► ansible/playbooks/authelia.yml (manual)
             └── Access rules reference LLDAP groups (group:jellyfin_users, etc.)
```

### Key Implementation Details

#### 1. Reading the shared config

Both Terraform modules use:
```hcl
locals {
  users_config = yamldecode(file("${path.module}/../users.yaml"))
}
```

#### 2. LLDAP groups (terraform/lldap/groups.tf)

```hcl
# Create all groups from users.yaml (except built-in ones)
resource "lldap_group" "groups" {
  for_each = {
    for name, config in local.users_config.groups : name => config
    if name != "service_accounts"  # Skip meta-groups that don't need LLDAP representation
  }

  display_name = each.key
}
```

#### 3. LLDAP users (terraform/lldap/users.tf)

```hcl
# Human users (password changes ignored after creation)
resource "lldap_user" "users" {
  for_each = {
    for username, user in local.users_config.users : username => user
    if !lookup(user, "is_service_account", false)
  }

  username     = each.key
  email        = each.value.email
  display_name = each.value.display_name
  password     = var.initial_user_password

  lifecycle {
    ignore_changes = [password]
  }
}

# Service accounts (password managed by Terraform)
resource "lldap_user" "service_accounts" {
  for_each = {
    for username, user in local.users_config.users : username => user
    if lookup(user, "is_service_account", false)
  }

  username     = each.key
  email        = each.value.email
  display_name = each.value.display_name
  password     = var.service_account_passwords[each.key]
}
```

#### 4. LLDAP memberships (terraform/lldap/memberships.tf)

```hcl
# Flatten user-group relationships
locals {
  memberships = flatten([
    for username, user in local.users_config.users : [
      for group in user.groups : {
        user  = username
        group = group
      }
      if group != "service_accounts"  # Skip meta-groups
    ]
  ])
}

resource "lldap_member" "memberships" {
  for_each = {
    for m in local.memberships : "${m.group}:${m.user}" => m
  }

  group_id = lldap_group.groups[each.value.group].id
  user_id  = coalesce(
    try(lldap_user.users[each.value.user].username, null),
    try(lldap_user.service_accounts[each.value.user].username, null)
  )
}
```

#### 5. Tailscale ACL (terraform/tailscale/tailscale.tf)

```hcl
locals {
  users_config = yamldecode(file("${path.module}/../users.yaml"))

  # Users with Tailscale access: in 'tailscale' group OR in 'admins' group
  tailscale_emails = [
    for username, user in local.users_config.users : user.email
    if contains(user.groups, "tailscale") || contains(user.groups, "admins")
  ]
}

resource "tailscale_acl" "homelab" {
  acl = jsonencode({
    groups = {
      "group:tailscale" = local.tailscale_emails
    }
    acls = [
      # Admins (you) can access everything
      { action = "accept", src = ["autogroup:admin"], dst = ["*:*"] },
      # Tailscale users get limited access
      {
        action = "accept"
        src    = ["group:tailscale"]
        dst = [
          "192.168.1.102:53",     # DNS
          "192.168.1.110:53",     # DNS backup
          "192.168.1.111:80,443", # Proxy
          "192.168.1.130:8096",   # Jellyfin
          "192.168.1.186:3280",   # Wishlist
        ]
      }
    ]
    # ... rest of config unchanged
  })
}
```

#### 6. Authelia access rules (ansible/playbooks/authelia.yml)

Configured manually in the playbook to reference LLDAP groups:

```yaml
authelia_access_rules:
  - domain: "jellyfin.paniland.com"
    policy: "one_factor"
    subject: ["group:admins", "group:jellyfin_users"]

  - domain: "wishlist.paniland.com"
    policy: "one_factor"
    subject: ["group:admins", "group:wishlist_users"]

  - domain: "immich.paniland.com"
    policy: "one_factor"
    subject: ["group:admins", "group:immich_users"]
```

### Files to Modify

1. **Create:** `terraform/users.yaml` - Unified user/group config
2. **Refactor:** `terraform/lldap/users.tf` - Dynamic users from users.yaml
3. **Refactor:** `terraform/lldap/groups.tf` - Dynamic groups from users.yaml
4. **Refactor:** `terraform/lldap/memberships.tf` - Dynamic memberships
5. **Refactor:** `terraform/tailscale/tailscale.tf` - Read tailscale group from users.yaml
6. **Update:** `ansible/playbooks/authelia.yml` - Add group-based access rules

### Migration Plan

**Phase 1: Create users.yaml and update LLDAP**
1. Create `terraform/users.yaml` with all users and service groups
2. Clear LLDAP Terraform state (since we're restructuring resources)
3. Run `terraform apply` in lldap/ - creates:
   - 7 users (peter, william, sweir, ani, alastair, maria, ivo, authelia)
   - 6 groups (admins, tailscale, jellyfin_users, wishlist_users, immich_users, service_accounts)
   - All group memberships

**Phase 2: Update Tailscale**
4. Update `terraform/tailscale/tailscale.tf` to read from users.yaml
5. Run `terraform plan` - should show change from `group:friends` to `group:tailscale`
6. Apply - ACL now uses unified config

**Phase 3: Update Authelia**
7. Update `ansible/playbooks/authelia.yml` with group-based access rules
8. Run authelia playbook - access now controlled by LLDAP groups

### What Changes for Users

| User | Before | After |
|------|--------|-------|
| peter | LLDAP + Tailscale admin | Same (admins group) |
| 6 friends | Tailscale ACL only | LLDAP accounts + groups you assign |

**During implementation:** You'll review each friend and assign their groups based on what access they should have.

### Adding a New User

After implementation, adding a user is:

```yaml
# In terraform/users.yaml, add:
  newuser:
    email: newuser@example.com
    display_name: New User
    groups: [friends]
```

Then:
```bash
cd terraform/lldap && terraform apply    # Creates LLDAP user
cd terraform/tailscale && terraform apply # Updates Tailscale ACL
```

### Benefits

- **Single source of truth** - One file defines all user access
- **Group-based access** - Assign user to group, access follows automatically
- **Future-proof** - Easy to add new groups (e.g., `family`, `media-only`)
- **Auditable** - Can see all user permissions in one file
- **Safe refactor** - Terraform plans should show no changes initially
