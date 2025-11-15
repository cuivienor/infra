# Proxmox Host Network Role

Manages the network configuration for the Proxmox host itself (not containers).

## Purpose

Configures static IP addressing for the Proxmox hypervisor, ensuring:
- Static IP configuration on the host (independent of DHCP)
- Proper bridge configuration for VMs/containers
- Consistent, version-controlled network settings
- Infrastructure as Code approach

## Variables

### Required Variables

None - defaults are provided in `defaults/main.yml`

### Default Variables

```yaml
# Network configuration
proxmox_host_ip: "192.168.1.100"          # Static IP for Proxmox host
proxmox_host_netmask: "24"                # Network mask
proxmox_host_gateway: "192.168.1.1"       # Default gateway
proxmox_host_dns_servers:                 # DNS servers
  - "1.1.1.1"
  - "1.0.0.1"

# Bridge configuration
proxmox_bridge_name: "vmbr0"              # Proxmox bridge interface
proxmox_physical_interface: "eno1"        # Physical NIC to bridge

# Bridge settings
proxmox_bridge_stp: "off"                 # Spanning Tree Protocol
proxmox_bridge_fd: "0"                    # Forward delay
```

### Overriding Variables

Create `ansible/group_vars/proxmox_hosts/network.yml`:

```yaml
---
proxmox_host_ip: "192.168.1.100"
proxmox_host_gateway: "192.168.1.1"
```

Or pass via playbook:

```bash
ansible-playbook playbooks/proxmox-network.yml -e "proxmox_host_ip=192.168.1.100"
```

## Usage

### Deploy Network Configuration

```bash
cd ansible
ansible-playbook playbooks/proxmox-network.yml
```

### Check Mode (Dry Run)

```bash
ansible-playbook playbooks/proxmox-network.yml --check
```

### With Custom IP

```bash
ansible-playbook playbooks/proxmox-network.yml -e "proxmox_host_ip=192.168.1.100"
```

## What It Does

1. **Backs up** current `/etc/network/interfaces`
2. **Deploys** new network configuration from template
3. **Validates** configuration syntax
4. **Applies** configuration via `ifreload -a`
5. **Waits** for new IP to become reachable (if IP changed)

## Important Notes

### IP Address Change

⚠️ **If changing IP address:**
- SSH connection will be lost during apply
- Update `ansible/inventory/hosts.yml` with new IP
- Remove old DHCP reservation from UniFi Controller
- Reconnect to new IP

### Migration Steps

When migrating Proxmox host IP (e.g., .56 → .100):

1. **Deploy new configuration:**
   ```bash
   ansible-playbook playbooks/proxmox-network.yml -e "proxmox_host_ip=192.168.1.100"
   ```

2. **Update Ansible inventory** (`ansible/inventory/hosts.yml`):
   ```yaml
   homelab:
     ansible_host: 192.168.1.100
   ```

3. **Remove DHCP reservation** from UniFi:
   ```bash
   # Via API or Controller UI
   curl -k -b /tmp/unifi-cookie.txt -X PUT \
     https://192.168.1.11:8443/api/s/default/rest/user/{id} \
     -d '{"use_fixedip":false}'
   ```

4. **Test connectivity:**
   ```bash
   ssh root@192.168.1.100
   ping 192.168.1.100
   ```

5. **Verify containers work:**
   ```bash
   ssh root@192.168.1.100 "pct list"
   ssh root@192.168.1.100 "pct exec 300 -- ping -c 2 1.1.1.1"
   ```

## Files Managed

- `/etc/network/interfaces` - Main network configuration
- Backup: `/etc/network/interfaces.backup.{timestamp}`

## Dependencies

None

## Tags

None currently implemented

## Rollback

If network configuration breaks:

1. **Console access** (Proxmox web UI or physical)
2. **Restore backup:**
   ```bash
   cp /etc/network/interfaces.backup.{timestamp} /etc/network/interfaces
   ifreload -a
   ```

3. **Or manual fix:**
   ```bash
   nano /etc/network/interfaces
   # Fix configuration
   ifreload -a
   ```

## Testing

### Verify Configuration

```bash
# Check current IP
ssh root@homelab "ip addr show vmbr0"

# Check routing
ssh root@homelab "ip route"

# Check DNS
ssh root@homelab "cat /etc/resolv.conf"

# Test internet connectivity
ssh root@homelab "ping -c 2 1.1.1.1"
```

### Verify Containers

```bash
# List containers
ssh root@homelab "pct list"

# Test container network
ssh root@homelab "pct exec 300 -- ping -c 2 8.8.8.8"
```

## Related

- **Playbook:** `ansible/playbooks/proxmox-network.yml`
- **Inventory:** `ansible/inventory/hosts.yml`
- **Storage Role:** `ansible/roles/proxmox_storage/`
- **IP Strategy:** `docs/reference/ip-allocation-strategy.md`

## Example

```yaml
---
- name: Configure Proxmox network
  hosts: proxmox_hosts
  roles:
    - role: proxmox_host_network
      vars:
        proxmox_host_ip: "192.168.1.100"
        proxmox_host_gateway: "192.168.1.1"
```

## Maintenance

Update IP address allocation in:
- `docs/reference/ip-allocation-strategy.md`
- `ansible/inventory/hosts.yml`
- UniFi Controller (remove DHCP reservation)
