# Homelab Cloud Expansion: SSO, Public Access, and External Monitoring

## Executive Summary

This plan implements a three-component infrastructure expansion:

1. **Authelia SSO (CT312)** - Centralized authentication with TOTP 2FA for all homelab services
2. **Cloudflare Tunnel (CT313)** - Secure public internet access for selected services (wishlist initially)
3. **DigitalOcean Monitoring VPS** - External uptime monitoring to detect full homelab outages

**Total Cost**: ~$18/month (DigitalOcean VPS only, Cloudflare Tunnel is free)

**Timeline**: 3-4 hours total deployment (can be done incrementally)

**Key Learning Goals**: Multi-location IaC, cloud VPS management, SSO implementation, public service exposure

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│ HOMELAB (192.168.1.0/24)                                            │
│                                                                      │
│  CT312 (Authelia)          CT313 (Cloudflare Tunnel)                │
│  192.168.1.112             192.168.1.113                            │
│       │                          │                                  │
│       │                          │ (outbound tunnel)                │
│       │                          ▼                                  │
│       │                    Cloudflare Edge ◄────── Internet Users   │
│       │                          │                                  │
│       │                          ▼                                  │
│       │  ┌────► CT311 (Caddy) ◄──┘                                 │
│       │  │      192.168.1.111                                       │
│       │  │            │                                             │
│       └──┼────────────┘ (forward_auth)                              │
│          │                                                           │
│          ▼                                                           │
│     Services (Jellyfin, Wishlist, Backrest, etc.)                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               │ (Tailscale)
                               │
                               ▼
                    DigitalOcean VPS (monitor.paniland.com)
                    - Uptime Kuma monitoring
                    - Monitors both public and private endpoints
```

**Traffic Flows**:
- **Internal access**: User → Tailscale → Caddy → Authelia → Service
- **Public access**: User → Cloudflare → CT313 → Caddy → Authelia → Service
- **Monitoring**: DO VPS → Tailscale → Services (private) | DO VPS → Cloudflare → Services (public)

## Component 1: Authelia SSO (CT312)

### Purpose
Centralized Single Sign-On authentication protecting all homelab services with TOTP 2FA.

### Architecture Decisions

**Deployment Method**: Native binary installation with systemd
- **Why not Docker**: Matches existing Caddy pattern, minimal resource overhead (~30MB RAM vs ~100MB), direct systemd integration
- **Trade-off**: Manual binary management, no official .deb packages

**Authentication Backend**: File-based with argon2id hashing
- **Why**: Simple to start, expandable to LDAP later
- **Users file**: `/etc/authelia/users.yml` managed via Ansible Vault

**Storage Backend**: SQLite
- **Why**: Sufficient for single-user homelab, upgradeable to PostgreSQL
- **Location**: `/var/lib/authelia/db.sqlite3`

**Session Provider**: In-memory (stateless sessions via cookies)
- **Why**: Lightweight, no Redis dependency initially
- **Future**: Migrate to Redis for HA support

**MFA**: TOTP (Time-based One-Time Password)
- **Setup**: CLI-generated secret or web UI during first login
- **Apps supported**: Google Authenticator, Authy, 1Password, etc.

### Resource Allocation (CT312)
- **CPU**: 1 core
- **RAM**: 512MB (actual usage ~30-50MB)
- **Disk**: 8GB
- **IP**: 192.168.1.112
- **Unprivileged**: Yes (no hardware passthrough needed)

### Caddy Integration

Caddy will use `forward_auth` directive to route all authentication requests through Authelia:

```caddyfile
wishlist.paniland.com {
    # Forward auth to Authelia
    forward_auth 192.168.1.112:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }

    reverse_proxy 192.168.1.186:3280

    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }
}
```

### Protected Services

All existing services will require authentication:
- jellyfin.paniland.com
- backrest.paniland.com
- dns.paniland.com
- proxmox.paniland.com
- unifi.paniland.com
- wishlist.paniland.com

**Access Control Policy**: `two_factor` (username + password + TOTP) for all services

### Critical Files (Authelia)

**Terraform**:
- `terraform/proxmox-homelab/authelia.tf` - CT312 container definition
- `terraform/proxmox-homelab/outputs.tf` - Add authelia outputs

**Ansible**:
- `ansible/roles/authelia/` - Complete role (tasks, handlers, defaults, templates)
- `ansible/playbooks/authelia.yml` - Deployment playbook
- `ansible/inventory/hosts.yml` - Add authelia_containers group
- `ansible/vars/secrets.yml` - JWT secret, session secret, encryption key, admin password hash

**Caddy Integration**:
- `ansible/roles/caddy/templates/Caddyfile.j2` - Add forward_auth directives
- `ansible/roles/caddy/defaults/main.yml` - Add authelia variables
- `ansible/playbooks/proxy.yml` - Set `authelia_enabled: true`

### Deployment Steps (Authelia)

1. **Generate secrets** (JWT, session, encryption key, admin password hash)
2. **Terraform**: Create CT312 container
3. **Ansible**: Create authelia role files
4. **Ansible**: Update inventory with CT312
5. **Ansible**: Deploy authelia (`ansible-playbook playbooks/authelia.yml`)
6. **Update Caddy**: Add forward_auth to Caddyfile, redeploy
7. **DNS**: Add AdGuard rewrite for auth.paniland.com → 192.168.1.112
8. **TOTP Setup**: Navigate to https://auth.paniland.com, enroll TOTP
9. **Test**: Access any service, verify redirect to Authelia, successful auth

**Time Estimate**: 1-1.5 hours

---

## Component 2: Cloudflare Tunnel (CT313)

### Purpose
Expose selected homelab services to the public internet securely via Cloudflare's edge network, without port forwarding.

### Architecture Decisions

**Tunnel Destination**: Caddy reverse proxy (CT311:443)
- **Why**: All services already route through Caddy, consistent architecture, easy expansion
- **Alternative rejected**: Direct to wishlist (less flexible, bypasses centralized logging)

**Tunnel Management**: Terraform with Cloudflare provider
- **Why**: IaC compliance, version control, reproducible disaster recovery
- **Alternative rejected**: Cloudflare dashboard (manual, not version-controlled)

**Initial Service**: wishlist.paniland.com only
- **Future expansion**: Add new services via simple Terraform config + DNS record

### Resource Allocation (CT313)
- **CPU**: 1 core
- **RAM**: 512MB
- **Disk**: 8GB
- **IP**: 192.168.1.113
- **Unprivileged**: No (following infrastructure pattern, though not strictly required)

### Cloudflare Configuration

**Tunnel Setup**:
```hcl
resource "cloudflare_tunnel" "homelab" {
  name   = "homelab-tunnel"
  secret = var.tunnel_secret  # 32-byte secret
}

