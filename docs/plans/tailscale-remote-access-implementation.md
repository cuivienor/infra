# Tailscale Remote Access Implementation Plan

**Created**: 2025-11-15  
**Status**: Ready to Execute  
**Purpose**: Enable secure remote access to homelab via Tailscale with redundant subnet routing

---

## Overview

Deploy Tailscale subnet routing to enable full remote access to homelab services:
- SSH to any host via `*.home.arpa`
- HTTPS web services via `*.paniland.com`
- Ad-blocking via Pi4 AdGuard Home
- Share access with friends via ACLs

## Architecture

```
Remote Client (you/friends)
    ↓
Tailscale Network
    ↓
Subnet Routers (redundant):
  - Pi4 (192.168.1.102) - Primary
  - Proxmox (192.168.1.100) - Secondary
    ↓
Your LAN (192.168.1.0/24)
    ↓
DNS: Pi4 AdGuard → resolves *.paniland.com and *.home.arpa
    ↓
Services: Jellyfin, Proxmox, etc.
```

**Key Benefits:**
- Same URLs work locally and remotely
- Ad-blocking follows you everywhere
- Redundant routing (Pi4 down? Proxmox takes over)
- Friend access with granular ACLs
- Mullvad exit nodes still work

---

## Prerequisites

- [x] Tailscale account created
- [x] Pi4 running AdGuard Home (192.168.1.102)
- [x] Proxmox host operational (192.168.1.100)
- [x] DNS rewrites configured for *.paniland.com and *.home.arpa
- [x] Reverse proxy with HTTPS (192.168.1.111)

---

## Phase 1: Tailscale Admin Setup (Manual, ~30 min)

### 1.1 Create OAuth Client

**Location**: https://login.tailscale.com/admin/settings/oauth

1. Go to Settings → OAuth Clients → "Generate OAuth Client"
2. Name: `homelab-iac`
3. Description: `Terraform and Ansible automation for homelab`
4. Scopes (check all):
   - `acl` - Manage access control policies
   - `devices` - Manage device authorization
   - `dns` - Configure DNS settings
   - `routes` - Manage subnet routes
   - `keys` - Generate auth keys
5. Click "Generate"
6. **SAVE BOTH VALUES SECURELY**:
   - OAuth Client ID: `xxxxxxxxxxxxxx`
   - OAuth Client Secret: `tskey-client-xxxxxx-xxxxxxxxx`

**Important**: The secret is shown only once. Store it immediately.

### 1.2 Note Your Tailnet Name

**Location**: https://login.tailscale.com/admin/settings/general

Your tailnet name looks like: `tail1234.ts.net` or a custom domain.

---

## Phase 2: Terraform Configuration (~1 hour)

### 2.1 Create Tailscale Terraform Config

**File**: `terraform/tailscale.tf`

