# UniFi Infrastructure as Code Research

**Research Date:** 2025-11-14  
**Purpose:** Evaluate IaC options for managing UniFi network infrastructure

## Executive Summary

**Recommended Approach:** Terraform with `paultyng/unifi` provider for network/WLAN/firewall configuration, combined with `config.gateway.json` + Ansible for USG-specific advanced configuration.

**Key Findings:**
- Terraform provider is mature (562 stars, actively maintained through 2023)
- Supports UniFi Controller v6+ (including UDM, UDM-Pro, Cloud Key)
- No comprehensive Ansible solution exists for UniFi network management
- USG advanced configuration requires `config.gateway.json` approach
- Direct API is well-documented but lacks declarative state management

---

## 1. Terraform Provider for UniFi

### Overview
- **Provider:** `paultyng/unifi`
- **Registry:** https://registry.terraform.io/providers/paultyng/unifi
- **GitHub:** https://github.com/paultyng/terraform-provider-unifi
- **Stars:** 562
- **License:** MPL-2.0
- **Last Release:** v0.41.0 (March 2023)
- **SDK:** Built on go-unifi (same author)

### Supported Controller Versions
- UniFi Controller v6.x, v7.x (v5 support dropped in v0.34.0)
- UniFi OS (UDM, UDM-Pro, Cloud Key Gen2, UDM-SE)
- Docker-based controllers
- Standard port 8443, UniFi OS uses port 443

### Supported Resources

#### Network Configuration
- `unifi_network` - WAN/LAN/VLAN networks
  - DHCP configuration (v4/v6)
  - Static routes
  - VLAN tagging
  - WAN types: static, DHCP, PPPoE
  - IPv6 support (static, PD, DHCPv6)
  - Internet/intra-network access controls
  - mDNS, IGMP snooping

#### Wireless Networks
- `unifi_wlan` - WiFi SSIDs
  - Security: WPA-PSK, WPA-EAP, Open
  - WPA3 support with PMF
  - MAC filtering
  - Fast roaming (802.11r)
  - BSS transition
  - L2 isolation
  - Guest networks
  - Minimum data rates (2G/5G)
  - Scheduling

#### Firewall & Security
- `unifi_firewall_rule` - Gateway firewall rules
  - Rulesets: WAN_IN/OUT/LOCAL, LAN_IN/OUT/LOCAL, GUEST_IN/OUT/LOCAL (IPv4/IPv6)
  - Actions: drop, accept, reject
  - Source/dest by address, network, firewall group
  - Protocol filtering
  - State matching (established, new, related, invalid)
  - IPsec matching
  - Port-based rules
  - Rule index 2000-2999, 4000-4999

- `unifi_firewall_group` - Address/port groups for firewall rules

#### Switch Configuration
- `unifi_port_profile` - Switch port profiles
  - VLAN assignment (native + tagged)
  - PoE modes (auto, passive 24V, passthrough, off)
  - Link speed/duplex/autoneg
  - 802.1X control
  - Port isolation
  - Rate limiting
  - Storm control
  - Voice VLAN
  - STP settings

#### Routing & WAN
- `unifi_static_route` - Static routes
- `unifi_port_forward` - Port forwarding rules
- `unifi_dynamic_dns` - Dynamic DNS configuration

#### User Management
- `unifi_user` - Client devices
- `unifi_user_group` - User groups with QoS
- `unifi_account` - Controller admin accounts

#### RADIUS
- `unifi_radius_profile` - RADIUS profiles for WPA-EAP

#### Site Management
- `unifi_site` - Multi-site management

#### Device Management
- `unifi_device` - Adopt/configure devices (limited)

#### Settings
- `unifi_setting_mgmt` - Management settings (SSH, auto-upgrade)
- `unifi_setting_usg` - USG-specific settings (basic)
- `unifi_setting_radius` - RADIUS server settings

### Data Sources
- `unifi_account`, `unifi_ap_group`, `unifi_network`, `unifi_port_profile`, `unifi_radius_profile`, `unifi_user`, `unifi_user_group`

### Configuration Example

