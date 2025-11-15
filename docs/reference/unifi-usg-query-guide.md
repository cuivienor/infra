# UniFi Security Gateway (USG) Query Guide

**Purpose**: Comprehensive reference for extracting configuration, topology, and settings from a Ubiquiti USG for documentation purposes.

## Overview

The UniFi Security Gateway can be queried through three primary methods:
1. **SSH/CLI Access** - Direct command-line access to the gateway
2. **UniFi Controller API** - Programmatic access via REST API
3. **UI/Web Interface** - Manual exports and configuration downloads

---

## 1. SSH/CLI Access to USG

### Initial SSH Access

**Default Credentials:**
- Username: `ubnt` (legacy) or use your UniFi admin account
- Default password: `ubnt` (should be changed)
- SSH Port: `22`

**SSH Connection:**
```bash
ssh <username>@<USG_IP_ADDRESS>
```

**For UniFi OS devices (UDM/UDM-Pro), use port 22 for UniFi OS and access the gateway via:**
```bash
# Access UniFi OS console first
ssh root@<UDM_IP>

# Then access the network container if needed
unifi-os shell
```

### Essential CLI Commands for Configuration Extraction

#### Network Topology & Interface Configuration

```bash
# Show all interfaces and their configuration
show interfaces

# Detailed interface information
show interfaces detail

# Show VLAN configuration
show interfaces vlan

# Show switch port configuration (if USG has switch ports)
show interfaces ethernet detail

# Show routing table
show ip route

# Show IPv6 routing table (if enabled)
show ipv6 route

# Show ARP table (connected devices)
show arp

# Show DHCP leases
show dhcp leases

# Show DHCP statistics
show dhcp statistics
```

#### Firewall Rules

```bash
# Show all firewall rule sets
show firewall

# Show specific firewall group (WAN_IN, WAN_OUT, WAN_LOCAL, LAN_IN, etc.)
show firewall name WAN_IN
show firewall name WAN_LOCAL
show firewall name LAN_IN
show firewall name LAN_LOCAL

# Show NAT rules
show nat rules

# Show port forwarding rules
show nat destination

# Show firewall statistics
show firewall statistics
```

#### NAT & Port Forwarding

```bash
# Show NAT rules
show nat rules

# Show destination NAT (port forwarding)
show nat destination

# Show source NAT (masquerading)
show nat source

# Show active NAT translations
show nat translations
```

#### DNS Configuration

```bash
# Show DNS forwarding configuration
show dns forwarding

# Show DNS forwarding statistics
show dns forwarding statistics

# Show configured name servers
show dns forwarding nameservers
```

#### DHCP Server Configuration

```bash
# Show DHCP server configuration
show dhcp server

# Show DHCP leases
show dhcp leases

# Show DHCP statistics per subnet
show dhcp statistics
```

#### VPN Configuration

```bash
# Show IPsec VPN status (if configured)
show vpn ipsec sa
show vpn ipsec status

# Show OpenVPN status (if configured)
show openvpn status server
show openvpn status client

# Show L2TP configuration
show vpn l2tp remote-access
```

#### System Information

```bash
# Show system version and hardware
show version

# Show system uptime
show uptime

# Show hardware information
show hardware

# Show current configuration (running config)
show configuration

# Show configuration in commands format
show configuration commands
```

### Exporting Configuration via CLI

```bash
# Enter configuration mode
configure

# Show running configuration
show

# Save configuration to file (from operational mode)
save /config/user-data/backup-$(date +%Y%m%d).cfg

# Exit configuration mode
exit

# Copy configuration file via SCP (from your workstation)
scp <username>@<USG_IP>:/config/user-data/backup-*.cfg ./usg-config-backup.cfg
```

### EdgeOS Configuration Files

Important configuration files located on the USG:

```bash
# Main configuration file (EdgeOS)
/config/config.boot

# User data and custom configurations
/config/user-data/

# DNS forwarding configuration
/etc/dnsmasq.conf

# DHCP leases
/var/lib/dhcp/dhcpd.leases
```