```hcl
# Tailscale Infrastructure Configuration
# Manages ACLs, DNS, and auth keys for remote access

terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.16"
    }
  }
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  tailnet             = var.tailscale_tailnet
}

# Access Control List - defines who can access what
resource "tailscale_acl" "homelab" {
  acl = jsonencode({
    // Tag ownership - who can assign these tags
    tagOwners = {
      "tag:server"        = ["autogroup:admin"]
      "tag:subnet-router" = ["autogroup:admin"]
    }

    // Group definitions for access control
    groups = {
      // Add friend emails here when you want to share
      "group:friends" = []
    }

    // Access rules
    acls = [
      // Admins (you) can access everything
      {
        action = "accept"
        src    = ["autogroup:admin"]
        dst    = ["*:*"]
      },
      // Friends can access web services only
      {
        action = "accept"
        src    = ["group:friends"]
        dst    = [
          "192.168.1.111:80,443",    // Proxy (HTTPS services)
          "192.168.1.130:8096",       // Jellyfin direct (if needed)
        ]
      }
    ]

    // Auto-approve subnet routes from tagged devices
    autoApprovers = {
      routes = {
        "192.168.1.0/24" = ["tag:subnet-router"]
      }
    }
  })
}

# DNS Configuration - route queries to Pi4 AdGuard
resource "tailscale_dns_nameservers" "homelab" {
  nameservers = [
    "192.168.1.102"  // Pi4 AdGuard Home
  ]
}

resource "tailscale_dns_preferences" "homelab" {
  magic_dns = true
}

# Split DNS - route specific domains to your DNS
resource "tailscale_dns_split_nameservers" "paniland" {
  nameservers = ["192.168.1.102"]  // Pi4
  domain      = "paniland.com"
}

resource "tailscale_dns_split_nameservers" "home_arpa" {
  nameservers = ["192.168.1.102"]  // Pi4
  domain      = "home.arpa"
}

# Auth key for Pi4 subnet router (primary)
resource "tailscale_tailnet_key" "pi4_router" {
  reusable            = true
  ephemeral           = false
  preauthorized       = true
  expiry              = 7776000  // 90 days (maximum)
  description         = "Pi4 primary subnet router"
  tags                = ["tag:subnet-router"]
  recreate_if_invalid = "always"
}

# Auth key for Proxmox subnet router (secondary)
resource "tailscale_tailnet_key" "proxmox_router" {
  reusable            = true
  ephemeral           = false
  preauthorized       = true
  expiry              = 7776000  // 90 days (maximum)
  description         = "Proxmox secondary subnet router"
  tags                = ["tag:subnet-router"]
  recreate_if_invalid = "always"
}

# Outputs - for use in Ansible
output "tailscale_pi4_auth_key" {
  value       = tailscale_tailnet_key.pi4_router.key
  sensitive   = true
  description = "Auth key for Pi4 subnet router"
}

output "tailscale_proxmox_auth_key" {
  value       = tailscale_tailnet_key.proxmox_router.key
  sensitive   = true
  description = "Auth key for Proxmox subnet router"
}
```

### 2.2 Add Terraform Variables

**File**: `terraform/variables.tf` (add to existing)

```hcl
# Tailscale configuration
variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name (e.g., tail1234.ts.net)"
  type        = string
}
```

### 2.3 Update terraform.tfvars

**File**: `terraform/terraform.tfvars` (add to existing)

```hcl
# Tailscale (DO NOT COMMIT - add to .gitignore if not already)
tailscale_oauth_client_id     = "your-client-id"
tailscale_oauth_client_secret = "tskey-client-xxxxx"
tailscale_tailnet             = "your-tailnet.ts.net"
```

### 2.4 Apply Terraform

```bash
cd terraform
terraform init -upgrade  # Get Tailscale provider
terraform plan
terraform apply
```

### 2.5 Export Auth Keys to Ansible Vault

```bash
# Get the auth keys and encrypt for Ansible
cd ~/dev/homelab-notes

# Pi4 key
terraform -chdir=terraform output -raw tailscale_pi4_auth_key | \
  ansible-vault encrypt_string --vault-password-file .vault_pass \
  --stdin-name vault_tailscale_pi4_auth_key

# Proxmox key
terraform -chdir=terraform output -raw tailscale_proxmox_auth_key | \
  ansible-vault encrypt_string --vault-password-file .vault_pass \
  --stdin-name vault_tailscale_proxmox_auth_key

# Add both to ansible/vars/secrets.yml
```

---

## Phase 3: Ansible Subnet Router Role (~1 hour)

### 3.1 Create Tailscale Role

**Directory Structure**:
```
ansible/roles/tailscale_subnet_router/
├── defaults/main.yml
├── handlers/main.yml
├── tasks/main.yml
└── templates/
```

**File**: `ansible/roles/tailscale_subnet_router/defaults/main.yml`

```yaml
---
# Tailscale subnet router defaults

# Auth key - REQUIRED, set from vault
tailscale_auth_key: ""

# Routes to advertise
tailscale_advertise_routes:
  - "192.168.1.0/24"

# Tags to apply to this device
tailscale_tags:
  - "tag:subnet-router"

# Accept routes from other nodes
tailscale_accept_routes: false

# Use Tailscale DNS (we want this for our DNS config)
tailscale_accept_dns: true

# Hostname in Tailscale admin (defaults to system hostname)
tailscale_hostname: ""
```