```hcl
terraform {
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.41.0"
    }
  }
}

provider "unifi" {
  username       = var.unifi_username  # or UNIFI_USERNAME env var
  password       = var.unifi_password  # or UNIFI_PASSWORD env var
  api_url        = var.unifi_api_url   # or UNIFI_API env var (e.g., https://192.168.1.1)
  allow_insecure = true                # or UNIFI_INSECURE env var (for self-signed certs)
  site           = "default"           # or UNIFI_SITE env var
}

# VLAN Network
resource "unifi_network" "iot_vlan" {
  name    = "IoT"
  purpose = "corporate"
  
  vlan_id      = 20
  subnet       = "192.168.20.1/24"
  dhcp_enabled = true
  dhcp_start   = "192.168.20.10"
  dhcp_stop    = "192.168.20.254"
  dhcp_dns     = ["192.168.1.1"]
  
  igmp_snooping              = true
  multicast_dns              = false
  internet_access_enabled    = true
  intra_network_access_enabled = false  # Isolate from other VLANs
}

# WiFi SSID
resource "unifi_wlan" "guest_wifi" {
  name       = "Guest-WiFi"
  passphrase = var.guest_wifi_password
  security   = "wpapsk"
  
  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional"
  
  network_id    = unifi_network.guest_vlan.id
  user_group_id = data.unifi_user_group.default.id
  
  is_guest    = true
  hide_ssid   = false
  l2_isolation = true
}

# Firewall Rule
resource "unifi_firewall_rule" "block_iot_to_lan" {
  name       = "Block IoT to LAN"
  action     = "drop"
  ruleset    = "LAN_IN"
  rule_index = 2010
  
  protocol = "all"
  
  src_network_id = unifi_network.iot_vlan.id
  dst_network_id = unifi_network.lan.id
  
  logging = true
  enabled = true
}

# Switch Port Profile
resource "unifi_port_profile" "iot_devices" {
  name = "IoT Devices"
  
  native_networkconf_id = unifi_network.iot_vlan.id
  poe_mode              = "auto"
  
  forward    = "native"
  isolation  = true
  
  autoneg = true
}
```

### Limitations & Gotchas

1. **Connection Requirements**
   - Must use wired connection when making network changes
   - Cannot configure network while connected to WiFi that may disconnect
   - API access requires local admin account (not Cloud account)
   - 2FA/MFA not supported

2. **Functionality Gaps**
   - Limited device management (adoption works, but limited config)
   - No wireless uplink configuration
   - Limited USG advanced features (need `config.gateway.json`)
   - Some settings only in UI (e.g., DPI, threat management)
   - Cannot manage controller settings (backups, updates)

3. **State Management**
   - Rule indices must be managed carefully (2000-2999, 4000-4999)
   - Removing passphrase from WLAN can break apply (known bug)
   - Setting `network_group` on WAN breaks configuration (known bug)
   - Import syntax varies by resource

4. **API Limitations**
   - Functionality depends on go-unifi SDK development
   - Some newer controller features may lag
   - UniFi OS API is slightly different (proxied differently)

5. **Version Compatibility**
   - Only supports Controller v6+ (pin to v0.33.x for v5 support)
   - Test with specific controller version before production use
   - UDM/UDM-Pro vs regular controller have minor API differences

### Best Practices

1. **Provider Configuration**
   - Use environment variables for credentials
   - Enable SSL verification in production (`allow_insecure = false`)
   - Use local admin account with appropriate permissions
   - Create dedicated Terraform user (Limited Admin, Local Access Only)

2. **State Management**
   - Use remote state backend (S3, Terraform Cloud)
   - Plan firewall rule indices ahead of time
   - Use data sources to reference existing resources
   - Import existing resources before managing them

3. **Testing**
   - Always run `terraform plan` before apply
   - Test on non-production site first
   - Maintain wired connection during network changes
   - Have console access to controller in case of network lockout

4. **Code Organization**
   ```
   terraform/
   ├── main.tf              # Provider config
   ├── variables.tf         # Input variables
   ├── outputs.tf           # Outputs
   ├── networks.tf          # Network/VLAN definitions
   ├── wireless.tf          # WLAN/WiFi
   ├── firewall.tf          # Firewall rules
   ├── switches.tf          # Port profiles
   └── terraform.tfvars     # Variable values (gitignored)
   ```

---

## 2. Ansible Options

### Current State
**No comprehensive Ansible solution exists for UniFi network management.**

### Available Ansible Projects