resource "cloudflare_tunnel_config" "homelab" {
  config {
    ingress_rule {
      hostname = "wishlist.paniland.com"
      service  = "https://192.168.1.111"  # Caddy
      origin_request {
        no_tls_verify = true  # Caddy uses internal certificates
      }
    }
    ingress_rule {
      service = "http_status:404"  # Catch-all
    }
  }
}

resource "cloudflare_record" "wishlist" {
  name    = "wishlist"
  value   = "${cloudflare_tunnel.homelab.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true  # DDoS protection enabled
}
```

### Security Considerations

**DDoS Protection**: Cloudflare absorbs attacks at edge (100+ Tbps capacity)

**Authentication Flow**:
```
Internet → Cloudflare → CT313 cloudflared → CT311 Caddy → CT312 Authelia → CT307 Wishlist
```

**Critical**: Wishlist is publicly accessible but requires Authelia authentication

**No Port Forwarding**: Tunnel is outbound-only connection from CT313

### Critical Files (Cloudflare Tunnel)

**Terraform**:
- `terraform/cloudflare/` - New root module
  - `main.tf` - Provider configuration
  - `variables.tf` - API token, account ID, zone ID, tunnel secret
  - `tunnel.tf` - Tunnel resource, config, DNS records
  - `outputs.tf` - Tunnel ID, token, CNAME
  - `terraform.tfvars` - Secrets (gitignored)

**Ansible**:
- `ansible/roles/cloudflare_tunnel/` - Complete role
- `ansible/playbooks/cloudflare-tunnel.yml` - Deployment playbook
- `ansible/inventory/hosts.yml` - Add cloudflare_tunnel_containers group
- `ansible/vars/secrets.yml` - Add tunnel token from Terraform output

### Deployment Steps (Cloudflare Tunnel)

1. **Terraform** (cloudflare module):
   - Create tunnel resource
   - Configure ingress rules
   - Create DNS CNAME record
   - Extract tunnel token
2. **Terraform** (proxmox module):
   - Create CT313 container
3. **Ansible**:
   - Store tunnel token in vault
   - Create cloudflare_tunnel role
   - Deploy cloudflared daemon
4. **Verification**:
   - Check tunnel status in Cloudflare dashboard
   - Test DNS resolution: `dig wishlist.paniland.com`
   - Test public access: `curl https://wishlist.paniland.com` (should redirect to Authelia)

