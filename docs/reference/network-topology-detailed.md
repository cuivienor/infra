# Complete Network Topology - Paniland Home Network

**Last Updated:** 2025-11-14  
**Site:** Home (default)  
**USG Version:** UniFiSecurityGateway.ER-e120.v4.4.57.5578372.230112.0823

## Executive Summary

Your "Paniland" home network is a well-structured UniFi ecosystem with:
- **1 USG (Security Gateway)** providing routing and firewall
- **4 UniFi Switches** (1x USL16LP, 3x USMINI)
- **2 Access Points** (UAL6 models)
- **4 Wireless Networks** (Main, IoT, Guest, 2.4GHz)
- **3 VLANs** (Private, IoT VLAN 20, Guest VLAN 10)
- **34 Active Clients** (13 wired, 21 wireless)

## Network Infrastructure Devices

### Gateway
| Device | Model | IP | MAC | Role |
|--------|-------|-----|-----|------|
| Security Gateway | UGW3 | 70.23.3.211 (WAN), 192.168.1.1 (LAN) | f0:9f:c2:16:bf:17 | Router/Firewall |

### Switches

| Device | Model | IP | MAC | Uplinks To | Ports |
|--------|-------|-----|-----|-----------|-------|
| Main Switch | USL16LP | 192.168.1.5 | 24:5a:4c:59:77:d7 | USG | 16 (PoE) |
| Bedroom Switch | USMINI | 192.168.1.9 | 68:d7:9a:31:c9:19 | Main Switch Port 6 | 5 |
| Lab Switch | USMINI | 192.168.1.8 | 68:d7:9a:31:c8:de | Main Switch Port 8 | 5 |
| Living Room Switch | USMINI | 192.168.1.10 | 68:d7:9a:31:c9:26 | Main Switch Port 1 | 5 |

### Access Points

| Device | Model | IP | MAC | Location | Connected Clients |
|--------|-------|-----|-----|----------|------------------|
| Living Room AP | UAL6 | 192.168.1.6 | 24:5a:4c:11:47:58 | Living Room | Multiple |
| Bedroom AP | UAL6 | 192.168.1.7 | 24:5a:4c:11:47:d4 | Bedroom | Multiple |

## Physical Topology

```
[Internet]
    |
    | eth0 (70.23.3.211)
    |
[USG Security Gateway]
    |
    | eth1 (192.168.1.1)
    | eth1.20 (192.168.20.1 - IoT VLAN)
    |
    +--- Port ? ---> [Main Switch - USL16LP] (192.168.1.5)
                           |
                           +--- Port 1 ---> [Living Room Switch - USMINI] (192.168.1.10)
                           |                      |
                           |                      +--- Port 2: NVidia Shield TV Pro
                           |                      +--- Port 3: Denon AVR (IoT VLAN)
                           |
                           +--- Port 2 ---> [Living Room AP] (192.168.1.6) PoE
                           |
                           +--- Port 6 ---> [Bedroom Switch - USMINI] (192.168.1.9)
                           |                      |
                           |                      +--- Port 4: Peters-MBP
                           |
                           +--- Port 7 ---> [UniFi Cloud Key] (192.168.1.11) PoE
                           |
                           +--- Port 8 ---> [Lab Switch - USMINI] (192.168.1.8)
                           |                      |
                           |                      +--- Port 2: raspberrypi (192.168.1.114)
                           |                      +--- Port 3: pihole (192.168.1.107)
                           |                      +--- Port 4: homelab (192.168.1.56) + 3 containers
                           |
                           +--- Port 14: Lutron Hub (IoT VLAN)
                           +--- Port 15: Philips Hue Bridge (IoT VLAN)
                           +--- Port 16: (Active, unknown device)
```

## Network Segments

### 1. Private Network (192.168.1.0/24)
- **Interface:** eth1 (untagged)
- **Gateway:** 192.168.1.1
- **DNS Server:** 192.168.1.1 → 1.1.1.1
- **DHCP Range:** 192.168.1.6 - 192.168.1.254
- **Domain:** lan
- **Purpose:** Main trusted network
- **Connected Devices:** ~65 (mix of wired and wireless)