1. **Controller Installation Roles**
   - `nephelaiio/ansible-role-unifi-controller` (29 stars)
   - `lifeofguenter/ansible-role-unifi-controller` (10 stars)
   - Purpose: Install/upgrade UniFi Controller software
   - **Does NOT manage network configuration**

2. **Custom/API-based Approaches**
   - `ppouliot/ansible-role-ubnt_platform_mgmt` (16 stars)
     - Manages EdgeMAX and UniFi devices
     - Limited, not actively maintained
   
   - `aioue/ansible-unifi-inventory` (5 stars)
     - Dynamic inventory plugin (reads from UniFi)
     - Not for configuration management

3. **SSL Certificate Deployment**
   - `bendews/ansible-unifi-ssl` (4 stars)
   - Only deploys SSL certs to controller

### Why Ansible Falls Short

1. **No Native Modules**
   - No official UniFi modules in Ansible core
   - No mature Ansible Galaxy collections for UniFi
   - Would require custom modules using UniFi API

2. **API Complexity**
   - UniFi API is REST-based but session-heavy
   - State management requires complex logic
   - Idempotency hard to achieve with imperative API calls

3. **Community Focus**
   - Ansible UniFi projects focus on controller installation
   - Network configuration via Ansible not a common pattern
   - Terraform is the community standard for UniFi IaC

### When to Use Ansible with UniFi

- **Controller installation/maintenance** (OS-level)
- **Deploying `config.gateway.json`** (see USG section)
- **SSL certificate management**
- **Orchestrating Terraform runs** as part of broader automation
- **Backup management** (controller backup files)

---

## 3. Direct API Approach

### UniFi Controller API Overview

- **Type:** REST API (JSON over HTTPS)
- **Authentication:** Session-based (login, get cookie, make requests)
- **Base Path:** `/api/` (classic) or `/proxy/network/api/` (UniFi OS)
- **Documentation:** Unofficial (reverse-engineered, no official docs)

### Popular API Clients

1. **Art-of-WiFi/UniFi-API-client** (PHP)
   - 1,279 stars
   - Most mature API client
   - Supports UniFi Controller 5.x-10.x, UniFi OS 3.x-5.x
   - https://github.com/Art-of-WiFi/UniFi-API-client

2. **Art-of-WiFi/UniFi-API-browser** (PHP)
   - 1,220 stars
   - Web-based API exploration tool
   - Useful for discovering API endpoints

3. **paultyng/go-unifi** (Go)
   - Powers the Terraform provider
   - https://github.com/paultyng/go-unifi

4. **Python clients**
   - Multiple community projects, varying maturity
   - Used for custom automation scripts

### API Capabilities

**Can be configured via API:**
- Networks (WAN/LAN/VLAN)
- WLANs (SSIDs)
- Firewall rules
- Port forwarding
- Static routes
- User groups
- RADIUS profiles
- Device adoption
- Client blocking/authorization
- Port profiles
- Site settings

**Requires UI or other methods:**
- Initial controller setup
- Controller backups/restore
- Firmware updates
- DPI configuration (Deep Packet Inspection)
- Some advanced USG features
- License management

### API Authentication & Sessions

```python
# Example: Python API login
import requests

session = requests.Session()

# Login
login_url = "https://192.168.1.1:8443/api/login"
login_data = {"username": "admin", "password": "password"}
response = session.post(login_url, json=login_data, verify=False)

# Make API calls with session cookie
clients_url = "https://192.168.1.1:8443/api/s/default/stat/sta"
clients = session.get(clients_url, verify=False).json()

# Logout
logout_url = "https://192.168.1.1:8443/api/logout"
session.post(logout_url)
```

### Challenges with Direct API

1. **No Declarative State**
   - API is imperative (do this action)
   - Must implement state tracking yourself
   - No built-in drift detection

2. **Session Management**
   - Cookie-based authentication
   - Sessions expire
   - Must handle re-authentication

3. **API Versioning**
   - API changes between controller versions
   - No official versioning scheme
   - Breaking changes possible

4. **Limited Documentation**
   - Unofficial, community-maintained docs
   - Reverse-engineered endpoints
   - Behavior discovered through testing

5. **Error Handling**
   - API errors not always descriptive
   - Must handle various failure modes
   - Rate limiting on some endpoints

### When to Use Direct API