**Time Estimate**: 1 hour

**Adding New Services** (future):
Just add to Terraform:
```hcl
ingress_rule {
  hostname = "photos.paniland.com"
  service  = "https://192.168.1.111"
}
resource "cloudflare_record" "photos" { ... }
```
Then `terraform apply` - no cloudflared daemon changes needed!

---

## Component 3: DigitalOcean Monitoring VPS

### Purpose
External monitoring to detect complete homelab outages that Tailscale-based monitoring can't catch.

### Architecture Decisions

**VPS Provider**: DigitalOcean
- **Why**: Simple API, good docs, $18/month tier sufficient, familiar to homelab community
- **Alternative**: Hetzner ($4.50/month but Europe-based, higher latency)

**Monitoring Tool**: Uptime Kuma
- **Why**: Beautiful UI, Docker-based, comprehensive checks (HTTP, Ping, DNS, etc.), notification integrations
- **Deployment**: Docker Compose (official recommended method)

**Tailscale Integration**: Yes, VPS joins Tailnet
- **Why**: Can monitor both public endpoints (Cloudflare Tunnel) AND private services (Tailscale-only)
- **Mode**: Client mode (not subnet router)

**Public Access**: Yes, via monitor.paniland.com
- **Why**: Access monitoring dashboard from anywhere (with Authelia protection future)
- **SSL**: Caddy with Cloudflare DNS-01 (same pattern as homelab)

### VPS Specifications

**Droplet**:
- **Size**: s-1vcpu-2gb-amd ($18/month)
- **Region**: NYC3 (closest to East Coast homelab, reduces latency)
- **OS**: Debian 12 (matches homelab containers)
- **Storage**: 50GB SSD
- **Bandwidth**: 2TB/month (monitoring uses negligible bandwidth)

**Why 2GB RAM**: Room for future expansion (Grafana, Prometheus, etc.)

**Downsize Option**: After testing, could drop to 1GB ($6/month) if monitoring-only

### Security Hardening

**Three-Layer Firewall**:
1. **UFW (host-level)**: Drop all except SSH, HTTP, HTTPS, Tailscale
2. **Cloud firewall (DigitalOcean)**: Network-level filtering before traffic reaches VPS
3. **Docker network isolation**: Uptime Kuma on internal network, Caddy on bridge

**SSH Hardening**:
- Key-only authentication (no passwords)
- Root login disabled
- fail2ban for brute force protection

**Automatic Updates**: Unattended upgrades for security patches

### Monitored Endpoints

**Public (via Cloudflare Tunnel)**:
- wishlist.paniland.com

**Private (via Tailscale)**:
- jellyfin.paniland.com
- backrest.paniland.com
- dns.paniland.com
- proxmox.paniland.com
- 192.168.1.100 (Proxmox host ping)
- 192.168.1.102 (Pi4 subnet router)

**Check Types**:
- HTTP (200 OK, <2s response)
- Ping (ICMP, <50ms)
- DNS (query resolution time)

### Critical Files (DigitalOcean Monitoring)

**Terraform**:
- `terraform/digitalocean/` - New root module
  - `main.tf` - Provider configuration
  - `variables.tf` - API token, SSH key, region, size
  - `droplet.tf` - VPS resource with cloud-init
  - `firewall.tf` - Cloud firewall rules
  - `dns.tf` - Optional: monitor.paniland.com DNS record
  - `outputs.tf` - Droplet IP, ID
  - `terraform.tfvars` - Secrets (gitignored)

**Ansible**:
- `ansible/roles/docker/` - Docker + Docker Compose installation
- `ansible/roles/uptime_kuma/` - Uptime Kuma deployment
- `ansible/roles/ufw/` - Firewall configuration
- `ansible/playbooks/monitor.yml` - Orchestrates all roles
- `ansible/inventory/hosts.yml` - Add monitor VPS to cloud_vps group
- `ansible/group_vars/cloud_vps.yml` - Cloud-specific variables

**Docker Compose**:
- `/opt/uptime-kuma/docker-compose.yml` - Service definition
- `/opt/uptime-kuma/data/` - Persistent data volume