**File**: `ansible/roles/tailscale_subnet_router/handlers/main.yml`

```yaml
---
- name: restart tailscaled
  systemd:
    name: tailscaled
    state: restarted
  become: true
```

**File**: `ansible/roles/tailscale_subnet_router/tasks/main.yml`

```yaml
---
# Install and configure Tailscale as subnet router

- name: Check if Tailscale is already installed
  stat:
    path: /usr/bin/tailscale
  register: tailscale_installed

- name: Install Tailscale (Debian/Ubuntu)
  when:
    - not tailscale_installed.stat.exists
    - ansible_os_family == "Debian"
  block:
    - name: Add Tailscale GPG key
      shell: |
        curl -fsSL https://pkgs.tailscale.com/stable/{{ ansible_distribution | lower }}/{{ ansible_distribution_release }}.noarmor.gpg | \
        tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
      args:
        creates: /usr/share/keyrings/tailscale-archive-keyring.gpg
      become: true

    - name: Add Tailscale repository
      copy:
        content: |
          deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} main
        dest: /etc/apt/sources.list.d/tailscale.list
      become: true

    - name: Install Tailscale package
      apt:
        name: tailscale
        state: present
        update_cache: true
      become: true

- name: Enable IP forwarding for subnet routing
  sysctl:
    name: "{{ item }}"
    value: '1'
    sysctl_set: true
    state: present
    reload: true
  loop:
    - net.ipv4.ip_forward
    - net.ipv6.conf.all.forwarding
  become: true

- name: Ensure tailscaled service is running
  systemd:
    name: tailscaled
    state: started
    enabled: true
  become: true

- name: Check current Tailscale status
  command: tailscale status --json
  register: tailscale_status_check
  failed_when: false
  changed_when: false
  become: true

- name: Authenticate and configure Tailscale
  command: >
    tailscale up
    --auth-key={{ tailscale_auth_key }}
    --advertise-routes={{ tailscale_advertise_routes | join(',') }}
    --advertise-tags={{ tailscale_tags | join(',') }}
    {% if tailscale_hostname %}--hostname={{ tailscale_hostname }}{% endif %}
    --accept-routes={{ tailscale_accept_routes | lower }}
    --accept-dns={{ tailscale_accept_dns | lower }}
    --reset
  when: >
    tailscale_status_check.rc != 0 or
    'BackendState' not in (tailscale_status_check.stdout | from_json)
  become: true

- name: Get Tailscale IP
  command: tailscale ip -4
  register: tailscale_ip
  changed_when: false
  become: true

- name: Display Tailscale configuration
  debug:
    msg: |
      Tailscale subnet router configured!

      Tailscale IP: {{ tailscale_ip.stdout }}
      Advertised routes: {{ tailscale_advertise_routes | join(', ') }}
      Tags: {{ tailscale_tags | join(', ') }}

      This device is now advertising {{ tailscale_advertise_routes | join(', ') }}
      Routes should be auto-approved via ACL autoApprovers.
```

### 3.2 Create Tailscale Playbook

**File**: `ansible/playbooks/tailscale.yml`