- **Custom automation** not covered by Terraform
- **Read-only monitoring** (client lists, stats)
- **One-off scripts** (mass client blocking, etc.)
- **Integrations** with other systems
- **Temporary changes** (testing firewall rules)

---

## 4. USG Configuration

### USG Architecture

The UniFi Security Gateway runs EdgeOS (Vyatta-based) underneath the UniFi Controller management layer. Advanced configuration requires understanding both layers.

**Two Management Layers:**
1. **UniFi Controller** - High-level network config (VLANs, firewall, etc.)
2. **EdgeOS** - Low-level router config (advanced routing, custom firewall, etc.)

### Managing USG via IaC

#### Option 1: `config.gateway.json` (Recommended)

**What it is:**
- JSON file placed on UniFi Controller
- Contains EdgeOS configuration (Vyatta syntax as JSON)
- Controller merges this with UniFi settings during USG provisioning
- Persists across USG reboots/re-provisioning

**Location:**
- Classic Controller: `/usr/lib/unifi/data/sites/<site-name>/config.gateway.json`
- UniFi OS: `/data/unifi/data/sites/<site-name>/config.gateway.json`

**Example: Custom firewall rule**
```json
{
  "firewall": {
    "group": {
      "network-group": {
        "LAN_NETWORKS": {
          "network": [
            "192.168.1.0/24",
            "192.168.20.0/24"
          ]
        }
      }
    },
    "name": {
      "WAN_LOCAL": {
        "rule": {
          "20": {
            "action": "accept",
            "description": "Allow SSH from specific IP",
            "destination": {
              "port": "22"
            },
            "protocol": "tcp",
            "source": {
              "address": "203.0.113.50"
            }
          }
        }
      }
    }
  }
}
```

**Managing with Ansible:**
```yaml
# ansible/roles/usg-config/tasks/main.yml
- name: Deploy config.gateway.json to UniFi Controller
  template:
    src: config.gateway.json.j2
    dest: "/usr/lib/unifi/data/sites/{{ unifi_site_name }}/config.gateway.json"
    owner: unifi
    group: unifi
    mode: '0644'
  notify: Force USG provision

# ansible/roles/usg-config/handlers/main.yml
- name: Force USG provision
  uri:
    url: "https://{{ unifi_controller }}/api/s/{{ unifi_site_name }}/cmd/devmgr"
    method: POST
    body_format: json
    body:
      cmd: force-provision
      mac: "{{ usg_mac_address }}"
    headers:
      Cookie: "{{ unifi_session_cookie }}"
    validate_certs: no
```

**IaC Integration:**
1. Store `config.gateway.json` in Git
2. Use Ansible to deploy to controller
3. Trigger USG re-provisioning
4. Validate config applied successfully

**Common Use Cases:**
- Custom firewall rules beyond UniFi UI
- Advanced NAT/port forwarding
- Policy-based routing
- VPN configurations (site-to-site)
- Custom DHCP options
- DNS forwarding rules
- Traffic shaping beyond UniFi QoS

#### Option 2: EdgeOS CLI Scripting

**What it is:**
- SSH directly to USG
- Run EdgeOS CLI commands
- Vyatta-style configuration

**Why NOT recommended for IaC:**
- Changes lost on USG re-provisioning
- Controller overwrites manual changes
- No persistence across reboots
- Conflicts with controller management

**When to use:**
- Debugging/troubleshooting
- Testing config before adding to config.gateway.json
- One-off diagnostics
- Emergency fixes

**Example:**
```bash
ssh admin@192.168.1.1
configure
set firewall name WAN_LOCAL rule 20 action accept
set firewall name WAN_LOCAL rule 20 description "Temp SSH allow"
set firewall name WAN_LOCAL rule 20 destination port 22
set firewall name WAN_LOCAL rule 20 protocol tcp
commit
save
exit
```

#### Option 3: Terraform `unifi_setting_usg`

**Current State:**
- `unifi_setting_usg` resource exists
- Very limited functionality
- Covers basic USG settings only
- **Does NOT replace config.gateway.json**

**What it can configure:**
- Basic firewall settings
- DHCP relay
- Multicast DNS
- IGMP snooping

**What it CANNOT configure:**
- Custom firewall rules (use `unifi_firewall_rule` instead)
- Advanced routing
- Policy-based routing
- VPN configurations

### Controller Provisioning Flow

