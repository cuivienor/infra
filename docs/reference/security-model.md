# Homelab Security Model

This document defines the security architecture for the homelab. Reference this when adding new services.

## Trust Boundaries

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           INTERNET (Untrusted)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌───────────────────┐           ┌───────────────────┐
        │ Cloudflare Tunnel │           │     Tailscale     │
        │   (Public apps)   │           │   (Trusted VPN)   │
        └─────────┬─────────┘           └─────────┬─────────┘
                  │                               │
                  ▼                               │
        ┌───────────────────┐                     │
        │     Authelia      │                     │
        │  (SSO gateway)    │                     │
        └─────────┬─────────┘                     │
                  │                               │
                  └───────────────┬───────────────┘
                                  ▼
        ┌─────────────────────────────────────────────────────────────────┐
        │                    LAN (192.168.1.0/24)                         │
        │                      Trusted Network                            │
        └─────────────────────────────────────────────────────────────────┘
```

## Access Patterns

### Pattern 1: Internal Only (Tailscale + LAN)

**Use when:** Media apps, admin interfaces, anything that doesn't need public access.

**Trust model:** Network access = authorization. If you're on Tailscale or LAN, you're trusted.

**Authentication:** Native app auth (if any) or none.

**Examples:**
- Jellyfin (`jellyfin.paniland.com`) - Passwordless profiles, internal only
- Proxmox (`proxmox.paniland.com`) - Native login (root@pam or OIDC)
- AdGuard (`dns.paniland.com`) - Basic auth
- Backrest (`backrest.paniland.com`) - Basic auth

**Implementation:**
```yaml
# proxy.yml - No authelia_protected flag
- domain: "jellyfin.paniland.com"
  upstream: "192.168.1.130:8096"
  # No tunnel, no Authelia - internal access only
```

### Pattern 2: Tunneled with Authelia Gate

**Use when:** Apps that need public access AND don't have robust native auth.

**Trust model:** Authelia proves identity before reaching the app.

**Authentication:** Authelia SSO (one_factor or two_factor).

**Examples:**
- Wishlist (`wishlist.paniland.com`) - Tunneled, Authelia gate
- LLDAP admin (`lldap.paniland.com`) - Tunneled, Authelia gate (admins only)

**Implementation:**
```yaml
# proxy.yml
- domain: "wishlist.paniland.com"
  upstream: "192.168.1.186:3280"
  authelia_protected: true

# authelia.yml
authelia_access_rules:
  - domain: "wishlist.paniland.com"
    policy: "one_factor"
    subject: ["group:admins", "group:wishlist_users"]
```

```hcl
# terraform/cloudflare/variables.tf
tunnel_services = {
  wishlist = { hostname = "wishlist.paniland.com" }
}
```

### Pattern 3: Tunneled with Native Auth

**Use when:** Apps with robust native auth that need public access.

**Trust model:** App handles its own authentication.

**Authentication:** Native app auth (OIDC, LDAP, etc.)

**Examples:**
- Authelia itself (`auth.paniland.com`) - Tunneled, no gate (it IS the gate)

**Implementation:**
```yaml
# proxy.yml - Tunneled but no authelia_protected
- domain: "auth.paniland.com"
  upstream: "192.168.1.112:9091"
```

## Decision Framework

When adding a new service, ask:

```
1. Does it need public (non-Tailscale) access?
   │
   ├─ NO → Pattern 1: Internal Only
   │       - No tunnel
   │       - No Authelia gate
   │       - Rely on network boundary
   │
   └─ YES → Does the app have robust native auth?
            │
            ├─ YES → Pattern 3: Tunnel + Native Auth
            │        - Add to tunnel
            │        - No Authelia gate
            │        - Configure native auth (OIDC/LDAP/etc)
            │
            └─ NO → Pattern 2: Tunnel + Authelia Gate
                    - Add to tunnel
                    - Add authelia_protected: true
                    - Add access rule in authelia.yml
```

## Authentication Methods

### Authelia (SSO Gateway)
- **Backend:** LLDAP for user directory
- **Policies:** one_factor (password), two_factor (password + TOTP)
- **Groups:** From LLDAP (admins, jellyfin_users, wishlist_users, etc.)

### LLDAP (User Directory)
- **Address:** `lldap.home.arpa:3890` (LDAP), `:17170` (Web UI)
- **Base DN:** `dc=paniland,dc=com`
- **Service account:** `cn=authelia,ou=people,dc=paniland,dc=com`

### Native App Auth Options
- **OIDC:** For apps that support it (Proxmox, etc.) - use Authelia as IdP
- **LDAP:** For apps that need username/password (works with TV apps)
- **Basic Auth:** For simple admin interfaces

## Group-Based Access Control

Groups are defined in `terraform/users.yaml` and synced to LLDAP:

| Group | Purpose |
|-------|---------|
| `admins` | Full access to everything |
| `tailscale` | VPN access to home network |
| `jellyfin_users` | Can access Jellyfin |
| `wishlist_users` | Can access Wishlist |
| `service_accounts` | System accounts (no user access) |

## Services Summary

| Service | URL | Access | Auth Method |
|---------|-----|--------|-------------|
| Jellyfin | jellyfin.paniland.com | Internal | None (profiles) |
| Wishlist | wishlist.paniland.com | Tunnel + Authelia | SSO |
| Authelia | auth.paniland.com | Tunnel | Native |
| LLDAP | lldap.paniland.com | Tunnel + Authelia | SSO (admins) |
| Proxmox | proxmox.paniland.com | Internal | OIDC / root@pam |
| AdGuard | dns.paniland.com | Internal | Basic auth |
| Backrest | backrest.paniland.com | Internal | Basic auth |
| UniFi | unifi.paniland.com | Internal | Native |

## Fallback Access

For reliability, maintain fallback access when possible:

- **Proxmox:** Always keep `root@pam` working
- **AdGuard/Backrest:** Direct IP access (http://192.168.1.x:port)
- **LLDAP:** Direct IP if Authelia is down (http://192.168.1.114:17170)

## Files Reference

| File | Purpose |
|------|---------|
| `terraform/cloudflare/variables.tf` | Tunnel services |
| `terraform/users.yaml` | User/group definitions |
| `ansible/playbooks/proxy.yml` | Caddy routes + Authelia flags |
| `ansible/playbooks/authelia.yml` | Access rules + OIDC clients |
| `ansible/playbooks/dns.yml` | DNS rewrites |
