# LLDAP Implementation Plan

**Status**: Phase 1 Complete - LLDAP deployed, Authelia integration pending
**Created**: 2025-11-30
**Updated**: 2025-12-01
**Current Authelia**: File-based authentication (working)

## Overview

Implement LLDAP (Lightweight LDAP) for centralized user management, replacing Authelia's file-based authentication backend with LDAP.

## Completed ✓

### Phase 1: LLDAP Deployment (Done)

1. **Container provisioned** - CT308 at 192.168.1.114
2. **LLDAP service running** - Web UI at http://192.168.1.114:17170, LDAP at :3890
3. **Users created via Terraform**:
   - `peter` - Admin user (member of admins and users groups)
   - `authelia` - Service account for Authelia LDAP binding
4. **Groups created**: `admins`, `users`

### SSH Issue Resolution

**Root Cause**: Pi4 (192.168.1.102) had stale IP .114 configured in addition to .102. The Pi hadn't rebooted since Nov 15, so old dhcpcd config persisted despite Ansible updates.

**Fix**: Power-cycled Pi4, which came back with correct config (.102 only).

## Remaining Tasks

### Phase 2: Authelia LDAP Integration

1. Update `authelia_auth_backend: ldap` in playbook vars
2. Re-run authelia playbook
3. Add authelia service account to `lldap_password_manager` group (for password reset)

### Phase 3: Testing

1. Login to wishlist.paniland.com with LDAP user (peter)
2. Test password reset flow
3. Verify OIDC still works with LDAP backend

## Infrastructure Created

### Terraform
- `terraform/proxmox-homelab/lldap.tf` - CT308 container definition (192.168.1.114)
- `terraform/lldap/` - LLDAP user management module (provider, users, groups, memberships)

### Ansible
- `ansible/roles/lldap/` - Complete role with:
  - `defaults/main.yml` - Configuration variables
  - `tasks/main.yml` - Installation and setup tasks
  - `handlers/main.yml` - Service restart handlers
  - `templates/lldap_config.toml.j2` - LLDAP configuration template
- `ansible/playbooks/lldap.yml` - Deployment playbook
- `ansible/inventory/hosts.yml` - LLDAP host entry added
- `ansible/roles/authelia/` - Updated for LDAP backend support (conditional)

### Secrets
- LLDAP secrets added to `ansible/vars/secrets.yml` (encrypted)
- `terraform/lldap/terraform.tfvars` - LLDAP Terraform variables

## Architecture

```
                    ┌─────────────────┐
                    │   User Browser  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Caddy (proxy)  │
                    │  .111           │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───────┐ ┌────▼─────┐ ┌──────▼──────┐
     │   Authelia     │ │ Wishlist │ │  Jellyfin   │
     │   .112         │ │ .186     │ │  .130       │
     └────────┬───────┘ └──────────┘ └─────────────┘
              │
     ┌────────▼────────┐
     │     LLDAP       │  ← Centralized user DB
     │     .114        │
     │ LDAP:3890       │
     │ HTTP:17170      │
     └─────────────────┘
```