1. **Configuration Sources (Priority Order):**
   - UniFi Controller settings (Terraform-managed)
   - `config.gateway.json`
   - Default EdgeOS config

2. **When USG Re-provisions:**
   - Manual "Force Provision" in UI
   - USG reboot
   - Network config changes in controller
   - After `config.gateway.json` changes

3. **Validation:**
   - SSH to USG: `show configuration`
   - Check for your custom config
   - Verify no conflicts with controller

### Recommended USG IaC Strategy

```
┌─────────────────────────────────────────────────────────┐
│ Terraform (paultyng/unifi provider)                     │
│ - Networks, VLANs, WLANs                                │
│ - Basic firewall rules                                  │
│ - Port profiles, static routes                          │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ config.gateway.json (Git-tracked)                       │
│ - Advanced USG-specific config                          │
│ - Custom firewall rules                                 │
│ - Policy routing, VPN, etc.                             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Ansible                                                  │
│ - Deploy config.gateway.json to controller              │
│ - Trigger USG re-provisioning                           │
│ - Validate config applied                               │
└─────────────────────────────────────────────────────────┘
```

### Example config.gateway.json Use Cases

**1. Allow WAN SSH from specific IP:**
```json
{
  "firewall": {
    "name": {
      "WAN_LOCAL": {
        "rule": {
          "20": {
            "action": "accept",
            "description": "SSH from home",
            "destination": {"port": "22"},
            "protocol": "tcp",
            "source": {"address": "203.0.113.50"}
          }
        }
      }
    }
  }
}
```

**2. Policy-based routing:**
```json
{
  "firewall": {
    "modify": {
      "LOAD_BALANCE": {
        "rule": {
          "10": {
            "action": "modify",
            "modify": {
              "table": "1"
            },
            "source": {
              "address": "192.168.20.0/24"
            }
          }
        }
      }
    }
  }
}
```

**3. Custom DHCP options:**
```json
{
  "service": {
    "dhcp-server": {
      "shared-network-name": {
        "LAN": {
          "subnet": {
            "192.168.1.0/24": {
              "subnet-parameters": "option domain-name-servers 1.1.1.1,8.8.8.8;"
            }
          }
        }
      }
    }
  }
}
```

---

## 5. Best Practices & Recommendations

### Recommended IaC Stack for UniFi

```
┌────────────────────────────────────────────────────────┐
│ TERRAFORM (Primary IaC Tool)                           │
│ - Networks & VLANs                                     │
│ - WiFi SSIDs                                           │
│ - Firewall rules (standard)                            │
│ - Switch port profiles                                 │
│ - User groups                                          │
│ - Port forwarding                                      │
└────────────────────────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────┐
│ GIT REPOSITORY                                         │
│ - config.gateway.json (advanced USG config)            │
│ - Terraform state (remote backend)                     │
│ - Variable files (network ranges, etc.)                │
└────────────────────────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────┐
│ ANSIBLE (Orchestration & Deployment)                   │
│ - Deploy config.gateway.json to controller             │
│ - Trigger USG provisioning                             │
│ - Run Terraform for network config                     │
│ - Controller backups                                   │
└────────────────────────────────────────────────────────┘
```

### State & Drift Detection

#### Terraform State
- Use **remote state backend** (S3 + DynamoDB, Terraform Cloud)
- Enable state locking
- Regular `terraform plan` to detect drift
- Controller changes outside Terraform will show as drift

#### Drift Detection Strategy
```bash
# Daily drift check (cron job)
#!/bin/bash
cd /path/to/terraform
terraform plan -detailed-exitcode

if [ $? -eq 2 ]; then
  # Drift detected
  echo "UniFi config drift detected" | mail -s "Alert" admin@example.com
fi
```

#### Handling Drift
1. **Terraform-managed resources changed in UI:**
   - `terraform plan` shows changes
   - `terraform apply` reverts to desired state
   - Consider using `-refresh-only` to update state without changes

2. **Resources created outside Terraform:**
   - Import with `terraform import`
   - Or document as "manual exceptions"

3. **Controller firmware updates:**
   - Test Terraform compatibility after updates
   - Controller v7 may need provider update

### Backup & Disaster Recovery

#### What to Backup

1. **Terraform State** (Critical)
   - Remote backend (S3) with versioning
   - Or Terraform Cloud (built-in versioning)

