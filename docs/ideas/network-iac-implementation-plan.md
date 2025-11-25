# Network Infrastructure as Code Implementation Plan

**Created:** 2025-11-14  
**Status:** Planning  
**Target:** Manage Paniland network via Terraform + config.gateway.json

## Hardware Constraints

Based on your current setup:
- **USG 4.4.57** (EOL, Jan 2023 last update) - Limited IaC support
- **Controller 7.2.97** on Cloud Key Gen1 - Resource constrained
- **UniFi Mini Switches 2.1.6** (Gen1) - Very old firmware

See `docs/reference/unifi-hardware-versions.md` for detailed compatibility analysis.

## Recommended Hybrid Approach

```
┌──────────────────────────────────────────────────────┐
│ Layer 1: Terraform (High-Level Network Config)      │
│  • Networks (VLANs)                                  │
│  • Wireless SSIDs                                    │
│  • Port Profiles                                     │
│  • Basic Firewall Rules                             │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ Layer 2: config.gateway.json (USG Advanced Config)  │
│  • Advanced firewall rules                          │
│  • Static DHCP mappings                             │
│  • DNS overrides                                    │
│  • Custom DHCP options                              │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│ Layer 3: Ansible (Deployment & Orchestration)       │
│  • Deploy config.gateway.json to USG                │
│  • Force-provision devices                          │
│  • Backup current configs                           │
│  • Smoke tests after changes                        │
└──────────────────────────────────────────────────────┘
```

## Phase 1: Setup & Testing (Week 1)

### Goal: Validate Terraform works with your hardware

#### Step 1.1: Install Terraform Provider
```bash
cd terraform/
cat > unifi-test.tf << 'EOF'
terraform {
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.41"
    }
  }
}

provider "unifi" {
  username = "cuiv"
  password = var.unifi_password
  api_url  = "https://192.168.1.7:8443"

  # Allow insecure since you're on local network
  allow_insecure = true

  # Important for Cloud Key Gen1 (resource constrained)
  # Add delays between API calls
}

variable "unifi_password" {
  type      = string
  sensitive = true
}
EOF

# Create terraform.tfvars (add to .gitignore!)
cat > terraform.tfvars << 'EOF'
unifi_password = "$Q2bdANgzviarx23YbHBMqX6"
EOF
```

#### Step 1.2: Read Current State (No Changes)
```bash
# Initialize
terraform init

# Try to read existing resources (manually define them first)
cat > unifi-import.tf << 'EOF'
# Import existing IoT network to test
resource "unifi_network" "iot" {
  name    = "IoT"
  purpose = "corporate"
  subnet  = "192.168.20.1/24"
  vlan_id = 20

  dhcp_enabled = true
  dhcp_start   = "192.168.20.6"
  dhcp_stop    = "192.168.20.254"
  dhcp_lease   = 86400

  domain_name = "lan"
}
EOF

# Import the existing IoT network
# (You'll need to find the network ID from the API)
terraform import unifi_network.iot <network-id>

# Verify no changes needed
terraform plan
# Should show: "No changes. Your infrastructure matches the configuration."
```

#### Step 1.3: Test Safe Change
```bash
# Create a TEST network (won't affect production)
cat > unifi-test-network.tf << 'EOF'
resource "unifi_network" "test" {
  name    = "Test-IaC"
  purpose = "corporate"
  subnet  = "192.168.99.1/24"
  vlan_id = 99

  dhcp_enabled = true
  dhcp_start   = "192.168.99.10"
  dhcp_stop    = "192.168.99.254"

  # Test on Private interface
  site = "default"
}
EOF

terraform plan
# Review carefully
terraform apply

# Verify in UI: Settings → Networks → Should see "Test-IaC"

# Clean up test
terraform destroy -target=unifi_network.test
```

**Success Criteria:**
- ✅ Terraform can connect to Controller
- ✅ Can import existing resources
- ✅ Can create/destroy test resources
- ✅ No impact on production

**If any failures:** Document specific errors, may need workarounds for USG 4.4.57

## Phase 2: Import Current Configuration (Week 2)

### Goal: Get existing config into Terraform state

#### Step 2.1: Network IDs Discovery
```bash
# Get network IDs from UniFi API
curl -s -k -b /tmp/unifi-cookie.txt \
  https://192.168.1.7:8443/api/s/default/rest/networkconf \
  | jq -r '.data[] | "\(.name): \(._id)"'

# Output will be like:
# Private: 5b6903abe9dc300f8bf5cd3b
# IoT: 60b61fd5e9dc300487d92a0a
# Guest: 62407436e9dc306717e3e48b
```

