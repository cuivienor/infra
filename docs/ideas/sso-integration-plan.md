# SSO Integration Plan for Admin Services

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate SSO with homelab services using Authelia as the gateway, with dual-access patterns for media services.

**Architecture:** External access (Cloudflare tunnel) requires Authelia SSO. Internal access (Tailscale/LAN) bypasses SSO for TV app compatibility. Jellyfin uses passwordless profiles (identity-only, no auth) since Authelia handles authorization.

**Tech Stack:** Authelia (SSO), Caddy (reverse proxy), Cloudflare Tunnel, LLDAP (user directory), Tailscale (VPN)

---

## Access Model

```
EXTERNAL (Cloudflare Tunnel)
┌─────────────────────────────────────────────────────────────────┐
│  jellyfin.paniland.com ──→ Authelia SSO ──→ Jellyfin           │
│  wishlist.paniland.com ──→ Authelia SSO ──→ Wishlist           │
│  auth.paniland.com ────────────────────────→ Authelia          │
│                                                                 │
│  Browser-only. SSO proves authorization. Pick profile inside.  │
└─────────────────────────────────────────────────────────────────┘

INTERNAL (Tailscale / LAN)
┌─────────────────────────────────────────────────────────────────┐
│  jellyfin-internal.paniland.com ───────────→ Jellyfin          │
│  proxmox.home.arpa ────────────────────────→ Proxmox           │
│  dns.home.arpa ────────────────────────────→ AdGuard           │
│  backrest.home.arpa ───────────────────────→ Backrest          │
│                                                                 │
│  Direct access. Tailscale = trusted. TV apps work here.        │
│  (Using paniland.com subdomain for valid LE certificates)      │
└─────────────────────────────────────────────────────────────────┘
```

**Security Model:**
- **Authelia** = bouncer at the door (external only, proves authorization)
- **Jellyfin profiles** = name tags inside (personalization, not security)
- **Tailscale** = private entrance for trusted guests

---

## Services Summary

| Service | External (Tunnel) | Internal (Tailscale) | Auth Method |
|---------|-------------------|----------------------|-------------|
| Jellyfin | jellyfin.paniland.com → Authelia gate → passwordless | jellyfin-internal.paniland.com → direct | None (identity-only) |
| Proxmox | Not exposed | OIDC or root@pam | Authelia OIDC |
| AdGuard | Not exposed | Direct + basic auth | Service password |
| Backrest | Not exposed | Direct + basic auth | Service password |

---

## Phase 1: Jellyfin Dual-Access Setup

### Task 1.1: Add Jellyfin to Cloudflare Tunnel

**Files:**
- Modify: `terraform/cloudflare/variables.tf:34-47`

**Step 1: Update tunnel_services variable**

```hcl
variable "tunnel_services" {
  description = "Map of services to expose via tunnel"
  type = map(object({
    hostname = string
  }))
  default = {
    jellyfin = {
      hostname = "jellyfin.paniland.com"
    }
    wishlist = {
      hostname = "wishlist.paniland.com"
    }
    auth = {
      hostname = "auth.paniland.com"
    }
  }
}
```

**Step 2: Apply Terraform**

```bash
cd terraform/cloudflare
terraform plan
terraform apply
```

Expected: New CNAME record for jellyfin.paniland.com pointing to tunnel.

**Step 3: Commit**

```bash
git add terraform/cloudflare/variables.tf
git commit -m "feat: add jellyfin to cloudflare tunnel"
```

---

### Task 1.2: Add Authelia Gate for External Jellyfin

**Files:**
- Modify: `ansible/playbooks/proxy.yml:43-67`
- Modify: `ansible/playbooks/authelia.yml:51-61`

**Step 1: Update Caddy proxy config**

In `ansible/playbooks/proxy.yml`, modify the jellyfin entry:

```yaml
caddy_proxy_targets:
  # ... existing entries ...
  - domain: "jellyfin.paniland.com"
    upstream: "192.168.1.130:8096"
    authelia_protected: true  # External access requires SSO
```

**Step 2: Add Authelia access rule**

In `ansible/playbooks/authelia.yml`, add to `authelia_access_rules`:

```yaml
authelia_access_rules:
  # ... existing rules ...
  - domain: "jellyfin.paniland.com"
    policy: "one_factor"
    subject: ["group:admins", "group:jellyfin_users"]
```

**Step 3: Apply playbooks**

```bash
cd ansible
ansible-playbook playbooks/authelia.yml
ansible-playbook playbooks/proxy.yml
```

**Step 4: Commit**

```bash
git add ansible/playbooks/proxy.yml ansible/playbooks/authelia.yml
git commit -m "feat: add authelia gate for external jellyfin access"
```

---

### Task 1.3: Add Internal Jellyfin Route (No Auth)

**Files:**
- Modify: `ansible/playbooks/proxy.yml:43-67`

**Step 1: Add jellyfin-internal.paniland.com to Caddy**

```yaml
caddy_proxy_targets:
  # ... existing entries ...
  - domain: "jellyfin.paniland.com"
    upstream: "192.168.1.130:8096"
    authelia_protected: true  # External - requires SSO
  - domain: "jellyfin-internal.paniland.com"
    upstream: "192.168.1.130:8096"
    # No authelia_protected - internal access is direct
```

Note: Using `paniland.com` subdomain instead of `.home.arpa` to get valid Let's Encrypt certificates.

**Step 2: Add DNS rewrite in AdGuard (via Ansible)**

In `ansible/playbooks/dns.yml`, add to `adguard_home_dns_rewrites` (SERVICE ENDPOINTS section):