2. **Terraform Code** (Critical)
   - Git repository (GitHub, GitLab)
   - Include variable files (encrypted secrets)

3. **config.gateway.json** (Critical)
   - Git repository
   - Version controlled

4. **Controller Backups** (Critical)
   - UniFi auto-backup feature (daily)
   - Download/backup to separate storage
   - Contains all settings not in Terraform

#### Disaster Recovery Procedure

**Scenario: Controller failure**

1. **Restore Controller:**
   - Install new controller
   - Restore from UniFi backup
   - Verify site accessible

2. **Verify Terraform State:**
   - `terraform plan` should show no changes
   - If state lost, rebuild from backup or re-import

3. **Re-deploy config.gateway.json:**
   - Run Ansible playbook
   - Force USG provision

4. **Validate:**
   - Check network connectivity
   - Verify VLANs, WiFi, firewall rules
   - Test client connectivity

**Recovery Time Objective (RTO):**
- With automation: ~30 minutes
- Manual restoration: 2-4 hours

### Common Pitfalls to Avoid

1. **Configuring network while on WiFi**
   - ALWAYS use wired connection
   - Risk of locking yourself out

2. **Using Cloud account or 2FA account**
   - API doesn't support Cloud accounts or 2FA
   - Create local admin with local-only access

3. **Not planning firewall rule indices**
   - Rule indices must be unique (2000-2999, 4000-4999)
   - Plan numbering scheme ahead of time
   - Leave gaps for future rules

4. **Mixing Terraform and manual changes**
   - Drift will occur
   - Terraform may overwrite manual changes
   - Choose one source of truth

5. **Not testing controller upgrades**
   - New controller versions may break provider
   - Test in staging before production upgrade
   - Check provider GitHub issues before upgrading

6. **Ignoring config.gateway.json persistence**
   - Changes in USG CLI are NOT persistent
   - Always update config.gateway.json for lasting changes

7. **Not versioning state or code**
   - Lost state = rebuild everything
   - Lost code = unknown configuration
   - Git + remote state = mandatory

8. **Changing network config without console access**
   - Firewall rule mistakes can lock you out
   - Have physical/IPMI access to controller host
   - Test firewall rules carefully

### Security Considerations

1. **API Credentials**
   - Store in encrypted vault (Ansible Vault, HashiCorp Vault)
   - Use environment variables
   - Never commit to Git

2. **Terraform State Security**
   - State contains sensitive data (WiFi passwords, etc.)
   - Encrypt remote backend (S3 encryption)
   - Restrict access to state files

3. **Controller Access**
   - Dedicated Terraform user (least privilege)
   - Limited Admin role sufficient
   - Disable account when not in use (optional)

4. **Network Access**
   - Run Terraform from trusted network
   - Consider VPN for remote management
   - Firewall API access (port 8443/443)

---

## 6. Comparison Matrix

| Aspect                    | Terraform          | Ansible           | Direct API        | config.gateway.json |
|---------------------------|-------------------|-------------------|-------------------|---------------------|
| **Declarative**           | ✅ Yes            | ⚠️ Partial        | ❌ No             | ✅ Yes              |
| **State Management**      | ✅ Built-in       | ❌ Manual         | ❌ Manual         | ⚠️ Via Controller   |
| **Drift Detection**       | ✅ Yes            | ❌ No             | ❌ No             | ❌ No               |
| **Network Config**        | ✅ Excellent      | ❌ Limited        | ✅ Full           | ❌ No               |
| **USG Advanced Config**   | ❌ Limited        | ✅ Via JSON       | ⚠️ Partial        | ✅ Full             |
| **Learning Curve**        | Medium            | Low-Medium        | High              | High                |
| **Community Support**     | Strong            | Weak (for UniFi)  | Medium            | Medium              |
| **Production Ready**      | ✅ Yes            | ⚠️ For some tasks | ⚠️ Custom only    | ✅ Yes              |
| **Rollback Support**      | ✅ Yes            | ⚠️ Manual         | ❌ Manual         | ⚠️ Manual           |
| **Best For**              | Network/WiFi/FW   | Orchestration     | Custom scripts    | USG-specific        |

---

## 7. Implementation Roadmap

### Phase 1: Foundation (Week 1)
1. Set up Terraform with remote state
2. Create dedicated UniFi admin user for Terraform
3. Import existing networks into Terraform state
4. Validate Terraform can manage existing resources