#### Step 2.2: Import Networks
```bash
# Create configs matching current state
cat > networks.tf << 'EOF'
# Private Network (Default VLAN)
resource "unifi_network" "private" {
  name    = "Private"
  purpose = "corporate"
  subnet  = "192.168.1.1/24"

  dhcp_enabled = true
  dhcp_start   = "192.168.1.6"
  dhcp_stop    = "192.168.1.254"
  dhcp_lease   = 86400

  domain_name = "lan"

  # DNS: USG itself
  dhcp_dns = ["192.168.1.1"]
}

# IoT Network (VLAN 20)
resource "unifi_network" "iot" {
  name    = "IoT"
  purpose = "corporate"
  subnet  = "192.168.20.1/24"
  vlan_id = 20

  dhcp_enabled = true
  dhcp_start   = "192.168.20.6"
  dhcp_stop    = "192.168.20.254"
  dhcp_lease   = 86400

  dhcp_dns = ["192.168.20.1"]
}

# Guest Network (VLAN 10) - currently inactive
resource "unifi_network" "guest" {
  name    = "Paniland-Guest"
  purpose = "guest"  # Note: guest isolation
  subnet  = "192.168.10.1/24"
  vlan_id = 10

  dhcp_enabled = true
  dhcp_start   = "192.168.10.10"
  dhcp_stop    = "192.168.10.254"

  # Guest network isolation
  igmp_snooping = true
}
EOF

# Import each network
terraform import unifi_network.private 5b6903abe9dc300f8bf5cd3b
terraform import unifi_network.iot 60b61fd5e9dc300487d92a0a
terraform import unifi_network.guest 62407436e9dc306717e3e48b

# Verify
terraform plan  # Should show minimal/no changes
```

#### Step 2.3: Import Wireless Networks
```bash
cat > wireless.tf << 'EOF'
# Main WiFi (Private VLAN)
resource "unifi_wlan" "main" {
  name       = "Paniland"
  security   = "wpapsk"
  passphrase = var.wifi_main_password

  network_id = unifi_network.private.id

  wpa3_support       = false  # U6-Lite supports this
  wpa3_transition    = false
  pmf_mode          = "optional"

  user_group_id = unifi_user_group.default.id
}

# 2.4GHz-only SSID (Private VLAN)
resource "unifi_wlan" "main_24" {
  name       = "Paniland-2.4"
  security   = "wpapsk"
  passphrase = var.wifi_main_password

  network_id = unifi_network.private.id

  # Force 2.4GHz only
  # (Check if supported on Controller 7.2.97)

  user_group_id = unifi_user_group.default.id
}

# IoT WiFi (SHOULD be VLAN 20, currently broken!)
resource "unifi_wlan" "iot" {
  name       = "Paniland-IoT"
  security   = "wpapsk"
  passphrase = var.wifi_iot_password

  # FIX: This should be VLAN 20, not default!
  network_id = unifi_network.iot.id  # Changed from default

  user_group_id = unifi_user_group.default.id
}

# Guest WiFi (SHOULD be VLAN 10, currently broken!)
resource "unifi_wlan" "guest" {
  name       = "Paniland-Guest"
  security   = "open"  # Open network

  # FIX: This should be VLAN 10
  network_id = unifi_network.guest.id  # Changed from default

  # Guest isolation
  is_guest          = true
  user_group_id     = unifi_user_group.guest.id
}

# User groups
resource "unifi_user_group" "default" {
  name = "Default"

  # Apply to all VLANs
  qos_rate_max_down = -1  # Unlimited
  qos_rate_max_up   = -1
}

resource "unifi_user_group" "guest" {
  name = "Guest"

  # Limit guest bandwidth
  qos_rate_max_down = 50000   # 50 Mbps
  qos_rate_max_up   = 10000   # 10 Mbps
}

# Variables
variable "wifi_main_password" {
  type      = string
  sensitive = true
}

variable "wifi_iot_password" {
  type      = string
  sensitive = true
}
EOF

# Add to terraform.tfvars
cat >> terraform.tfvars << 'EOF'
wifi_main_password = "your-main-wifi-password"
wifi_iot_password  = "your-iot-wifi-password"
EOF

# Import WLANs (get IDs from API first)
# terraform import unifi_wlan.main <wlan-id>
# ...etc
```

**Success Criteria:**
- ✅ All networks imported
- ✅ All WLANs imported
- ✅ `terraform plan` shows only the VLAN fixes for IoT/Guest SSIDs
- ✅ No unexpected changes

## Phase 3: Fix Critical Issues via Terraform (Week 3)

### Goal: Fix VLAN assignments for IoT and Guest WiFi

**⚠️ IMPORTANT: Do this during a maintenance window, will cause brief WiFi disconnects**

#### Step 3.1: Review Changes
```bash
terraform plan

# Should show:
# unifi_wlan.iot will be updated in-place
#   ~ network_id = "xxxxx" -> "60b61fd5e9dc300487d92a0a" (IoT VLAN 20)
#
# unifi_wlan.guest will be updated in-place
#   ~ network_id = "xxxxx" -> "62407436e9dc306717e3e48b" (Guest VLAN 10)
```

