# Networking, DNS & Routing Architecture Plan

**Created**: 2025-11-13
**Status**: Planning
**Purpose**: Build resilient DNS and networking infrastructure for seamless local and remote homelab access

---

## Current State Analysis

### What You Have Now

**Network**: UniFi/Ubiquiti router (VLAN-capable)
**Proxmox Host**: 192.168.1.56/24
**DNS**: None (using router or ISP defaults)
**Remote Access**: None
**Reverse Proxy**: None
**Domain**: paniland.com (owned, not configured)

### Active Containers

| CTID | Name | IP | Purpose |
|------|------|-----|---------|
| 300 | backup | 192.168.1.58 | Backups (Restic) |
| 301 | samba | 192.168.1.82 | File shares |
| 302 | ripper | 192.168.1.70 | Blu-ray ripping |
| 303 | analyzer | 192.168.1.73 | Media analysis |
| 304 | transcoder | 192.168.1.77 | FFmpeg transcoding |
| 305 | jellyfin | 192.168.1.85 | Media server |

### Available Infrastructure

- **Raspberry Pi(s)**: Available for dedicated services
- **UniFi Router**: Can handle VLANs and firewall rules
- **Domain**: paniland.com ready to configure

### Current Pain Points

1. ❌ No consistent naming (must remember IP addresses)
2. ❌ No remote access solution
3. ❌ No HTTPS for services
4. ❌ No network segmentation for future IoT devices

---

## Goals & Requirements

### Core Requirements

**FR1: Stable Service Names**
- Access services via memorable names: `jellyfin.paniland.com`, `ssh media@jellyfin`
- DNS-based service discovery

**FR2: Transparent Local/Remote Access**
- Same URLs work whether on LAN or remote via Tailscale
- Split-horizon DNS returns appropriate IPs automatically

**FR3: IoT Device Access**
- Access devices that can't run Tailscale (AVR, smart switches, etc.)
- Via Tailscale subnet router

**FR4: Automatic HTTPS**
- Valid certificates from Let's Encrypt
- No browser warnings
- No public exposure required

**FR5: High Availability DNS**
- Survives single point of failure
- Automatic failover

**FR6: Network Segmentation**
- Isolated VLANs for servers, IoT, guests
- Firewall rules prevent unauthorized access

---

## Recommended Architecture

### Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **DNS Primary** | AdGuard Home + Unbound on Raspberry Pi | Most resource-efficient, encrypted DNS built-in |
| **DNS Backup** | AdGuard Home + Unbound on CT306 (LXC) | Automatic failover via DHCP |
| **VPN** | Tailscale | Zero-config NAT traversal, subnet routing |
| **Reverse Proxy** | Caddy on CT307 (LXC) | Simplest config, automatic HTTPS |
| **VLANs** | UniFi managed | Native router support |

**Why AdGuard over Pi-hole**: More resource-efficient (130MB vs 138MB), encrypted DNS built-in, better for IoT device management

**Why Caddy over Traefik**: Simpler for LXC-heavy setup, excellent auto-HTTPS, still supports Docker via plugin when needed

**Why Tailscale over WireGuard**: Built-in NAT traversal, MagicDNS, ACLs, subnet routing - all zero-config

### High-Level Architecture

```
Internet
   │
   ├─→ Tailscale (remote clients)
   │        ↓
   │   Subnet Router (exposes 192.168.1.0/24)
   │        ↓
   ↓        ↓
UniFi Router
   │
   ├─→ VLAN 1: Management/Trusted (192.168.1.0/24)
   │    ├─ Raspberry Pi: Primary DNS (AdGuard + Unbound)
   │    ├─ Proxmox Host (192.168.1.56)
   │    │  ├─ CT306: Backup DNS (AdGuard + Unbound + Tailscale)
   │    │  ├─ CT307: Caddy Reverse Proxy
   │    │  └─ CT300-305: Existing containers
   │    └─ Workstations
   │
   ├─→ VLAN 10: Servers (192.168.10.0/24) [future]
   ├─→ VLAN 20: IoT (192.168.20.0/24) [future]
   └─→ VLAN 30: Guests (192.168.30.0/24) [future]

DNS Flow:
  Local Client → AdGuard (Pi) → Unbound → Root DNS
                      ↓
              jellyfin.paniland.com = 192.168.1.85

  Tailscale Client → AdGuard (via Tailscale) → Unbound
                      ↓
              jellyfin.paniland.com = 100.64.x.x
```

