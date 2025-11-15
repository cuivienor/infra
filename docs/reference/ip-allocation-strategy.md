# IP Address Allocation Strategy

**Created:** 2025-11-14  
**Status:** Active  
**Purpose:** Standardized IP allocation for homelab infrastructure

## Design Principles

1. **Predictable ranges** - Group services by function
2. **Room for growth** - Leave gaps between service types
3. **Static allocations** - Infrastructure gets reserved IPs
4. **DHCP pools** - Clients get dynamic IPs from designated ranges
5. **Documentation** - Every static IP must be documented

## Current Network: 192.168.1.0/24 (VLAN 1)

### Allocation Map

```
192.168.1.0/24 - Primary Network (VLAN 1)
├─ .1           - Gateway (USG/Cloud Gateway Max)
├─ .2-.20       - Network Infrastructure (Switches, APs, Controller)
├─ .21-.99      - DHCP Pool (Workstations, phones, laptops) [ACTIVE]
├─ .100-.149    - Static: Infrastructure Services (Proxmox, DNS, Containers)
├─ .150-.199    - Static: Future Services
└─ .200-.254    - Static: Reserved for expansion
```

### Detailed Allocations

#### Infrastructure (.1-.79)

| IP | Device/Service | Type | Status | Notes |
|----|----------------|------|--------|-------|
| .1 | Gateway | Router | Active | USG (will become Cloud Gateway Max) |
| .2 | Reserved | - | Reserved | Future infrastructure |
| .3 | Reserved | - | Reserved | Future infrastructure |
| .4 | Reserved | - | Reserved | Future infrastructure |
| .5 | Main Switch | UniFi Switch | Active | USL16LP (24:5a:4c:59:77:d7) |
| .6 | Living Room AP | UniFi AP | Active | UAL6 (24:5a:4c:11:47:58) |
| .7 | Bedroom AP | UniFi AP | Active | UAL6 (24:5a:4c:11:47:d4) |
| .8 | Lab Switch | UniFi Switch | Active | USMINI (68:d7:9a:31:c8:de) |
| .9 | Bedroom Switch | UniFi Switch | Active | USMINI (68:d7:9a:31:c9:19) |
| .10 | Living Room Switch | UniFi Switch | Active | USMINI (68:d7:9a:31:c9:26) |
| .11 | UniFi Controller | Cloud Key | Active | f0:9f:c2:c6:d7:af |
| .12-.20 | Reserved | - | Reserved | Future network infrastructure |
| .21-.99 | **DHCP Range** | Dynamic | **✅ Active** | Workstations, laptops, phones (79 addresses) |

#### Infrastructure Services & Containers (.100-.149)

| IP | Device/Service | Type | Status | Notes |
|----|----------------|------|--------|-------|
| .100 | **Proxmox Host** | Physical | ✅ Active | 70:85:c2:a5:c3:c4 - Managed by Ansible |
| .101-.106 | Reserved | - | Available | Future hypervisors/infrastructure |
| .107 | **Pi-hole** | Raspberry Pi | Active | b8:27:eb:7c:24:24 - Will retire |
| .108-.113 | Reserved | - | Available | Future services |
| .114 | **Raspberry Pi** | Physical | Active | dc:a6:32:d4:85:77 - Will migrate to .53 for DNS |
| .115-.139 | Reserved | - | Available | Future application containers |
| .140 | Reserved | - | Available | Future services |
| .141 | **NVidia Shield TV** | Media Player | Active | 48:b0:2d:92:b7:be - Static reservation |
| .142-.149 | Reserved | - | Available | Future services |

#### IoT Devices (.150-.199) - Temporary

**These will migrate to VLAN 20 (192.168.20.0/24) in Phase 4**

| IP Range | Device Type | Status |
|----------|-------------|--------|
| .150-.159 | Smart home hubs | Will migrate to VLAN 20 |
| .160-.169 | Smart speakers/displays | Will migrate to VLAN 20 |
| .170-.179 | Cameras | Will migrate to VLAN 20 |
| .180-.189 | Smart appliances | Will migrate to VLAN 20 |
| .190-.199 | Misc IoT | Will migrate to VLAN 20 |