**Copy files to local machine:**
```bash
# From your workstation
scp <username>@<USG_IP>:/config/config.boot ./usg-config.boot
scp <username>@<USG_IP>:/var/lib/dhcp/dhcpd.leases ./usg-dhcp-leases.txt
```

---

## 2. UniFi Controller API

The UniFi Controller provides a REST API for querying devices, configurations, and network topology.

### API Authentication

**Base URL Format:**
- Classic Controller: `https://<controller-ip>:8443`
- UniFi OS (UDM/UDM-Pro): `https://<device-ip>:443`
- UniFi OS Server: `https://<device-ip>:11443`

**Authentication Flow:**
```bash
# Login to controller
curl -k -X POST https://<controller-ip>:8443/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"<admin-user>","password":"<password>"}' \
  -c cookie.txt

# Note: Use the cookie.txt file for subsequent requests
```

### Key API Endpoints for Network Documentation

#### Sites

```bash
# List all sites
curl -k -X GET https://<controller-ip>:8443/api/self/sites \
  -b cookie.txt

# Get site settings
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/self \
  -b cookie.txt
```

#### Devices (USG, Switches, APs)

```bash
# List all devices
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/stat/device \
  -b cookie.txt

# Get specific device details
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/stat/device/<mac-address> \
  -b cookie.txt

# List USG configuration
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/device/<device-id> \
  -b cookie.txt
```

#### Networks (VLANs, Subnets)

```bash
# List all networks
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/networkconf \
  -b cookie.txt

# Get specific network configuration
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/networkconf/<network-id> \
  -b cookie.txt
```

#### Firewall Rules

```bash
# List firewall rules
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/firewallrule \
  -b cookie.txt

# List firewall groups
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/firewallgroup \
  -b cookie.txt
```

#### Port Forwarding

```bash
# List port forwarding rules
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/portforward \
  -b cookie.txt
```

#### Routing

```bash
# List static routes
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/routing \
  -b cookie.txt
```

#### Connected Clients

```bash
# List all active clients
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/stat/sta \
  -b cookie.txt

# List all known clients (including historical)
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/user \
  -b cookie.txt
```

#### Topology & Switch Ports

```bash
# List switches and their port configuration
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/stat/device \
  -b cookie.txt

# Get port configuration for a specific device
curl -k -X GET https://<controller-ip>:8443/api/s/<site-name>/rest/device/<device-id> \
  -b cookie.txt
```

### Using PHP API Client

For more robust API interaction, use the community-maintained PHP client:

**Installation:**
```bash
composer require art-of-wifi/unifi-api-client
```

**Example Usage:**
```php
<?php
require_once 'vendor/autoload.php';

use UniFi_API\Client;

$controller_user = 'admin';
$controller_password = 'password';
$controller_url = 'https://192.168.1.1:8443';
$site_id = 'default';  // Short site name (8 chars)

try {
    $unifi_connection = new Client(
        $controller_user,
        $controller_password,
        $controller_url,
        $site_id,
        '8.0.28',
        true  // SSL verify
    );
    
    $login = $unifi_connection->login();
    
    // Get all networks (VLANs)
    $networks = $unifi_connection->list_networkconf();
    print_r($networks);
    
    // Get all devices
    $devices = $unifi_connection->list_devices();
    print_r($devices);
    
    // Get firewall rules
    $firewall_rules = $unifi_connection->list_firewallrules();
    print_r($firewall_rules);
    
    // Get port forwarding rules
    $port_forwards = $unifi_connection->list_portforwarding();
    print_r($port_forwards);
    
    // Get all clients
    $clients = $unifi_connection->list_clients();
    print_r($clients);
    
    $unifi_connection->logout();
    
} catch (Exception $e) {
    echo 'Error: ' . $e->getMessage() . PHP_EOL;
}
?>
```