### Split-Horizon DNS Implementation

**Concept**: Same DNS server returns different IPs based on query source

**Method 1: Dual AdGuard Instances** (Recommended)
- Primary AdGuard on Pi (port 53) → Returns LAN IPs for LAN clients
- Secondary AdGuard on Pi (port 5353) → Returns Tailscale IPs for Tailscale clients
- Tailscale restricted nameserver points to port 5353

**Method 2: Single Instance with Conditional Rewrite**
- AdGuard custom DNS rewrites based on source network
- Requires more complex rule configuration

**DNS Records Example** (LAN):
```
jellyfin.paniland.com  → 192.168.1.85
samba.paniland.com     → 192.168.1.82
```

**DNS Records Example** (Tailscale):
```
jellyfin.paniland.com  → 100.64.0.85
samba.paniland.com     → 100.64.0.82
```

### Caddy Reverse Proxy Configuration

**Caddyfile** (CT307):
```caddyfile
{
    email admin@paniland.com
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

jellyfin.paniland.com {
    reverse_proxy 192.168.1.85:8096
}

samba.paniland.com {
    reverse_proxy 192.168.1.82:80
}

homeassistant.paniland.com {
    reverse_proxy 192.168.1.X:8123
}
```

**Certificate Management**: Let's Encrypt DNS-01 challenge via Cloudflare
- No services need public exposure
- Valid certificates everywhere
- Automatic renewal

### Tailscale Configuration

**Subnet Router** (on Proxmox host or CT306):
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p

# Advertise subnet
sudo tailscale up --advertise-routes=192.168.1.0/24
```

**MagicDNS + Split DNS** (Tailscale admin console):
1. Enable MagicDNS
2. Add custom nameserver: AdGuard Pi Tailscale IP
3. Restrict to domain: `paniland.com`
4. Enable "Override local DNS"

**ACL Example**:
```json
{
  "groups": {
    "group:admins": ["peter@example.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["group:admins"],
      "dst": ["192.168.1.0/24:*"]
    }
  ]
}
```

### Network Segmentation (UniFi VLANs)

**VLAN Structure**:

| VLAN | Network | Purpose | Firewall Rules |
|------|---------|---------|----------------|
| 1 | 192.168.1.0/24 | Management + Trusted | Allow all |
| 10 | 192.168.10.0/24 | Servers (future) | Trusted → Servers, block reverse |
| 20 | 192.168.20.0/24 | IoT (future) | Allow internet, Trusted → IoT, block IoT → others |
| 30 | 192.168.30.0/24 | Guests (future) | Internet only |

**IoT VLAN Firewall Rules**:
```
1. Allow IoT → Internet (ports 53, 123, 80, 443)
2. Allow Trusted → IoT (initiate)
3. Deny IoT → Trusted (initiate)
4. Deny IoT → Servers
```

---

## Implementation Plan

### Phase 1: DNS Infrastructure (Week 1)

**Objective**: Establish resilient DNS with ad-blocking

#### Tasks

**1.1 Raspberry Pi Primary DNS** (4 hours)
```bash
# Install AdGuard Home
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh

# Install Unbound
sudo apt-get install unbound