### Deployment Steps (DigitalOcean Monitoring)

1. **Prerequisites**:
   - Create DigitalOcean account
   - Generate API token (Read/Write access)
   - Add SSH key to DO account (or let Terraform manage it)
   - Generate Tailscale auth key (tag: `tag:monitor`, reusable, 90-day expiry)

2. **Terraform** (digitalocean module):
   - Configure provider with API token
   - Create droplet with cloud-init (installs Tailscale)
   - Create cloud firewall
   - Optional: Create DNS record for monitor.paniland.com

3. **Ansible**:
   - Add VPS to inventory (use Terraform output for IP)
   - Deploy docker role (install Docker + Docker Compose)
   - Deploy uptime_kuma role (Docker Compose setup)
   - Deploy ufw role (host firewall)
   - Optional: Deploy caddy role (HTTPS for public access)

4. **Uptime Kuma Configuration** (via web UI):
   - Navigate to http://<vps-ip>:3001
   - Create admin account
   - Add monitoring targets (public + private endpoints)
   - Configure notification channels (email, Discord, etc.)

5. **Verification**:
   - SSH to VPS: `ssh root@<vps-ip>`
   - Check Tailscale: `tailscale status`
   - Check Docker: `docker ps`
   - Check Uptime Kuma: `curl http://localhost:3001`
   - Test private endpoint monitoring: Uptime Kuma should reach homelab services via Tailscale

**Time Estimate**: 1.5-2 hours

---

## Integration Points

### 1. Authelia + Caddy
- Caddy's `forward_auth` directive sends authentication checks to Authelia
- Authelia validates session cookie, returns 200 (authenticated) or 302 (redirect to login)
- Caddy proxies request to service only if authenticated

### 2. Cloudflare Tunnel + Caddy + Authelia
- Public traffic arrives at CT313 (cloudflared)
- cloudflared proxies to Caddy (CT311) over HTTPS
- Caddy checks authentication with Authelia (CT312)
- If authenticated, Caddy proxies to wishlist (CT307)

**Security**: All public services require Authelia authentication

### 3. Monitoring + Tailscale
- DO VPS joins Tailscale network as client
- Can ping/HTTP check services on 192.168.1.0/24
- Monitors both public endpoints (Cloudflare) and private endpoints (Tailscale)

**Benefit**: Detects full homelab outages (Proxmox down, power loss, internet down)

### 4. DNS Configuration

**Internal (AdGuard Home)**:
- auth.paniland.com → 192.168.1.112 (Authelia)
- wishlist.paniland.com → 192.168.1.186 (direct) OR 192.168.1.111 (via Caddy)

**External (Cloudflare DNS)**:
- wishlist.paniland.com → CNAME → <tunnel-id>.cfargotunnel.com
- monitor.paniland.com → A → <digitalocean-vps-ip> (optional)

---

## Deployment Sequence

### Phase 1: Foundation (Authelia SSO)
**Why first**: All public services must have authentication before internet exposure

**Steps**:
1. Generate Authelia secrets
2. Terraform: Create CT312
3. Ansible: Create authelia role
4. Ansible: Deploy authelia
5. Update Caddy with forward_auth
6. Configure DNS rewrites
7. Enroll TOTP 2FA
8. Test authentication on all services

**Verification**: All services require login, 2FA works

**Time**: 1-1.5 hours

---

### Phase 2: Public Access (Cloudflare Tunnel)
**Why second**: Requires Authelia to be operational for security

**Steps**:
1. Create Terraform cloudflare module
2. Generate tunnel secret
3. Terraform: Create tunnel, config, DNS records
4. Terraform: Create CT313
5. Extract tunnel token
6. Ansible: Create cloudflare_tunnel role
7. Ansible: Store token in vault
8. Ansible: Deploy cloudflared
9. Verify tunnel connection in Cloudflare dashboard
10. Test public access to wishlist.paniland.com

**Verification**: https://wishlist.paniland.com accessible from internet (with Authelia auth)

**Time**: 1 hour

---

### Phase 3: External Monitoring (DigitalOcean VPS)
**Why last**: Independent of other components, can be deployed anytime

**Steps**:
1. Create DigitalOcean account + API token
2. Generate Tailscale auth key
3. Create Terraform digitalocean module
4. Terraform: Create droplet + firewall
5. Ansible: Create docker, uptime_kuma, ufw roles
6. Ansible: Add VPS to inventory
7. Ansible: Deploy monitoring stack
8. Configure Uptime Kuma via web UI
9. Add monitoring targets (public + private)
10. Set up notification channels