### Phase 2: Network Configuration (Week 2)
1. Define all networks/VLANs in Terraform
2. Configure WLANs (WiFi SSIDs)
3. Set up firewall rules
4. Define port profiles for switches
5. Test changes on non-critical network first

### Phase 3: Advanced Features (Week 3)
1. Create config.gateway.json for USG
2. Set up Ansible playbook to deploy config.gateway.json
3. Configure advanced routing/firewall in EdgeOS JSON
4. Test USG provisioning process

### Phase 4: Automation & Monitoring (Week 4)
1. Set up CI/CD for Terraform (GitHub Actions, GitLab CI)
2. Implement drift detection (daily cron)
3. Configure backup automation
4. Document runbooks for common tasks

---

## 8. Example Project Structure

```
unifi-iac/
├── terraform/
│   ├── main.tf                  # Provider config
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Outputs
│   ├── networks.tf              # Networks & VLANs
│   ├── wireless.tf              # WLANs
│   ├── firewall.tf              # Firewall rules
│   ├── switches.tf              # Port profiles
│   ├── users.tf                 # User groups
│   ├── terraform.tfvars.example # Example variables
│   └── backend.tf               # Remote state config
│
├── ansible/
│   ├── playbooks/
│   │   ├── deploy-usg-config.yml        # Deploy config.gateway.json
│   │   ├── backup-controller.yml        # Backup UniFi controller
│   │   └── run-terraform.yml            # Orchestrate Terraform
│   ├── roles/
│   │   └── usg-config/
│   │       ├── tasks/
│   │       │   └── main.yml
│   │       ├── templates/
│   │       │   └── config.gateway.json.j2
│   │       └── handlers/
│   │           └── main.yml
│   └── inventory/
│       └── hosts.yml
│
├── config/
│   ├── config.gateway.json      # USG advanced config
│   └── config.gateway.schema.json # Optional schema validation
│
├── scripts/
│   ├── drift-check.sh           # Daily drift detection
│   └── backup-state.sh          # Backup Terraform state
│
├── docs/
│   ├── network-design.md        # Network architecture
│   ├── runbooks.md              # Operational procedures
│   └── disaster-recovery.md     # DR procedures
│
├── .gitignore                   # Ignore secrets, state files
├── README.md                    # Project documentation
└── Makefile                     # Common commands
```

---

## 9. Additional Resources

### Documentation
- Terraform UniFi Provider: https://registry.terraform.io/providers/paultyng/unifi/latest/docs
- UniFi API Browser: https://github.com/Art-of-WiFi/UniFi-API-browser
- UniFi API Client (PHP): https://github.com/Art-of-WiFi/UniFi-API-client
- EdgeOS Command Reference: https://help.ui.com/hc/en-us/articles/204960094

### Community Resources
- UniFi subreddit: r/Ubiquiti
- UniFi Community Forums: https://community.ui.com
- Terraform Provider GitHub: https://github.com/paultyng/terraform-provider-unifi

### Related Projects
- go-unifi SDK: https://github.com/paultyng/go-unifi
- config.gateway.json Examples: https://github.com/topics/config-gateway-json
- Ansible UniFi SSL: https://github.com/bendews/ansible-unifi-ssl

### Learning Resources
- Terraform Up and Running (book)
- HashiCorp Learn: https://learn.hashicorp.com/terraform
- Vyatta/EdgeOS documentation (for USG config)

---

## Conclusion

For a homelab with existing Terraform and Ansible experience:

**Recommended Approach:**
1. **Primary:** Terraform (`paultyng/unifi` provider) for all standard network configuration
2. **Secondary:** `config.gateway.json` (Git-tracked, Ansible-deployed) for USG advanced features
3. **Orchestration:** Ansible for deploying config.gateway.json and running Terraform
4. **Backup:** Remote Terraform state + controller auto-backups + Git

**Do NOT use:**
- Ansible for network configuration (no good modules)
- Direct API (unless building custom tools)
- EdgeOS CLI for persistent config (lost on re-provision)

**Success Criteria:**
- All network config in Git
- `terraform plan` shows no drift
- Can rebuild controller from backups + code in <1 hour
- Changes tested in staging before production
- Runbooks documented for common operations