**Available Methods for Documentation:**
- `list_networkconf()` - VLANs and subnets
- `list_devices()` - All UniFi devices (USG, switches, APs)
- `list_firewallrules()` - Firewall rules
- `list_firewallgroups()` - Firewall address/port groups
- `list_portforwarding()` - NAT/port forwarding rules
- `list_routing()` - Static routes
- `list_clients()` - Connected devices
- `stat_sites()` - Site information
- `list_wlanconf()` - WiFi network configuration

**API Client GitHub:** https://github.com/Art-of-WiFi/UniFi-API-client

---

## 3. UI/Web Interface Exports

### Controller Web UI Access

**URL:**
- Classic Controller: `https://<controller-ip>:8443`
- UniFi OS: `https://<device-ip>`

### Configuration Exports via UI

#### 1. Site Settings Export

Navigate to: **Settings → System → Maintenance → Backup**

**Options:**
- Download backup (JSON format containing all site configuration)
- Contains: Networks, firewall rules, port forwarding, device settings

**Download location:** `Settings → System → Maintenance → Download Backup`

#### 2. Network Diagram Export

Navigate to: **Topology**

**Features:**
- Visual network topology
- Inter-device connections
- Switch port assignments
- Screenshot or export options (varies by controller version)

#### 3. Manual Configuration Documentation

**Settings to Document:**

**Networks:**
- Navigate to: `Settings → Networks`
- Document: VLAN ID, purpose, subnet, DHCP range, gateway

**Firewall Rules:**
- Navigate to: `Settings → Firewall & Security → Firewall Rules`
- Document: Name, rule type, protocol, source, destination, port

**Port Forwarding:**
- Navigate to: `Settings → Firewall & Security → Port Forwarding`
- Document: Name, protocol, external port, internal IP, internal port

**Routing:**
- Navigate to: `Settings → Routing`
- Document: Static routes, policy routes

**Site Settings:**
- Navigate to: `Settings → System → Site`
- Document: Site name, country, timezone

#### 4. Device Configuration

**For each device:**
- Navigate to: `Devices → <Device Name> → Settings`
- Document: Ports, VLANs, IP addresses, uplink configuration

---

## 4. Configuration Files Download

### UniFi Controller Backup

**Via UI:**
1. Navigate to `Settings → System → Maintenance → Backup`
2. Click "Download Backup"
3. File format: `.unf` (JSON compressed format)

**Extract backup contents:**
```bash
# The .unf file is a gzipped JSON file
gunzip -c autobackup_*.unf > backup.json
cat backup.json | jq '.' > backup-formatted.json
```

**Via SSH (if controller is on UDM/UDM-Pro):**
```bash
# SSH to UniFi OS device
ssh root@<udm-ip>

# Backups are stored at:
ls /data/unifi/data/backup/autobackup_*.unf

# Download via SCP
scp root@<udm-ip>:/data/unifi/data/backup/autobackup_*.unf ./
```

### USG Configuration Backup

**Via SSH to USG:**
```bash
# Connect to USG
ssh <username>@<usg-ip>

# Copy running configuration
show configuration commands > /config/running-config.txt

# Download via SCP
scp <username>@<usg-ip>:/config/running-config.txt ./
```

---

## 5. Best Practices for Network Topology Documentation

### Recommended Documentation Structure

#### 1. Network Overview Document

**Include:**
- Site name and location
- WAN configuration (IP, gateway, DNS)
- Internet service provider details
- Controller version and location

#### 2. VLAN/Network Inventory

Create a table with:
```
| VLAN ID | Name        | Purpose    | Subnet          | Gateway       | DHCP Range        |
|---------|-------------|------------|-----------------|---------------|-------------------|
| 1       | Default     | Management | 192.168.1.0/24  | 192.168.1.1   | .10 - .254        |
| 10      | IoT         | IoT        | 192.168.10.0/24 | 192.168.10.1  | .50 - .250        |
| 20      | Guest       | Guest      | 192.168.20.0/24 | 192.168.20.1  | .100 - .200       |
```

#### 3. Device Inventory