**Verification**: Uptime Kuma shows all services as "UP"

**Time**: 1.5-2 hours

---

## Critical Files Summary

### Files to Create (26 new files)

**Terraform** (14 files):
- `terraform/proxmox-homelab/authelia.tf`
- `terraform/proxmox-homelab/cloudflare-tunnel.tf`
- `terraform/cloudflare/main.tf`
- `terraform/cloudflare/variables.tf`
- `terraform/cloudflare/tunnel.tf`
- `terraform/cloudflare/outputs.tf`
- `terraform/cloudflare/terraform.tfvars.example`
- `terraform/digitalocean/main.tf`
- `terraform/digitalocean/variables.tf`
- `terraform/digitalocean/droplet.tf`
- `terraform/digitalocean/firewall.tf`
- `terraform/digitalocean/outputs.tf`
- `terraform/digitalocean/terraform.tfvars.example`
- `terraform/digitalocean/.gitignore`

**Ansible** (12+ files):
- `ansible/roles/authelia/` (complete role: defaults, tasks, handlers, templates)
- `ansible/roles/cloudflare_tunnel/` (complete role)
- `ansible/roles/docker/` (complete role)
- `ansible/roles/uptime_kuma/` (complete role)
- `ansible/roles/ufw/` (complete role)
- `ansible/playbooks/authelia.yml`
- `ansible/playbooks/cloudflare-tunnel.yml`
- `ansible/playbooks/monitor.yml`
- `ansible/group_vars/cloud_vps.yml`

### Files to Modify (6 files)

**Terraform**:
- `terraform/proxmox-homelab/outputs.tf` - Add authelia + cloudflared outputs

**Ansible**:
- `ansible/inventory/hosts.yml` - Add authelia, cloudflared, monitor hosts
- `ansible/vars/secrets.yml` - Add authelia secrets, cloudflared token
- `ansible/roles/caddy/templates/Caddyfile.j2` - Add forward_auth directives
- `ansible/roles/caddy/defaults/main.yml` - Add authelia variables
- `ansible/playbooks/proxy.yml` - Set authelia_enabled: true

**Documentation**:
- `docs/reference/current-state.md` - Add CT312, CT313, monitoring VPS

---

## Cost Analysis

### One-Time Costs
- **Time investment**: 3-4 hours total deployment
- **Learning**: Multi-location IaC, cloud management, SSO implementation

### Monthly Costs
- **Cloudflare Tunnel**: $0 (free)
- **DigitalOcean VPS**: $18/month (2GB RAM droplet)
- **Authelia (CT312)**: $0 (runs on existing Proxmox)
- **cloudflared (CT313)**: $0 (runs on existing Proxmox)

**Total**: ~$18/month

### Optimization Options
- **Downsize DO droplet**: After testing, 1GB RAM ($6/month) may suffice
- **Alternative provider**: Hetzner Cloud ($4.50/month) if willing to use European datacenter
- **Future expansion**: 2GB RAM allows adding Grafana, Prometheus, or other services to DO VPS

---

## Success Criteria

### Authelia SSO
- [ ] All services redirect to https://auth.paniland.com when unauthenticated
- [ ] Login with username + password + TOTP succeeds
- [ ] Session persists across services (single sign-on works)
- [ ] Logout from one service logs out from all services

### Cloudflare Tunnel
- [ ] https://wishlist.paniland.com accessible from public internet
- [ ] Requires Authelia authentication before viewing
- [ ] Cloudflare dashboard shows tunnel as "Healthy"
- [ ] DNS resolution works: `dig wishlist.paniland.com` returns CNAME

### DigitalOcean Monitoring
- [ ] Uptime Kuma web UI accessible
- [ ] All public endpoints monitored and showing "UP"
- [ ] All private endpoints (via Tailscale) monitored and showing "UP"
- [ ] Test outage detection: Stop a service, verify Uptime Kuma detects downtime
- [ ] Notifications configured and tested

---

## Next Steps

Ready to begin implementation! We can proceed:
1. **Incrementally** - One component at a time (recommended for learning)
2. **All at once** - Deploy all three components in sequence
3. **Custom order** - Start with whichever component interests you most

Each phase is independent and can be rolled back without affecting the others.