#### Step 3.2: Apply Fixes
```bash
# Apply the VLAN fixes
terraform apply

# This will:
# 1. Update Paniland-IoT SSID → VLAN 20
# 2. Update Paniland-Guest SSID → VLAN 10
# 3. Reprovision APs (brief WiFi disconnect)

# Verify
# 1. Check UniFi Controller: Settings → Wireless Networks
# 2. Reconnect IoT device to Paniland-IoT, check it gets 192.168.20.x IP
# 3. Test isolation: IoT device should NOT ping 192.168.1.x
```

#### Step 3.3: Verify Isolation
```bash
# From an IoT device (on 192.168.20.x):
ping 192.168.1.1  # Should FAIL (blocked by firewall rule 2000)
ping 8.8.8.8      # Should SUCCEED (internet access OK)

# From Private device:
ping 192.168.20.x  # Should SUCCEED (Private can reach IoT)
```

**Success Criteria:**
- ✅ IoT devices get 192.168.20.x IPs
- ✅ Guest devices get 192.168.10.x IPs
- ✅ IoT cannot ping Private network
- ✅ All SSIDs working

## Phase 4: config.gateway.json for Advanced Config (Week 4)

### Goal: Manage static DHCP and DNS via Git

#### Step 4.1: Create config.gateway.json
```bash
mkdir -p ansible/files/usg/
cat > ansible/files/usg/config.gateway.json << 'EOF'
{
  "service": {
    "dhcp-server": {
      "shared-network-name": {
        "net_Private_eth1_192.168.1.0-24": {
          "subnet": {
            "192.168.1.0/24": {
              "static-mapping": {
                "homelab": {
                  "ip-address": "192.168.1.56",
                  "mac-address": "70:85:c2:a5:c3:c4"
                },
                "pihole": {
                  "ip-address": "192.168.1.107",
                  "mac-address": "b8:27:eb:7c:24:24"
                },
                "raspberrypi": {
                  "ip-address": "192.168.1.114",
                  "mac-address": "dc:a6:32:d4:85:77"
                },
                "main-switch": {
                  "ip-address": "192.168.1.6",
                  "mac-address": "24:5a:4c:59:77:d7"
                },
                "bedroom-switch": {
                  "ip-address": "192.168.1.112",
                  "mac-address": "68:d7:9a:31:c9:19"
                },
                "lab-switch": {
                  "ip-address": "192.168.1.44",
                  "mac-address": "68:d7:9a:31:c8:de"
                },
                "livingroom-switch": {
                  "ip-address": "192.168.1.113",
                  "mac-address": "68:d7:9a:31:c9:26"
                },
                "livingroom-ap": {
                  "ip-address": "192.168.1.9",
                  "mac-address": "24:5a:4c:11:47:58"
                },
                "bedroom-ap": {
                  "ip-address": "192.168.1.10",
                  "mac-address": "24:5a:4c:11:47:d4"
                },
                "unifi-controller": {
                  "ip-address": "192.168.1.7",
                  "mac-address": "f0:9f:c2:c6:d7:af"
                }
              }
            }
          }
        }
      }
    },
    "dns": {
      "forwarding": {
        "options": [
          "server=1.1.1.1",
          "server=1.0.0.1",
          "host-record=unifi,192.168.1.7",
          "host-record=homelab,192.168.1.56",
          "host-record=pihole,192.168.1.107",
          "cname=unifi.lan,unifi"
        ]
      }
    }
  }
}
EOF
```

#### Step 4.2: Ansible Playbook to Deploy
```bash
cat > ansible/playbooks/deploy-usg-config.yml << 'EOF'
---
- name: Deploy config.gateway.json to USG
  hosts: localhost
  gather_facts: no

  vars:
    usg_ip: 192.168.1.1
    usg_user: cuiv
    usg_password: "0bi4amAni"
    config_file: "../files/usg/config.gateway.json"

  tasks:
    - name: Validate config.gateway.json syntax
      command: jq empty {{ config_file }}
      changed_when: false

    - name: Backup current config from USG
      shell: |
        sshpass -p '{{ usg_password }}' ssh -o StrictHostKeyChecking=no \
          {{ usg_user }}@{{ usg_ip }} \
          'cat /usr/lib/unifi/data/sites/default/config.gateway.json' \
          > /tmp/config.gateway.json.backup.$(date +%Y%m%d-%H%M%S)
      ignore_errors: yes

    - name: Copy config.gateway.json to Controller
      shell: |
        sshpass -p '{{ usg_password }}' scp -o StrictHostKeyChecking=no \
          {{ config_file }} \
          {{ usg_user }}@192.168.1.7:/usr/lib/unifi/data/sites/default/config.gateway.json

    - name: Force provision USG
      uri:
        url: https://192.168.1.7:8443/api/s/default/cmd/devmgr
        method: POST
        body_format: json
        body:
          cmd: force-provision
          mac: "f0:9f:c2:16:bf:17"
        headers:
          Cookie: "{{ lookup('file', '/tmp/unifi-cookie.txt') }}"
        validate_certs: no

    - name: Wait for USG to reprovision
      pause:
        seconds: 30

    - name: Verify config applied
      shell: |
        sshpass -p '{{ usg_password }}' ssh -o StrictHostKeyChecking=no \
          {{ usg_user }}@{{ usg_ip }} \
          'vbash -ic "show dhcp server leases" | grep homelab'
      register: verify
      failed_when: verify.rc != 0
EOF

# Run it
ansible-playbook ansible/playbooks/deploy-usg-config.yml
```