```yaml
---
# Tailscale Subnet Router Deployment
#
# Configures redundant subnet routing for remote access.
# Primary: Pi4, Secondary: Proxmox host
#
# Prerequisites:
# - Terraform applied (ACLs, DNS, auth keys configured)
# - Auth keys stored in Ansible Vault
#
# Usage:
#   ansible-playbook ansible/playbooks/tailscale.yml --vault-password-file .vault_pass

- name: Configure Pi4 as Primary Subnet Router
  hosts: pi4
  become: true
  gather_facts: true

  vars_files:
    - ../vars/secrets.yml

  vars:
    tailscale_auth_key: "{{ vault_tailscale_pi4_auth_key }}"
    tailscale_hostname: "pi4-router"
    tailscale_advertise_routes:
      - "192.168.1.0/24"
    tailscale_tags:
      - "tag:subnet-router"

  pre_tasks:
    - name: Display configuration
      debug:
        msg: |
          Configuring Pi4 as PRIMARY subnet router

          Host: {{ inventory_hostname }} ({{ ansible_host }})
          Routes: {{ tailscale_advertise_routes | join(', ') }}
          Tags: {{ tailscale_tags | join(', ') }}

          This will enable remote access to your entire homelab!

  roles:
    - role: tailscale_subnet_router
      tags: ['tailscale']


- name: Configure Proxmox as Secondary Subnet Router
  hosts: proxmox_host
  become: true
  gather_facts: true

  vars_files:
    - ../vars/secrets.yml

  vars:
    tailscale_auth_key: "{{ vault_tailscale_proxmox_auth_key }}"
    tailscale_hostname: "proxmox-router"
    tailscale_advertise_routes:
      - "192.168.1.0/24"
    tailscale_tags:
      - "tag:subnet-router"

  pre_tasks:
    - name: Display configuration
      debug:
        msg: |
          Configuring Proxmox as SECONDARY subnet router

          Host: {{ inventory_hostname }} ({{ ansible_host }})
          Routes: {{ tailscale_advertise_routes | join(', ') }}
          Tags: {{ tailscale_tags | join(', ') }}

          This provides redundancy if Pi4 goes down.

  roles:
    - role: tailscale_subnet_router
      tags: ['tailscale']


- name: Display Final Status
  hosts: localhost
  gather_facts: false

  tasks:
    - name: Show next steps
      debug:
        msg: |
          ✅ Tailscale Subnet Routing Configured!

          Primary Router: Pi4 (192.168.1.102)
          Secondary Router: Proxmox (192.168.1.100)

          NEXT STEPS:
          1. Check Tailscale admin console - routes should be auto-approved
          2. Install Tailscale on your laptop/phone
          3. Test remote access:
             - ssh root@jellyfin.home.arpa
             - https://jellyfin.paniland.com
          4. Verify DNS queries go through Pi4 (ad-blocking works)

          SHARING WITH FRIENDS:
          1. Edit terraform/tailscale.tf
          2. Add email to group:friends
          3. Run terraform apply
          4. Friend accepts Tailscale invite
          5. They can access allowed services

          MULLVAD EXIT NODES:
          - Works alongside subnet routing
          - Internet traffic exits via Mullvad
          - Homelab traffic still routes through your subnet routers
```

---

## Phase 4: Testing (~30 min)

### 4.1 Verify Subnet Routes Approved

**Location**: https://login.tailscale.com/admin/machines

Check that both Pi4 and Proxmox show:
- Status: Connected
- Subnet routes: 192.168.1.0/24 (approved)
- Tags: tag:subnet-router

### 4.2 Install Tailscale on Client Device

**macOS/Linux/Windows**: Download from https://tailscale.com/download

**Mobile**: App Store / Google Play

Login with same account.

### 4.3 Test Remote Access

**Disconnect from home WiFi** (use mobile hotspot or different network)

```bash
# Test DNS resolution
dig jellyfin.paniland.com
# Should return: 192.168.1.111

dig jellyfin.home.arpa
# Should return: 192.168.1.130

# Test SSH
ssh root@jellyfin.home.arpa
# Should connect!

# Test HTTPS
curl -I https://jellyfin.paniland.com
# Should return HTTP 200/302

# Test ad-blocking
dig ads.google.com
# Should return 0.0.0.0 (if ad-blocking enabled in AdGuard)
```

### 4.4 Test Failover

1. SSH into homelab: `ssh root@jellyfin.home.arpa`
2. Stop Tailscale on Pi4: `ssh cuiv@pi4.home.arpa "sudo systemctl stop tailscaled"`
3. Wait 30 seconds for failover
4. Test connection again - should still work via Proxmox
5. Restart Pi4: `ssh cuiv@pi4.home.arpa "sudo systemctl start tailscaled"`

---

## Phase 5: Friend Access (Optional)

### 5.1 Add Friend to ACL

Edit `terraform/tailscale.tf`:

```hcl
groups = {
  "group:friends" = ["friend@gmail.com"]  // Add their email
}
```

Apply:
```bash
cd terraform && terraform apply
```

### 5.2 Invite Friend

1. Go to https://login.tailscale.com/admin/users
2. Click "Invite users"
3. Enter friend's email
4. They receive invite, create Tailscale account
5. Once connected, they can access allowed services:
   - https://jellyfin.paniland.com (via proxy)
   - Direct Jellyfin on port 8096

### 5.3 Adjust Friend Permissions

Modify the ACL to grant more/less access:

```hcl
// Friends can only access Jellyfin
{
  action = "accept"
  src    = ["group:friends"]
  dst    = ["192.168.1.111:443"]  // Only HTTPS proxy
}

// Or give full subnet access
{
  action = "accept"
  src    = ["group:friends"]
  dst    = ["192.168.1.0/24:*"]  // Everything
}
```

---

## Maintenance

### Auth Key Rotation (Every 90 Days)

Tailscale auth keys expire after 90 days maximum. Terraform will auto-recreate them.

```bash
cd terraform
terraform plan  # Should show key recreation
terraform apply
# Re-export to Ansible vault
# Re-run Ansible playbook
```

### Adding New Services

1. Add DNS rewrite in `ansible/playbooks/dns.yml`
2. Add proxy target in `ansible/playbooks/proxy.yml`
3. Redeploy both playbooks
4. Service immediately accessible locally and remotely

### Monitoring

- Tailscale admin: https://login.tailscale.com/admin/machines
- Check device connectivity, route status
- View network activity logs

---

## Troubleshooting

### Routes Not Approved

Check ACL autoApprovers section includes `tag:subnet-router`:
```hcl
autoApprovers = {
  routes = {
    "192.168.1.0/24" = ["tag:subnet-router"]
  }
}
```

### DNS Not Resolving

1. Verify split DNS configured in Terraform
2. Check `tailscale dns status` on client
3. Ensure Pi4 is reachable via Tailscale

### Can't Connect to Services

1. Check subnet route is enabled on client: `tailscale status`
2. Verify route is approved in admin console
3. Test direct IP: `ping 192.168.1.130`

### Failover Not Working

Both routers must advertise the same route. Tailscale auto-selects based on:
- Latency
- Device health
- Route priority

---

## Files Changed/Created

```
terraform/
  tailscale.tf (NEW)
  variables.tf (MODIFIED - add Tailscale vars)
  terraform.tfvars (MODIFIED - add credentials, DO NOT COMMIT)

ansible/
  vars/secrets.yml (MODIFIED - add auth keys)
  roles/tailscale_subnet_router/ (NEW)
    defaults/main.yml
    handlers/main.yml
    tasks/main.yml
  playbooks/tailscale.yml (NEW)
```

---

## Security Considerations

1. **OAuth credentials**: Store securely, don't commit to git
2. **Auth keys**: Encrypted in Ansible Vault, rotate every 90 days
3. **ACLs**: Principle of least privilege for friends
4. **Tailnet Lock**: Consider enabling for production (prevents rogue devices)
5. **MFA**: Enable on Tailscale account

---

## Estimated Time

- Phase 1 (Admin setup): 30 minutes
- Phase 2 (Terraform): 1 hour
- Phase 3 (Ansible): 1 hour
- Phase 4 (Testing): 30 minutes
- **Total**: ~3 hours

---

## Success Criteria

- [ ] Pi4 and Proxmox both advertising 192.168.1.0/24
- [ ] Routes auto-approved via ACL
- [ ] Remote SSH works: `ssh root@jellyfin.home.arpa`
- [ ] Remote HTTPS works: `https://jellyfin.paniland.com`
- [ ] DNS queries go through Pi4 (ad-blocking active)
- [ ] Failover works (Pi4 down → Proxmox takes over)
- [ ] Mullvad exit nodes still functional
- [ ] Friend can access shared services (when configured)

---

**Ready to execute!** Start with Phase 1: Create OAuth Client in Tailscale admin.