#### DHCP Overflow (.200-.254)

| IP Range | Purpose | Status |
|----------|---------|--------|
| .200-.254 | DHCP overflow | Active |

## Planned VLANs (Phase 4)

### VLAN 10: Servers (192.168.10.0/24)

**Purpose:** Isolated server environment (future migration)

```
192.168.10.0/24 - Server Network (VLAN 10)
├─ .1           - Gateway
├─ .2-.9        - Reserved
├─ .10-.49      - Application servers
├─ .50-.79      - Database servers
├─ .80-.99      - Infrastructure services
└─ .100-.254    - Reserved for expansion
```

**Migration candidates from VLAN 1:**
- Consider moving media pipeline here eventually
- Application containers

### VLAN 20: IoT (192.168.20.0/24)

**Purpose:** Isolated IoT devices (already partially configured!)

```
192.168.20.0/24 - IoT Network (VLAN 20) [EXISTING]
├─ .1           - Gateway
├─ .6-.254      - DHCP Pool (IoT devices)
├─ .15          - Philips Hue Bridge (00:17:88:a3:6b:c4)
├─ .17          - Lutron Hub (60:64:05:4e:dc:d1)
├─ .18          - Already in use
├─ .21-.51      - Various IoT devices (Nest, Levoit, etc.)
```

**Current allocations on VLAN 20:**
- .15: Philips Hue Bridge (wired, Port 15 Main Switch)
- .17: Lutron Hub (wired, Port 14 Main Switch)  
- .18-.51: Various wireless IoT (see network-topology-detailed.md)

**No static allocation needed** - IoT devices work fine with DHCP

### VLAN 30: Guest (192.168.30.0/24)

**Purpose:** Guest WiFi isolation

```
192.168.30.0/24 - Guest Network (VLAN 30)
├─ .1           - Gateway
└─ .10-.254     - DHCP Pool (guests only)
```

**No static allocations** - All DHCP

## Container IP Allocation Process

### New Container Checklist

When creating a new container:

1. **Determine category:**
   - Infrastructure? (.50-.79)
   - Media pipeline? (.80-.99)
   - Application? (.100-.149)

2. **Check allocation table** (this document)

3. **Pick next available IP** in that range

4. **Update this document BEFORE deploying:**
   ```bash
   vim docs/reference/ip-allocation-strategy.md
   git add docs/reference/ip-allocation-strategy.md
   git commit -m "docs: reserve .XX for CT30X (service-name)"
   ```

5. **Deploy via Terraform** with static IP:
   ```hcl
   network {
     name   = "eth0"
     bridge = "vmbr0"
     ip     = "192.168.1.XX/24"
     gw     = "192.168.1.1"
   }
   ```

6. **Add to DNS** (after Phase 1):
   - Update AdGuard Home custom DNS
   - Or update Ansible DNS role

### Example: New Container

**Scenario:** Adding CT308 for Home Assistant

**Process:**
```bash
# 1. Check this doc - Application range is .100-.149
# 2. .100 is first in home automation range (.100-.109)
# 3. Update this doc:
#    | .100 | Home Assistant | 308 | Planned | Home automation |

# 4. Create Terraform config
cat > terraform/ct308-homeassistant.tf << 'EOF'
resource "proxmox_lxc" "ct308_homeassistant" {
  target_node = "homelab"
  hostname    = "homeassistant"
  ostemplate  = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.1.100/24"  # From allocation strategy
    gw     = "192.168.1.1"
  }
  
  tags = "homeautomation,application"
}
EOF

# 5. Deploy
terraform apply

# 6. Add DNS entry (manual for now, automated after Phase 1)
# AdGuard: homeassistant.paniland.com → 192.168.1.100
```

## DHCP Configuration

### Current DHCP Pools (VLAN 1)

**✅ Configured:** 192.168.1.21 - 192.168.1.99 (79 addresses)