```yaml
- domain: "jellyfin-internal.paniland.com"
  answer: "192.168.1.111"  # Via Caddy proxy (internal, no auth)
```

**Step 3: Apply playbooks**

```bash
cd ansible
ansible-playbook playbooks/dns.yml    # Updates AdGuard DNS rewrites
ansible-playbook playbooks/proxy.yml  # Updates Caddy routes
```

**Step 4: Commit**

```bash
git add ansible/playbooks/proxy.yml ansible/playbooks/dns.yml
git commit -m "feat: add internal jellyfin-internal.paniland.com route"
```

---

### Task 1.4: Configure Jellyfin Passwordless Profiles

**Manual steps in Jellyfin UI:**

1. Go to Dashboard → Users
2. For each user, edit settings:
   - Uncheck "Password required to sign in" (if available)
   - Or leave password field empty
3. Users can now select their profile without entering a password

**Note:** Jellyfin may require at least one admin with a password. Keep `peter` with a password for admin access.

---

### Task 1.5: Test Dual-Access

**External path test:**
1. Disconnect from Tailscale
2. Go to https://jellyfin.paniland.com
3. Should redirect to Authelia SSO
4. Login with SSO credentials
5. Should reach Jellyfin, pick profile (no password needed)

**Internal path test:**
1. Connect to Tailscale
2. Go to https://jellyfin-internal.paniland.com
3. Should reach Jellyfin directly (no Authelia)
4. Pick profile (no password needed)
5. Test from TV app using jellyfin-internal.paniland.com

---

## Phase 2: Proxmox OIDC (Internal Only)

Proxmox stays internal-only (not tunneled). OIDC provides convenience, not external access.

### Task 2.1: Add OIDC Client to Authelia

**Files:**
- Modify: `ansible/playbooks/authelia.yml:71-82`
- Modify: `ansible/vars/secrets.yml`

**Step 1: Generate client secret**

```bash
# Generate raw secret
openssl rand -hex 32
# Save output - you'll need it for both Authelia (hashed) and Proxmox (raw)

# Hash for Authelia config
docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --password '<raw-secret>'
```

**Step 2: Add secret to vault**

```bash
cd ansible
ansible-vault edit vars/secrets.yml
```

Add:
```yaml
vault_authelia_oidc_proxmox_client_secret: "$pbkdf2-sha512$..."  # hashed version
vault_proxmox_oidc_client_secret: "raw-secret-here"  # raw version for Proxmox
```

**Step 3: Add OIDC client to Authelia config**

In `ansible/playbooks/authelia.yml`, add to `authelia_oidc_clients`:

```yaml
- client_id: proxmox
  client_name: Proxmox VE
  client_secret: "{{ vault_authelia_oidc_proxmox_client_secret }}"
  redirect_uris:
    - https://proxmox.paniland.com
  scopes:
    - openid
    - profile
    - email
  authorization_policy: one_factor
```

**Step 4: Apply Authelia playbook**

```bash
ansible-playbook playbooks/authelia.yml
```

**Step 5: Commit**

```bash
git add ansible/playbooks/authelia.yml
git commit -m "feat: add proxmox OIDC client to authelia"
```

---

### Task 2.2: Configure Proxmox OIDC Realm

**Manual steps on Proxmox host:**

Via CLI:
```bash
pveum realm add authelia --type openid \
  --issuer-url https://auth.paniland.com \
  --client-id proxmox \
  --client-key <raw-secret> \
  --username-claim preferred_username \
  --autocreate 1
```

Or via UI: Datacenter → Permissions → Realms → Add → OpenID Connect

---

### Task 2.3: Test Proxmox OIDC

1. Go to https://proxmox.paniland.com (via Tailscale)
2. Select "authelia" realm from dropdown
3. Click Login → redirects to Authelia
4. Login → returns to Proxmox authenticated
5. Verify fallback: Can still login with root@pam

---

## Phase 3: Admin Services (Internal Only, Future)

AdGuard and Backrest stay internal-only with service passwords. Future enhancement: add Authelia forward_auth for convenience on internal network.

**Deferred tasks:**
- Add `authelia_protected: true` to dns.paniland.com and backrest.paniland.com
- Add access rules restricting to `group:admins`
- Keep service passwords as fallback

---

## Files Summary

| File | Changes |
|------|---------|
| `terraform/cloudflare/variables.tf` | Add jellyfin to tunnel_services |
| `ansible/playbooks/proxy.yml` | Add jellyfin.paniland.com (protected), jellyfin-internal.paniland.com (unprotected) |
| `ansible/playbooks/dns.yml` | Add DNS rewrite for jellyfin-internal.paniland.com |
| `ansible/playbooks/authelia.yml` | Add jellyfin access rule, proxmox OIDC client |
| `ansible/vars/secrets.yml` | Add proxmox OIDC client secrets |

---

## Verification Checklist

- [ ] Jellyfin external: SSO required via jellyfin.paniland.com
- [ ] Jellyfin internal: Direct access via jellyfin-internal.paniland.com
- [ ] Jellyfin: Passwordless profile selection works
- [ ] Jellyfin: TV app works via internal path
- [ ] Proxmox: OIDC login via Authelia works
- [ ] Proxmox: root@pam fallback still works

---

## Sources

- [Authelia Forward Auth](https://www.authelia.com/integration/proxies/caddy/)
- [Authelia Proxmox OIDC](https://www.authelia.com/integration/openid-connect/proxmox/)
- [Proxmox User Management](https://pve.proxmox.com/wiki/User_Management)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
