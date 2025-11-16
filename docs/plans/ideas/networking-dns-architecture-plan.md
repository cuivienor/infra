# Networking, DNS & Routing Architecture Plan

**Created**: 2025-11-13
**Updated**: 2025-11-15
**Status**: Planning - Ready for Implementation
**Purpose**: Build resilient DNS and networking infrastructure for seamless local and remote homelab access

---

## Current State Analysis

### What You Have Now

**Network**: UniFi/Ubiquiti router (VLAN-capable)
**Proxmox Host**: 192.168.1.100/24 (Ansible-managed)
**DNS**: None (using 1.1.1.1, 8.8.8.8 via Terraform defaults)
**Remote Access**: None
**Reverse Proxy**: None
**Domain**: paniland.com (owned, not configured)

### Active Containers (All IaC-Managed)

| CTID | Hostname | IP | Cores | RAM | Purpose |
|------|----------|-----|-------|-----|---------|
| 300 | backup | 192.168.1.120 | 2 | 2 GB | Restic + Backrest |
| 301 | samba | 192.168.1.121 | 1 | 1 GB | File shares |
| 302 | ripper | 192.168.1.131 | 2 | 4 GB | MakeMKV ripping |
| 303 | analyzer | 192.168.1.133 | 2 | 4 GB | FileBot + media tools |
| 304 | transcoder | 192.168.1.132 | 4 | 8 GB | FFmpeg GPU encoding |
| 305 | jellyfin | 192.168.1.130 | 4 | 8 GB | Media server (dual GPU) |

**Note**: All containers use Terraform variable `var.dns_servers` (default: `["1.1.1.1", "8.8.8.8"]`)

### Available Infrastructure

- **Raspberry Pi 3B**: 192.168.1.101 (pi3)
- **Raspberry Pi 4B**: 192.168.1.102 (pi4) - **Selected for primary DNS**
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
   │   Subnet Router (on Proxmox host, exposes 192.168.1.0/24)
   │        ↓
   ↓        ↓
UniFi Router (192.168.1.1)
   │
   ├─→ VLAN 1: Management/Trusted (192.168.1.0/24)
   │    ├─ Proxmox Host (192.168.1.100) - Tailscale subnet router
   │    │  ├─ CT300-305: Media pipeline containers (.120-.133)
   │    │  ├─ CT310: Backup DNS (AdGuard + Unbound)
   │    │  └─ CT311: Caddy Reverse Proxy
   │    ├─ Pi4 (192.168.1.102): Primary DNS (AdGuard + Unbound)
   │    ├─ Pi3 (192.168.1.101): Available for other services
   │    └─ Workstations
   │
   ├─→ VLAN 10: Servers (192.168.10.0/24) [future]
   ├─→ VLAN 20: IoT (192.168.20.0/24) [future]
   └─→ VLAN 30: Guests (192.168.30.0/24) [future]

DNS Flow:
  Local Client → AdGuard (Pi4 .102) → Unbound → Root DNS
                      ↓
              jellyfin.paniland.com = 192.168.1.130

  Tailscale Client → AdGuard (via Tailscale) → Unbound
                      ↓
              jellyfin.paniland.com = 100.64.x.x (Tailscale IP)