```
| Device Type | Name         | Model    | MAC Address       | Management IP   | Location    |
|-------------|--------------|----------|-------------------|-----------------|-------------|
| Gateway     | USG          | USG-3P   | xx:xx:xx:xx:xx:xx | 192.168.1.1     | Network Room|
| Switch      | Main-Switch  | US-24    | xx:xx:xx:xx:xx:xx | 192.168.1.2     | Network Room|
| AP          | Office-AP    | UAP-AC-PRO| xx:xx:xx:xx:xx:xx| 192.168.1.10    | Office      |
```

#### 4. Firewall Rules Documentation

```
| Rule Name          | Type | Source         | Destination    | Port/Protocol | Action |
|--------------------|------|----------------|----------------|---------------|--------|
| Block-IoT-to-LAN   | LAN  | VLAN 10        | VLAN 1         | All           | Drop   |
| Allow-Web-Server   | WAN  | Any            | 192.168.1.100  | 80/443 TCP    | Accept |
```

#### 5. Port Forwarding Rules

```
| Name        | External Port | Protocol | Forward IP    | Internal Port | Enabled |
|-------------|---------------|----------|---------------|---------------|---------|
| Web Server  | 80/443        | TCP      | 192.168.1.100 | 80/443        | Yes     |
| SSH Access  | 22022         | TCP      | 192.168.1.50  | 22            | Yes     |
```

#### 6. Switch Port Assignments

```
| Device      | Port | Type   | VLAN(s)      | Connected Device | Notes          |
|-------------|------|--------|--------------|------------------|----------------|
| Main-Switch | 1    | Trunk  | All          | USG eth1         | Uplink to USG  |
| Main-Switch | 2    | Access | 1            | Server 1         | Management     |
| Main-Switch | 10   | Access | 10           | IoT Hub          | IoT VLAN       |
| Main-Switch | 24   | Trunk  | 1,10,20      | Office-Switch    | Trunk to Office|
```

### Automation Scripts

#### Bash Script to Export All Configuration

```bash
#!/bin/bash
# unifi-export-config.sh

CONTROLLER_IP="192.168.1.1"
CONTROLLER_PORT="8443"
SITE_NAME="default"
USERNAME="admin"
PASSWORD="password"
OUTPUT_DIR="./unifi-export-$(date +%Y%m%d)"

mkdir -p "$OUTPUT_DIR"

# Login and get cookie
curl -k -X POST "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" \
  -c "${OUTPUT_DIR}/cookie.txt"

# Export networks
curl -k -X GET "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/s/${SITE_NAME}/rest/networkconf" \
  -b "${OUTPUT_DIR}/cookie.txt" \
  -o "${OUTPUT_DIR}/networks.json"

# Export devices
curl -k -X GET "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/s/${SITE_NAME}/stat/device" \
  -b "${OUTPUT_DIR}/cookie.txt" \
  -o "${OUTPUT_DIR}/devices.json"

# Export firewall rules
curl -k -X GET "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/s/${SITE_NAME}/rest/firewallrule" \
  -b "${OUTPUT_DIR}/cookie.txt" \
  -o "${OUTPUT_DIR}/firewall-rules.json"

# Export port forwarding
curl -k -X GET "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/s/${SITE_NAME}/rest/portforward" \
  -b "${OUTPUT_DIR}/cookie.txt" \
  -o "${OUTPUT_DIR}/port-forwarding.json"

# Export clients
curl -k -X GET "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/s/${SITE_NAME}/stat/sta" \
  -b "${OUTPUT_DIR}/cookie.txt" \
  -o "${OUTPUT_DIR}/clients.json"

# Export routing
curl -k -X GET "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/s/${SITE_NAME}/rest/routing" \
  -b "${OUTPUT_DIR}/cookie.txt" \
  -o "${OUTPUT_DIR}/routing.json"

# Logout
curl -k -X POST "https://${CONTROLLER_IP}:${CONTROLLER_PORT}/api/logout" \
  -b "${OUTPUT_DIR}/cookie.txt"

echo "Export complete: ${OUTPUT_DIR}"
```

#### USG Direct Configuration Export