# Configure AdGuard upstream: 127.0.0.1:5335 (Unbound)
# Add DNS records for paniland.com services
```

**1.2 CT306 Backup DNS** (3 hours)
- Create container via Terraform: `terraform/ct306-dns.tf`
- Deploy AdGuard + Unbound via Ansible: `ansible/playbooks/ct306-dns.yml`
- Configure identical to Pi

**1.3 Client Configuration** (1 hour)
- UniFi DHCP settings:
  - Primary DNS: 192.168.1.53 (Pi)
  - Secondary DNS: 192.168.1.54 (CT306)
- Test resolution and failover

**Success Criteria**:
- ✅ `nslookup jellyfin.paniland.com` returns correct IP
- ✅ Ad-blocking works on all clients
- ✅ DNS survives Pi shutdown (failover to CT306)

---

### Phase 2: Tailscale Integration (Week 2)

**Objective**: Enable secure remote access

#### Tasks

**2.1 Tailscale Setup** (2 hours)
- Create Tailscale account
- Install on Proxmox host or CT306
- Configure subnet router for 192.168.1.0/24

**2.2 Split DNS Configuration** (2 hours)
- Set up secondary AdGuard instance on Pi (port 5353) with Tailscale IPs
- Configure Tailscale restricted nameserver
- Test resolution from remote client

**2.3 Client Testing** (2 hours)
- Install Tailscale on laptop/phone
- Verify remote access to containers
- Test DNS split-horizon

**Success Criteria**:
- ✅ Can access `jellyfin.paniland.com` remotely
- ✅ Same URL returns different IP when local vs. remote
- ✅ Can SSH to containers via hostname remotely

---

### Phase 3: Reverse Proxy & HTTPS (Week 3)

**Objective**: Implement automatic HTTPS

#### Tasks

**3.1 Cloudflare Setup** (1 hour)
- Add paniland.com to Cloudflare
- Create API token for DNS-01 challenge

**3.2 CT307 Caddy Container** (3 hours)
- Create via Terraform: `terraform/ct307-proxy.tf`
- Deploy Caddy via Ansible: `ansible/playbooks/ct307-proxy.yml`
- Configure Caddyfile with services

**3.3 Testing** (2 hours)
- Test HTTPS access to services
- Verify certificates valid
- Test from local and Tailscale

**Success Criteria**:
- ✅ `https://jellyfin.paniland.com` shows valid certificate
- ✅ No browser warnings
- ✅ Works locally and remotely

---

### Phase 4: Network Segmentation (Week 4)

**Objective**: Isolate network segments

#### Tasks

**4.1 VLAN Creation** (2 hours)
- Create VLANs 10, 20, 30 in UniFi
- Configure DHCP scopes

**4.2 Firewall Rules** (3 hours)
- Implement IoT isolation rules
- Implement guest isolation rules
- Test with temporary devices

**4.3 Tailscale Route Updates** (1 hour)
- Update subnet routes to include new VLANs
- Test remote access to all VLANs

**Success Criteria**:
- ✅ IoT devices can't initiate to trusted VLAN
- ✅ Guests can only access internet
- ✅ Services still accessible from trusted VLAN

---

## Terraform Configurations

### CT306: DNS Backup Container

**File**: `terraform/ct306-dns.tf`

```hcl
resource "proxmox_lxc" "ct306_dns" {
  target_node  = "homelab"
  hostname     = "dns-backup"
  ostemplate   = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  unprivileged = true

  cores  = 1
  memory = 512
  swap   = 512

  rootfs {
    storage = "local-lvm"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.1.54/24"
    gw     = "192.168.1.1"
  }

  features {
    nesting = true
  }

  start = true
  onboot = true

  tags = "dns,infrastructure"
}
```

### CT307: Caddy Reverse Proxy

**File**: `terraform/ct307-proxy.tf`

```hcl
resource "proxmox_lxc" "ct307_proxy" {
  target_node  = "homelab"
  hostname     = "caddy"
  ostemplate   = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  unprivileged = true

  cores  = 1
  memory = 1024
  swap   = 512

  rootfs {
    storage = "local-lvm"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.1.80/24"
    gw     = "192.168.1.1"
  }

  start = true
  onboot = true

  tags = "proxy,infrastructure"
}
```

---

## Ansible Roles

### Role: adguard_home

**File**: `ansible/roles/adguard_home/tasks/main.yml`