**Success Criteria:**
- ✅ config.gateway.json validates
- ✅ Deployed to Controller
- ✅ USG reprovisioned
- ✅ Static DHCP mappings active
- ✅ DNS records working

## Phase 5: Production Workflow

### Git Workflow
```bash
# Feature branch for network changes
git checkout -b network/add-iot-vlan-isolation

# Make changes
vim terraform/networks.tf
vim ansible/files/usg/config.gateway.json

# Test
cd terraform/
terraform plan

# Review carefully
# Commit
git add .
git commit -m "network: enforce IoT VLAN isolation on WiFi SSIDs"

# Merge to main
git checkout main
git merge network/add-iot-vlan-isolation

# Apply
terraform apply
ansible-playbook ansible/playbooks/deploy-usg-config.yml
```

### Directory Structure
```
homelab-notes/
├── terraform/
│   ├── unifi/
│   │   ├── main.tf           # Provider config
│   │   ├── networks.tf       # VLAN definitions
│   │   ├── wireless.tf       # SSIDs
│   │   ├── firewall.tf       # Basic firewall rules
│   │   ├── port-profiles.tf  # Switch port configs
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars  # Passwords (gitignored!)
│   └── ...
├── ansible/
│   ├── files/
│   │   └── usg/
│   │       └── config.gateway.json
│   └── playbooks/
│       ├── deploy-usg-config.yml
│       └── backup-usg-config.yml
└── docs/
    └── plans/
        └── network-iac-implementation-plan.md (this file)
```

## Rollback Procedures

### Terraform Changes
```bash
# Revert to previous state
git revert HEAD
terraform apply

# Or restore from state backup
cp terraform.tfstate.backup terraform.tfstate
terraform apply
```

### config.gateway.json Changes
```bash
# Restore backup
scp /tmp/config.gateway.json.backup.20251114-123456 \
  cuiv@192.168.1.7:/usr/lib/unifi/data/sites/default/config.gateway.json

# Force provision via UI or API
```

## Limitations to Accept (Given Your Hardware)

### Things that will STILL require UI:
1. **Per-port VLAN assignments** on old Mini switches (firmware 2.1.6)
2. **Device adoption** (new switches/APs)
3. **Firmware upgrades**
4. **Some advanced USG features** (VPN, policy routing)

### Things managed via config.gateway.json:
1. Static DHCP reservations
2. DNS overrides
3. Advanced firewall rules
4. Custom DHCP options

### Things fully managed via Terraform:
1. ✅ Networks (VLANs)
2. ✅ Wireless SSIDs
3. ✅ Port profiles
4. ✅ Basic firewall rules
5. ✅ Port forwarding

## Success Metrics

After full implementation:
- ✅ 80%+ of network config in Git
- ✅ VLAN changes via PR + Terraform
- ✅ WiFi password changes via Terraform
- ✅ Firewall rules documented in code
- ✅ No manual UI changes (except documented exceptions)
- ✅ Can rebuild network from Git (disaster recovery)

## When to Upgrade Hardware

Consider upgrading USG to UXG-Lite ($129) or UDM-SE ($299) when:
1. You want 100% IaC coverage
2. USG security vulnerabilities emerge (EOL risk)
3. Need modern features (WireGuard VPN, IDS/IPS, etc.)
4. Want to eliminate config.gateway.json complexity

**UDM-SE Benefits:**
- Full Terraform support
- Built-in controller (no Cloud Key needed)
- Modern UniFi OS
- 2.5G WAN port
- Active development

## Next Steps

1. **Decide:** Proceed with hybrid IaC approach, or wait for hardware upgrade?
2. **If proceed:** Start Phase 1 testing this week
3. **If upgrade first:** Research UXG-Lite vs UDM-SE vs UDM-Pro
4. **Either way:** Document current config in Git (even if not active IaC yet)

## Related Documents

- `docs/reference/unifi-hardware-versions.md` - Compatibility details