```bash
#!/bin/bash
# usg-export-config.sh

USG_IP="192.168.1.1"
USG_USER="admin"
BACKUP_DIR="./usg-backup-$(date +%Y%m%d)"

mkdir -p "$BACKUP_DIR"

# Export configuration via SSH
ssh "${USG_USER}@${USG_IP}" "show configuration commands" > "${BACKUP_DIR}/config-commands.txt"
ssh "${USG_USER}@${USG_IP}" "show configuration" > "${BACKUP_DIR}/config-tree.txt"
ssh "${USG_USER}@${USG_IP}" "show interfaces" > "${BACKUP_DIR}/interfaces.txt"
ssh "${USG_USER}@${USG_IP}" "show firewall" > "${BACKUP_DIR}/firewall.txt"
ssh "${USG_USER}@${USG_IP}" "show nat rules" > "${BACKUP_DIR}/nat-rules.txt"
ssh "${USG_USER}@${USG_IP}" "show dhcp leases" > "${BACKUP_DIR}/dhcp-leases.txt"
ssh "${USG_USER}@${USG_IP}" "show dns forwarding" > "${BACKUP_DIR}/dns-forwarding.txt"

# Copy config files
scp "${USG_USER}@${USG_IP}:/config/config.boot" "${BACKUP_DIR}/"

echo "USG export complete: ${BACKUP_DIR}"
```

---

## 6. Quick Reference Commands

### Most Important Commands for Documentation

```bash
# === On USG via SSH ===

# Complete configuration dump
show configuration commands > /tmp/full-config.txt

# Network topology
show interfaces
show dhcp leases
show arp

# Firewall & Security
show firewall
show nat rules

# Routing
show ip route
show protocols

# === Via Controller API ===

# Get all configuration (after login)
curl -k -b cookie.txt https://<controller>:8443/api/s/default/rest/networkconf > networks.json
curl -k -b cookie.txt https://<controller>:8443/api/s/default/rest/firewallrule > firewall.json
curl -k -b cookie.txt https://<controller>:8443/api/s/default/stat/device > devices.json

# === Via UI ===

# Download full site backup
Settings → System → Maintenance → Download Backup
```

---

## 7. Useful Resources

### Official Documentation
- UniFi Controller API Documentation: Available in controller at `/dl/unifi_sh_api` (e.g., `https://controller:8443/dl/unifi_sh_api`)
- EdgeOS Command Reference: Via `man` pages on USG or Ubiquiti docs

### Community Tools
- **UniFi API Browser**: https://github.com/Art-of-WiFi/UniFi-API-browser
- **PHP UniFi API Client**: https://github.com/Art-of-WiFi/UniFi-API-client
- **Python unifi-api**: https://github.com/finish06/pyunifi

### Important Notes

**Security Considerations:**
- Use local admin accounts (not UniFi Cloud accounts) for API access
- Do not enable MFA/2FA on accounts used for API access
- Always use HTTPS/SSL when possible
- Secure API credentials and backup files

**Controller Access:**
- Classic controllers use port 8443
- UniFi OS (UDM/UDM-Pro) uses port 443
- UniFi OS Server uses port 11443

**Site ID Format:**
- Short site name is usually 8 characters (visible in URL: `/manage/site/xxxxxxxx/`)
- Default site is usually named "default"

---

## Summary

**Best Method for Homelab Documentation:**

1. **Start with SSH access** to USG for raw configuration (`show configuration commands`)
2. **Use Controller API** to extract structured data (networks, firewall rules, devices)
3. **Create automation scripts** to regularly export configuration
4. **Document in version control** (Git) with date-stamped exports
5. **Maintain human-readable tables** in Markdown for quick reference

**Recommended Workflow:**
1. Run automated export scripts weekly
2. Store JSON exports in `docs/reference/network-config/`
3. Maintain human-readable documentation in `docs/reference/networking.md`
4. Use Git to track changes over time
5. Include topology diagrams (exported screenshots or draw.io)

---

**Last Updated:** 2025-11-14  
**Tested With:** UniFi Controller 8.x, UniFi OS 2.x, USG 4.x firmware