**Allocation:**
```
.1-.20:         Network Infrastructure (Switches, APs, Controller)
.21-.99:        DHCP Pool (Workstations, phones, laptops) ✅ ACTIVE
.100-.254:      Static Infrastructure & Services (Proxmox, Containers, etc.)
```

**What happened to devices with IPs above .99?**
- **Static/Reserved IPs (.114, .141):** Unaffected - they keep their IPs
- **DHCP clients (.106, .115, .124, .220, .225, .253):** Will get new IPs from .21-.99 range when their lease expires or they reconnect
- **Impact:** Minimal - phones/laptops handle IP changes automatically

**Implementation:**
- Configured via UniFi Controller API on 2025-11-14
- USG automatically provisioned with new settings
- No service interruption

### Static DHCP Reservations

**Core infrastructure only** (everything else gets static IP in container config):

| MAC | IP | Device | Method |
|-----|-----|--------|--------|
| 24:5a:4c:59:77:d7 | .5 | Main Switch | Static (UniFi Controller) |
| 24:5a:4c:11:47:58 | .6 | Living Room AP | Static (UniFi Controller) |
| 24:5a:4c:11:47:d4 | .7 | Bedroom AP | Static (UniFi Controller) |
| 68:d7:9a:31:c8:de | .8 | Lab Switch | Static (UniFi Controller) |
| 68:d7:9a:31:c9:19 | .9 | Bedroom Switch | Static (UniFi Controller) |
| 68:d7:9a:31:c9:26 | .10 | Living Room Switch | Static (UniFi Controller) |
| f0:9f:c2:c6:d7:af | .11 | Cloud Key | Static (UniFi Controller) |
| 70:85:c2:a5:c3:c4 | .100 | Proxmox Host | ✅ Static (Ansible-managed) |
| dc:a6:32:d4:85:77 | .114 | Raspberry Pi | DHCP Reservation (will migrate to .53 for DNS) |
| 48:b0:2d:92:b7:be | .141 | NVidia Shield TV | DHCP Reservation |

**Why DHCP reservation for some, static for others?**
- **DHCP reservations:** Physical devices, UniFi gear (managed by controller)
- **Static in config:** LXC containers (defined in Terraform)

### After Hardware Upgrade

When you get Cloud Gateway Max + new switches:

**Remove DHCP reservations:**
- Old switches (.44, .112, .113) - no longer exist

**Add DHCP reservations:**
- New USW-Flex-Mini switches (if you keep them in .44, .112, .113 ranges)

**Or better:** Let Cloud Gateway Max auto-assign IPs to UniFi devices, document them here after adoption.

## Integration with DNS Plan

### Phase 1: Manual DNS Entries

**AdGuard Home custom DNS rewrites:**

```
# Infrastructure
homelab.paniland.com        → 192.168.1.56
switch.paniland.com         → 192.168.1.5
ap-living.paniland.com      → 192.168.1.6
ap-bedroom.paniland.com     → 192.168.1.7

# Services (current)
backup.paniland.com         → 192.168.1.58
samba.paniland.com          → 192.168.1.82
ripper.paniland.com         → 192.168.1.70
analyzer.paniland.com       → 192.168.1.73
transcoder.paniland.com     → 192.168.1.77
jellyfin.paniland.com       → 192.168.1.85

# Services (planned)
dns.paniland.com            → 192.168.1.53  (Pi)
dns-backup.paniland.com     → 192.168.1.54  (CT306)
proxy.paniland.com          → 192.168.1.80  (CT307)
```

### Phase 2+: Automated DNS

**Option A: Ansible-managed AdGuard config**

Create DNS entries via Ansible variable:

```yaml
# ansible/group_vars/all/dns.yml
dns_entries:
  - { name: "jellyfin.paniland.com", ip: "192.168.1.85" }
  - { name: "samba.paniland.com", ip: "192.168.1.82" }
  # ... etc
```

**Option B: Dynamic DNS via Terraform**

After hardware upgrade, use Terraform to manage DNS records directly.

## IP Renumbering Plan (Optional)