```yaml
---
- name: Install AdGuard Home
  shell: |
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh
  args:
    creates: /opt/AdGuardHome/AdGuardHome

- name: Install Unbound
  apt:
    name: unbound
    state: present

- name: Configure Unbound
  template:
    src: unbound.conf.j2
    dest: /etc/unbound/unbound.conf.d/homelab.conf
  notify: restart unbound

- name: Start and enable services
  systemd:
    name: "{{ item }}"
    state: started
    enabled: yes
  loop:
    - AdGuardHome
    - unbound
```

### Role: caddy

**File**: `ansible/roles/caddy/tasks/main.yml`

```yaml
---
- name: Install Caddy
  shell: |
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/setup.deb.sh' | sudo -E bash
    apt-get install caddy
  args:
    creates: /usr/bin/caddy

- name: Create Caddyfile
  template:
    src: Caddyfile.j2
    dest: /etc/caddy/Caddyfile
  notify: reload caddy

- name: Set Cloudflare API token
  lineinfile:
    path: /etc/default/caddy
    line: "CLOUDFLARE_API_TOKEN={{ cloudflare_api_token }}"
    create: yes
  notify: restart caddy

- name: Start and enable Caddy
  systemd:
    name: caddy
    state: started
    enabled: yes
```

### Role: tailscale_subnet_router

**File**: `ansible/roles/tailscale_subnet_router/tasks/main.yml`

```yaml
---
- name: Install Tailscale
  shell: |
    curl -fsSL https://tailscale.com/install.sh | sh
  args:
    creates: /usr/bin/tailscale

- name: Enable IP forwarding
  sysctl:
    name: net.ipv4.ip_forward
    value: '1'
    state: present
    sysctl_file: /etc/sysctl.d/99-tailscale.conf

- name: Start Tailscale with subnet routing
  command: >
    tailscale up
    --authkey={{ tailscale_auth_key }}
    --advertise-routes={{ tailscale_advertised_routes }}
    --accept-routes
  args:
    creates: /var/lib/tailscale/tailscaled.state
```

---

## Alternative Approaches

### Alternative 1: Pi-hole Instead of AdGuard Home

**Pros**: Larger community, more tutorials
**Cons**: Less resource-efficient, no built-in encrypted DNS
**When to choose**: If already familiar with Pi-hole

### Alternative 2: Traefik Instead of Caddy

**Pros**: Better Docker auto-discovery
**Cons**: More complex for static LXC containers
**When to choose**: If moving to Docker-heavy setup

### Alternative 3: OPNsense/pfSense All-in-One

**Pros**: Single management interface, integrated
**Cons**: Requires dedicated hardware, less flexible
**When to choose**: If upgrading router infrastructure

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| DNS failure (both Pi + CT306) | Low | High | Dual DNS + static /etc/hosts backup |
| Tailscale account compromise | Low | High | 2FA, ACLs, regular audit |
| Let's Encrypt rate limit | Low | Medium | Use staging for testing |
| Pi hardware failure | Medium | Medium | Auto-failover to CT306, keep spare |
| Split DNS config drift | Medium | Medium | IaC for CT306, sync scripts |

---

## Success Criteria

### Overall Project Success

- [ ] Access any homelab service by name from anywhere
- [ ] Experience identical whether on LAN or remote
- [ ] All web services use valid HTTPS
- [ ] No ports forwarded on router
- [ ] Network properly segmented for security
- [ ] Infrastructure defined in code (reproducible)

### Phase Validation

**Phase 1**: DNS working, ad-blocking active, failover tested
**Phase 2**: Remote access via Tailscale, split DNS operational
**Phase 3**: HTTPS working with valid certificates
**Phase 4**: VLANs isolating traffic appropriately

---

## Next Steps

1. **Review this plan** - Adjustments needed?
2. **Gather prerequisites**:
   - Raspberry Pi with Raspberry Pi OS
   - Cloudflare account for paniland.com
   - Tailscale account
3. **Start Phase 1** - DNS infrastructure
4. **Incremental validation** - Test each phase before proceeding

**Estimated time**: 4 weeks (working incrementally)

---

## Related Documentation

- [Current State](../reference/current-state.md)
- [Homelab IaC Strategy](../reference/homelab-iac-strategy.md)
- [Container README](../containers/README.md)

---

**Status**: 📋 Planning - Ready for review