### 2. IoT Network (192.168.20.0/24)
- **Interface:** eth1.20 (VLAN 20)
- **Gateway:** 192.168.20.1
- **DHCP Range:** 192.168.20.6 - 192.168.20.254
- **Purpose:** Isolated IoT devices
- **Isolation:** Firewall rule prevents IoT → Private (see security notes)
- **Connected Devices:** ~15

**IoT Devices:**
- Philips Hue Bridge (192.168.20.17) - Port 15 on Main Switch
- Lutron Hub (192.168.20.18) - Port 14 on Main Switch
- Denon AVR (192.168.20.25) - Living Room Switch
- Nest Cameras (192.168.20.21, 35)
- Levoit Air Purifiers/Humidifiers (x5)
- Google TV (192.168.20.22)
- iRobot Vacuum (192.168.20.34)
- Nanit Baby Monitor (192.168.20.35)
- Rest Sound Machines (192.168.20.33, 44)

### 3. Guest Network (192.168.10.0/24)
- **Interface:** VLAN 10
- **Gateway:** 192.168.10.1
- **Status:** Configured but currently INACTIVE
- **SSID:** Paniland-Guest (Open WiFi)

### 4. WAN (Internet)
- **Interface:** eth0
- **IP:** 70.23.3.211/24 (DHCP from ISP)
- **Gateway:** 70.23.3.1

## Wireless Networks (SSIDs)

| SSID | Security | VLAN | Purpose | Status |
|------|----------|------|---------|--------|
| Paniland | WPA-PSK | Default (Private) | Main WiFi | Active |
| Paniland-2.4 | WPA-PSK | Default (Private) | 2.4GHz only | Active |
| Paniland-IoT | WPA-PSK | Default (should be VLAN 20!) | IoT devices | Active ⚠️ |
| Paniland-Guest | Open | Default (should be VLAN 10!) | Guest WiFi | Active ⚠️ |

**⚠️ SECURITY ISSUE:** IoT and Guest SSIDs are on "default" VLAN instead of their designated VLANs (20 and 10).

## Main Switch Port Map (USL16LP - 192.168.1.6)

| Port | Device/Name | Speed | PoE | VLAN | Status |
|------|-------------|-------|-----|------|--------|
| 1 | Living Room Switch | 1000 Mbps | Yes | - | UP |
| 2 | Living Room AP | 1000 Mbps | Yes | - | UP |
| 3 | - | - | No | - | DOWN |
| 4 | - | - | No | - | DOWN |
| 5 | - | - | No | - | DOWN |
| 6 | Bedroom Switch | 1000 Mbps | Yes | - | UP |
| 7 | UniFi Cloud Key | 1000 Mbps | Yes | - | UP |
| 8 | Lab Switch | 1000 Mbps | Yes | - | UP |
| 9 | - | - | No | - | DOWN |
| 10 | - | - | No | - | DOWN |
| 11 | - | - | No | - | DOWN |
| 12 | - | - | No | - | DOWN |
| 13 | - | - | No | - | DOWN |
| 14 | Lutron Hub | 100 Mbps | No | IoT? | UP |
| 15 | Philips Hue Bridge | 100 Mbps | No | IoT? | UP |
| 16 | Unknown Device | 1000 Mbps | No | - | UP |

## Key Devices Inventory

### Infrastructure & Services
| Hostname | IP | MAC | Location | Notes |
|----------|-----|-----|----------|-------|
| UniFi Cloud Key | 192.168.1.7 | f0:9f:c2:c6:d7:af | Main Switch Port 7 | Controller |
| pihole | 192.168.1.107 | b8:27:eb:7c:24:24 | Lab Switch Port 3 | DNS/Ad-blocking |
| homelab | 192.168.1.56 | 70:85:c2:a5:c3:c4 | Lab Switch Port 4 | Proxmox host ⚠️ IPS block |
| samba | 192.168.1.82 | bc:24:11:f0:27:97 | Lab Switch Port 4 | CT301 container |
| raspberrypi | 192.168.1.114 | dc:a6:32:d4:85:77 | Lab Switch Port 2 | Raspberry Pi |