**Current state has some non-optimal allocations.** If you want perfect organization:

### Renumbering Proposal

| Current IP | New IP | Service | Reason |
|------------|--------|---------|--------|
| .73 | .83 | CT303: Analyzer | Move to media pipeline range |
| .107 | Retire | Pi-hole | Replaced by .53 (AdGuard on Pi) |
| .114 | .53 | Raspberry Pi | Becomes DNS Primary |

**When to renumber:**
- During Phase 1 implementation (DNS setup)
- Update container IPs in Terraform
- Re-provision affected containers

**Or:** Don't renumber, just follow allocation strategy for NEW containers going forward.

## Troubleshooting

### IP Conflict Detection

```bash
# From any Linux machine on network
sudo nmap -sn 192.168.1.0/24

# Check for duplicates
sudo arp-scan --interface=eth0 --localnet | sort -k2
```

### Finding Next Available IP

```bash
# Quick check what's used
nmap -sn 192.168.1.50-99

# Or check this document + current state doc
```

### Migrating Container IP

```bash
# Example: Move CT303 from .73 to .83

# 1. Update Terraform
vim terraform/ct303-analyzer.tf
# Change IP: "192.168.1.73/24" → "192.168.1.83/24"

# 2. Apply (will recreate container)
terraform apply

# 3. Redeploy with Ansible
ansible-playbook ansible/playbooks/ct303-analyzer.yml

# 4. Update DNS entries
# AdGuard: analyzer.paniland.com → 192.168.1.83

# 5. Update this document
vim docs/reference/ip-allocation-strategy.md
```

## Migration Timeline

### Immediate (Before DNS Plan)

- [x] Document current allocations
- [ ] Add static DHCP reservations for infrastructure
- [ ] Verify no conflicts in .50-.99 range

### Phase 1: DNS Infrastructure

- [ ] Assign .53 to Raspberry Pi (move from .114)
- [ ] Deploy CT306 at .54 (DNS Backup)
- [ ] Update DHCP to use new DNS servers

### Phase 2: Tailscale

- [ ] Assign Tailscale IPs (handled by Tailscale)
- [ ] Document Tailscale IP range (100.64.0.0/10)

### Phase 3: Reverse Proxy

- [ ] Deploy CT307 at .80 (Caddy)

### Phase 4: VLAN Migration

- [ ] No changes to VLAN 1 allocations
- [ ] IoT devices stay on VLAN 20 DHCP
- [ ] Future servers can use VLAN 10

## Related Documentation

- [Network Topology (Detailed)](network-topology-detailed.md) - Current network state
- [Networking DNS Architecture Plan](../plans/ideas/networking-dns-architecture-plan.md) - DNS implementation plan
- [Current State](current-state.md) - Overall homelab state

## Quick Reference Card

```
VLAN 1 (192.168.1.0/24) - Primary Network
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
.1              Gateway (USG/Cloud Gateway Max)
.2-.5           Reserved (future infrastructure)
.6-.49          DHCP Pool (workstations)
.50-.79         Static: Infrastructure Services
                ├─ .53: DNS Primary (Raspberry Pi)
                ├─ .54: DNS Backup (CT306)
                ├─ .56: Proxmox Host
                ├─ .58: CT300 Backup
                ├─ .70: CT302 Ripper
                └─ .77: CT304 Transcoder
.80-.99         Static: Media Pipeline
                ├─ .80: CT307 Caddy Proxy
                ├─ .82: CT301 Samba
                ├─ .83: (Future) CT303 Analyzer
                └─ .85: CT305 Jellyfin
.100-.149       Static: Application Containers
.150-.199       IoT (temporary, migrate to VLAN 20)
.200-.254       DHCP Pool (overflow)

VLAN 20 (192.168.20.0/24) - IoT [EXISTING]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
.1              Gateway
.6-.254         DHCP Pool (all IoT devices)

VLAN 10/30 - Future (Servers/Guest)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
To be designed in Phase 4
```

---

**Last Updated:** 2025-11-14  
**Maintained By:** Document in Git, update before deploying new containers