```

### Split-Horizon DNS Implementation

**Concept**: Same DNS server returns different IPs based on query source

**Method 1: Dual AdGuard Instances** (Recommended)
- Primary AdGuard on Pi4 (port 53) → Returns LAN IPs for LAN clients
- Secondary AdGuard on Pi4 (port 5353) → Returns Tailscale IPs for Tailscale clients
- Tailscale restricted nameserver points to Pi4's Tailscale IP:5353

**Method 2: Single Instance with Conditional Rewrite**
- AdGuard custom DNS rewrites based on source network
- Requires more complex rule configuration

**DNS Records Example** (LAN - port 53):
```
jellyfin.paniland.com   → 192.168.1.130
samba.paniland.com      → 192.168.1.121
backup.paniland.com     → 192.168.1.120
ripper.paniland.com     → 192.168.1.131
transcoder.paniland.com → 192.168.1.132
analyzer.paniland.com   → 192.168.1.133
```

**DNS Records Example** (Tailscale - port 5353):
```
jellyfin.paniland.com   → 100.64.0.x  (Tailscale IP of jellyfin, if Tailscale installed)
samba.paniland.com      → 100.64.0.y  (or use subnet routing to LAN IP)
```

**Note**: Since containers likely won't have Tailscale installed individually, remote clients will use Tailscale subnet routing to reach LAN IPs. The split DNS may not be necessary initially - can start simpler.

### Caddy Reverse Proxy Configuration

**Caddyfile** (CT311 at 192.168.1.111):
```caddyfile
{
    email admin@paniland.com
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

jellyfin.paniland.com {
    reverse_proxy 192.168.1.130:8096
}

backup.paniland.com {
    reverse_proxy 192.168.1.120:9898  # Backrest UI
}

# Future services
# homeassistant.paniland.com {
#     reverse_proxy 192.168.1.170:8123
# }
```

**Note**: Samba (192.168.1.121) uses SMB protocol on ports 139/445, not HTTP. Access via `\\samba\share` or direct IP, not through Caddy.

**Certificate Management**: Let's Encrypt DNS-01 challenge via Cloudflare
- No services need public exposure (no port forwarding required)
- Valid certificates everywhere (internal services get real certs)
- Automatic renewal (Caddy handles this)
- Use staging environment first to avoid rate limits

### Tailscale Configuration

**Subnet Router** (on Proxmox host - 192.168.1.100):
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p

# Advertise subnet
sudo tailscale up --advertise-routes=192.168.1.0/24
```

**Rationale for Proxmox Host**: Always running, stable, central to all traffic. CT310 (backup DNS) is fallback only.

**MagicDNS + Split DNS** (Tailscale admin console):
1. Enable MagicDNS
2. Add custom nameserver: AdGuard Pi4 Tailscale IP (100.64.x.x assigned to Pi4)
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

**1.1 Raspberry Pi 4 Primary DNS** (4 hours)
- Target: Pi4 at 192.168.1.102
- **Option A**: Keep Pi4 at .102, add .110 as alias
- **Option B**: Move Pi4 to .110 (cleaner, matches IP strategy)

```bash
# Install AdGuard Home on Pi4
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh

# Install Unbound for recursive DNS
sudo apt-get install unbound

# Configure AdGuard upstream: 127.0.0.1:5335 (Unbound)
# Add DNS records for paniland.com services:
# - jellyfin.paniland.com → 192.168.1.130
# - samba.paniland.com → 192.168.1.121
# - backup.paniland.com → 192.168.1.120
```

**1.2 CT310 Backup DNS** (3 hours)
- Create container via Terraform: `terraform/dns.tf`
- Deploy AdGuard + Unbound via Ansible: `ansible/playbooks/dns.yml`
- Configure identical to Pi4
- Uses IP 192.168.1.110 (per IP allocation strategy)

**1.3 Client Configuration** (1 hour)
- UniFi DHCP settings:
  - Primary DNS: 192.168.1.102 (Pi4) or .110 if migrated
  - Secondary DNS: 192.168.1.110 (CT310)
- Update Terraform `var.dns_servers`:
  ```hcl
  dns_servers = ["192.168.1.102", "192.168.1.110", "1.1.1.1"]
  ```
- Re-apply Terraform to update all containers
- Test resolution and failover

**Success Criteria**:
- ✅ `nslookup jellyfin.paniland.com` returns 192.168.1.130
- ✅ Ad-blocking works on all clients
- ✅ DNS survives Pi4 shutdown (failover to CT310)

---

### Phase 2: Tailscale Integration (Week 2)

**Objective**: Enable secure remote access

#### Tasks

**2.1 Tailscale Setup** (2 hours)
- Create Tailscale account (free tier sufficient)
- Install on Proxmox host (192.168.1.100) - the subnet router
- Configure subnet router for 192.168.1.0/24
- Install on Pi4 to give it Tailscale IP for split DNS

```bash
# On Proxmox host
curl -fsSL https://tailscale.com/install.sh | sh
sudo sysctl -w net.ipv4.ip_forward=1
sudo tailscale up --advertise-routes=192.168.1.0/24

# On Pi4
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Note the Tailscale IP assigned (e.g., 100.64.x.x)
```

**2.2 Split DNS Configuration** (2 hours)
- Set up secondary AdGuard instance on Pi4 (port 5353) with Tailscale IPs
- Configure Tailscale restricted nameserver pointing to Pi4's Tailscale IP
- Test resolution from remote client

**2.3 Client Testing** (2 hours)
- Install Tailscale on laptop/phone
- Verify remote access to containers via subnet routing
- Test DNS split-horizon (same hostname, different IP based on location)

**Success Criteria**:
- ✅ Can access `jellyfin.paniland.com` remotely via Tailscale
- ✅ Same URL returns LAN IP locally, Tailscale IP remotely
- ✅ Can SSH to containers via hostname: `ssh media@jellyfin` works both local and remote

---

### Phase 3: Reverse Proxy & HTTPS (Week 3)

**Objective**: Implement automatic HTTPS

#### Tasks

**3.1 Cloudflare Setup** (1 hour)
- Add paniland.com to Cloudflare (transfer DNS management)
- Create API token for DNS-01 challenge (Zone:DNS:Edit permissions)
- Store token securely (Ansible Vault)

**3.2 CT311 Caddy Container** (3 hours)
- Create via Terraform: `terraform/proxy.tf` (uses .111)
- Deploy Caddy via Ansible: `ansible/playbooks/proxy.yml`
- Create Ansible role: `ansible/roles/caddy/`
- Configure Caddyfile with services:
  - jellyfin.paniland.com → 192.168.1.130:8096
  - backup.paniland.com → 192.168.1.120:9898 (Backrest UI)

**3.3 Testing** (2 hours)
- Update DNS records to point to CT311 (.111)
- Test HTTPS access to services
- Verify certificates valid (check with Let's Encrypt staging first)
- Test from local and Tailscale

**Success Criteria**:
- ✅ `https://jellyfin.paniland.com` shows valid certificate
- ✅ No browser warnings
- ✅ Works locally and remotely via Tailscale

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

**Note**: These use the BPG Proxmox provider syntax (`proxmox_virtual_environment_container`) to match existing infrastructure.

### CT310: DNS Backup Container

**File**: `terraform/dns.tf`

```hcl
resource "proxmox_virtual_environment_container" "dns" {
  description = "DNS backup - AdGuard Home + Unbound for failover"
  node_name   = "homelab"
  vm_id       = 310

  started      = true
  unprivileged = false  # Match other containers for consistency

  initialization {
    hostname = "dns"

    ip_config {
      ipv4 {
        address = "192.168.1.110/24"  # Per IP allocation strategy
        gateway = "192.168.1.1"
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      keys = local.ssh_public_keys
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024  # 1GB (matches samba, your lightest container)
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  features {
    nesting = true
  }

  tags = ["dns", "infrastructure", "iac"]

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
```

### CT311: Caddy Reverse Proxy

**File**: `terraform/proxy.tf`

```hcl
resource "proxmox_virtual_environment_container" "proxy" {
  description = "Caddy reverse proxy - automatic HTTPS via Let's Encrypt DNS-01"
  node_name   = "homelab"
  vm_id       = 311

  started      = true
  unprivileged = false  # May need privileged for port 443 binding

  initialization {
    hostname = "proxy"

    ip_config {
      ipv4 {
        address = "192.168.1.111/24"  # Per IP allocation strategy
        gateway = "192.168.1.1"
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      keys = local.ssh_public_keys
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024  # 1GB
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  features {
    nesting = false  # Not needed for Caddy
  }

  tags = ["proxy", "infrastructure", "iac"]

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
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

1. **Pre-implementation tasks**:
   - [ ] Set up Pi4 (192.168.1.102) with Raspberry Pi OS if not already
   - [ ] Create Cloudflare account and add paniland.com
   - [ ] Create Tailscale account
   - [ ] Fix current-state.md with correct container IPs (they're already on target IPs!)

2. **Phase 1 Decision**: Pi4 IP strategy
   - **Option A**: Keep Pi4 at .102, use for DNS as-is
   - **Option B**: Move Pi4 to .110 (matches IP allocation strategy for "Network, DNS & Security" range)
   - **Recommendation**: Option A for now, keeps Pi stable; CT310 backup at .110 is sufficient

3. **Start Phase 1** - DNS infrastructure on Pi4
4. **Incremental validation** - Test each phase before proceeding

**Estimated time**: 4 weeks (working incrementally)

---

## IP Allocation Summary (After Implementation)

| IP | Service | Type | Status |
|----|---------|------|--------|
| .100 | Proxmox host | Physical | ✅ Active |
| .101 | Pi3 | Physical | ✅ Active (available) |
| .102 | Pi4 + AdGuard Primary | Physical | 🎯 Phase 1 |
| .110 | CT310 DNS Backup | LXC | 🎯 Phase 1 |
| .111 | CT311 Caddy Proxy | LXC | 🎯 Phase 3 |
| .120 | CT300 backup | LXC | ✅ Active |
| .121 | CT301 samba | LXC | ✅ Active |
| .130 | CT305 jellyfin | LXC | ✅ Active |
| .131 | CT302 ripper | LXC | ✅ Active |
| .132 | CT304 transcoder | LXC | ✅ Active |
| .133 | CT303 analyzer | LXC | ✅ Active |

---

## Related Documentation

- [Current State](../../reference/current-state.md) - **Note: Container IPs need updating**
- [IP Allocation Strategy](../../reference/ip-allocation-strategy.md)
- [Terraform Variables](../../../terraform/variables.tf) - DNS servers config

---

**Status**: 📋 Planning - Ready for implementation  
**Decisions Made**: Pi4 for primary DNS, Proxmox host for Tailscale subnet router, CT310/311 for backup DNS and proxy