**Note:** Multiple devices on Lab Switch Port 4 suggests Proxmox containers sharing the host's MAC.

### Workstations
| Hostname | IP | MAC | Connection | Notes |
|----------|-----|-----|------------|-------|
| Peters-MBP | 192.168.1.8 | 6c:6e:07:1f:08:38 | Bedroom Switch Port 4 | MacBook Pro (wired) |
| MacBookPro | 192.168.1.225 | c6:6d:d8:a7:d5:50 | WiFi (Paniland) | MacBook Pro (wireless) |
| iPhone | 192.168.1.220 | be:c9:91:d9:26:59 | WiFi (Paniland) | iPhone |
| Pixel-9a | 192.168.1.253 | 8e:b1:d3:b7:ab:68 | WiFi (Paniland) | Android phone |

### Entertainment
| Hostname | IP | MAC | Connection | Notes |
|----------|-----|-----|------------|-------|
| NVidia Shield TV Pro | 192.168.1.141 | 48:b0:2d:92:b7:be | Living Room Switch Port 2 | Streaming |
| Denon-AVR-S760H | 192.168.20.25 | 00:06:78:9f:0f:9c | Living Room Switch Port 3 | AV Receiver (IoT VLAN) |
| Google-TV | 192.168.20.22 | 1c:53:f9:25:4a:15 | WiFi (IoT) | Chromecast/Google TV |

## DHCP Static Mappings

| MAC Address | IP Address | Device |
|-------------|------------|--------|
| 70:85:c2:a5:c3:c4 | 192.168.1.56 | homelab (Proxmox) |
| b8:27:eb:7c:24:24 | 192.168.1.107 | pihole |
| d4:4d:a4:aa:26:25 | 192.168.1.86 | Unknown |
| d4:5d:64:d1:90:dc | 192.168.1.32 | Unknown |
| dc:a6:32:d4:85:77 | 192.168.1.114 | raspberrypi |

## DNS Configuration

**Primary DNS:** dnsmasq on USG (192.168.1.1)

### Custom DNS Records
- `unifi.lan` → 192.168.1.7
- `unifi` → CNAME to unifi.lan
- `SecurityGateway` → 192.168.1.1

### Forwarders
- 1.1.1.1 (Cloudflare)

### Options
- Cache: 10,000 entries
- All-servers mode (queries all upstreams)

## Port Profiles/VLANs

| Profile Name | VLAN ID | Network ID | Purpose |
|--------------|---------|------------|---------|
| All | Default | - | Untagged access |
| Disabled | - | - | Disabled ports |
| Private | Default | 5b6903abe9dc300f8bf5cd3b | Main network |
| IoT | 20 | 60b61fd5e9dc300487d92a0a | IoT VLAN |
| Paniland-Guest | 10 | 62407436e9dc306717e3e48b | Guest VLAN |

## Security Configuration

### Firewall Rules Summary

**WAN → LAN (WAN_IN):**
- Default: DROP
- Rule 2000: DROP IoT → Private (⚠️ wrong chain, may not work)
- Rule 3001: ACCEPT established/related
- Rule 3002: DROP invalid

**LAN → WAN (LAN_IN):**
- Default: ACCEPT
- Accounting rules for traffic tracking

**Internet → Gateway (WAN_LOCAL):**
- Default: DROP
- Allow established/related only
- 3.3M packets dropped

**Gateway → Internet (WAN_OUT):**
- Default: ACCEPT
- Rule 2000: **IPS BLOCK** - 192.168.1.56 → 125.105.238.106

### NAT Rules
- MASQUERADE all corporate_network (192.168.1.0/24, 192.168.20.0/24) to WAN
- No port forwarding configured

### Security Observations
1. ✅ Stateful firewall enabled
2. ✅ Default deny on WAN
3. ⚠️ IoT isolation rule in wrong firewall chain
4. ⚠️ WiFi SSIDs not properly VLAN-tagged
5. ⚠️ IPS block on homelab server (192.168.1.56) - investigate
6. ✅ No port forwarding (good security posture)

## Critical Issues & Recommendations

### 🔴 HIGH PRIORITY

1. **VLAN Misconfiguration on WiFi SSIDs**
   - **Issue:** `Paniland-IoT` and `Paniland-Guest` are on default VLAN instead of VLANs 20 and 10
   - **Impact:** IoT devices can access Private network, defeating isolation
   - **Fix:** In UniFi Controller → Settings → Wireless Networks:
     - Paniland-IoT → Set VLAN to 20
     - Paniland-Guest → Set VLAN to 10

2. **IoT Firewall Rule Ineffective**
   - **Issue:** Rule 2000 (block IoT→Private) is in WAN_IN chain
   - **Impact:** Not blocking inter-VLAN traffic as intended
   - **Fix:** Move to LAN_IN chain or verify current effectiveness with testing

3. **IPS Block on Homelab Server**
   - **Issue:** Traffic from 192.168.1.56 to 125.105.238.106 is blocked
   - **Action:**
     - Check homelab server for compromise
     - Review IPS/IDS logs
     - Determine if 125.105.238.106 is malicious
     - Remove block if false positive

### 🟡 MEDIUM PRIORITY

4. **Missing Static DHCP Reservations**
   - Add reservations for:
     - All switches (192.168.1.6, .44, .112, .113)
     - Access points (192.168.1.9, .10)
     - Infrastructure (Cloud Key .7 already has DNS entry)

5. **Document Unknown Devices**
   - Port 16 on Main Switch (1000 Mbps device)
   - Multiple devices showing as "Unknown" in client list
   - Static mappings at .32 and .86 need identification

6. **Guest Network Not Isolated**
   - Guest network configured but VLAN misconfiguration allows Private access
   - Consider enabling captive portal
   - Set bandwidth limits

### 🟢 LOW PRIORITY

7. **Optimize Switch Layout**
   - Consider consolidating rarely-used ports
   - PoE budget review (PoE on ports 1,2,6,7,8)

8. **Enable Traffic Analytics**
   - Currently disabled (DPI disabled)
   - Would provide better visibility

9. **Backup Configuration**
   - Set up automated UniFi Controller backups
   - Export USG config regularly

## UniFi Controller Information

- **IP:** 192.168.1.7 (UniFi Cloud Key)
- **Management URL:** https://192.168.1.7:8443
- **Site:** Home (default)
- **Access:** cuiv user configured

## Related Files

- `docs/reference/usg-config-raw.txt` - Complete USG configuration
- `docs/reference/unifi-devices.json` - Device inventory (JSON)
- `docs/reference/unifi-clients.json` - Client list (JSON)
- `docs/reference/unifi-networks.json` - Network configs (JSON)
- `docs/reference/network-topology.md` - Basic topology overview
- `docs/reference/unifi-usg-query-guide.md` - Query commands reference

## Query Commands

### SSH to USG
```bash
sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 'vbash -ic "show interfaces"'
```

### UniFi Controller API
```bash
# Login
curl -k -c cookie.txt -X POST https://192.168.1.7:8443/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"cuiv","password":"$Q2bdANgzviarx23YbHBMqX6"}'

# Get devices
curl -k -b cookie.txt https://192.168.1.7:8443/api/s/default/stat/device | jq .
```

## Next Steps

1. **Fix WiFi VLAN assignments** (Critical - breaks IoT isolation)
2. **Investigate homelab IPS block** (192.168.1.56)
3. **Add static DHCP for infrastructure devices**
4. **Test IoT isolation after VLAN fix**
5. **Review and clean up unknown devices**
6. **Set up automated config backups**
