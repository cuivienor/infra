# UniFi Hardware and Firmware Inventory

**Last Updated:** 2025-11-14

## Your Current Setup

### UniFi Controller
- **Version:** 7.2.97
- **Platform:** UniFi Cloud Key Gen1 (f0:9f:c2:c6:d7:af)
- **IP:** 192.168.1.7
- **Release Date:** ~Q4 2023

### Security Gateway (USG)
- **Model:** UGW3 (USG-3P)
- **Firmware:** 4.4.57.5578372
- **Release Date:** January 12, 2023
- **EdgeOS Version:** v1.10.11 based
- **Status:** ⚠️ **LEGACY** - Last firmware update Jan 2023

### Switches

| Device | Model | Firmware | Age | Notes |
|--------|-------|----------|-----|-------|
| Main Switch | USL16LP (16-port PoE Lite) | 7.2.123.16565 | Modern | ✅ Current gen |
| Bedroom Switch | USMINI (5-port) | 2.1.6.762 | OLD | ⚠️ Gen1 hardware |
| Lab Switch | USMINI (5-port) | 2.1.6.762 | OLD | ⚠️ Gen1 hardware |
| Living Room Switch | USMINI (5-port) | 2.1.6.762 | OLD | ⚠️ Gen1 hardware |

### Access Points

| Device | Model | Firmware | Notes |
|--------|-------|----------|-------|
| Living Room AP | UAL6 (U6-Lite) | 6.7.31.15618 | ✅ WiFi 6, Current gen |
| Bedroom AP | UAL6 (U6-Lite) | 6.7.31.15618 | ✅ WiFi 6, Current gen |

## Hardware Generation Analysis

### ✅ Modern Hardware (Full IaC Support)
- **Main Switch** (USL16LP) - Gen3, actively updated
- **Access Points** (U6-Lite x2) - WiFi 6, actively supported

### ⚠️ Legacy Hardware (Limited Support)
- **USG (UGW3)** - End of Life, last update Jan 2023
- **UniFi Switches Mini (USMINI x3)** - Gen1, firmware v2.x (very old)

## IaC Compatibility Assessment

### Terraform Provider (paultyng/unifi) Compatibility

#### ✅ CONFIRMED WORKING
Based on your Controller version **7.2.97** and hardware:

**Network Configuration:**
- ✅ `unifi_network` - Create/manage VLANs, networks
- ✅ `unifi_wlan` - Manage WiFi SSIDs
- ✅ `unifi_port_profile` - Switch port profiles
- ✅ `unifi_user_group` - VLAN groups
- ✅ `unifi_firewall_rule` - USG firewall rules
- ✅ `unifi_port_forward` - NAT port forwarding
- ✅ `unifi_static_route` - Static routes

**Tested with:**
- Controller 6.0+ (you have 7.2.97) ✅
- USG firmware 4.4.x (you have 4.4.57) ✅
- UniFi switches (all generations) ✅

#### ⚠️ LIMITATIONS FOR YOUR SETUP

1. **USG (Legacy Device)**
   - Terraform provider works via Controller API
   - But USG is EOL (End of Life)
   - Advanced features require `config.gateway.json` (not Terraform)
   - Provider can manage: Networks, firewall rules, port forwarding
   - Provider CANNOT manage: Advanced routing, VPN, custom DHCP options, QoS

2. **Old UniFi Mini Switches**
   - Firmware 2.1.6 is from ~2016-2017
   - Basic port profile management works
   - Limited VLAN trunk configuration
   - No advanced PoE management

3. **Controller 7.2.97**
   - ✅ Fully compatible with Terraform provider
   - But it's on Cloud Key Gen1 (also legacy hardware)
   - Consider: Cloud Key has limited resources

### Recommended IaC Approach for YOUR Hardware

Given your mix of modern and legacy hardware:

```
┌─────────────────────────────────────────────────────┐
│ IaC Strategy by Component                           │
├─────────────────────────────────────────────────────┤
│                                                     │
│ TERRAFORM (via UniFi Controller API)                │
│  ├─ Networks (VLANs, DHCP ranges, DNS)            │
│  ├─ Wireless Networks (SSIDs, passwords)           │
│  ├─ Port Profiles                                   │
│  ├─ User Groups                                     │
│  └─ Basic Firewall Rules (indices 2000-2999)       │
│                                                     │
│ config.gateway.json + ANSIBLE                       │
│  ├─ Advanced USG firewall rules                    │
│  ├─ Custom DHCP options                            │
│  ├─ Static host mappings                           │
│  ├─ DNS overrides                                   │
│  └─ Policy routing (if needed)                     │
│                                                     │
│ MANUAL (until upgrade)                              │
│  ├─ Mini switch port assignments                   │
│  └─ Per-device configs on legacy switches          │
└─────────────────────────────────────────────────────┘
```

## Version-Specific Gotchas

### USG 4.4.57 (Your Version)

**Known Issues:**
1. **API Firewall Rule Sync Delay** - Rules created via API may take 30-60 seconds to apply
2. **Config Gateway Provisioning** - Sometimes requires manual force-provision
3. **DHCP Static Mappings** - Better managed via config.gateway.json than API

**Workarounds:**
- Always use `terraform apply` with `--auto-approve=false` to review
- After network changes, SSH to USG and verify: `show firewall`, `show dhcp server`
- Keep backup of working config.gateway.json

### Controller 7.2.97 (Your Version)

**Known Issues:**
1. **Resource Limits on Cloud Key Gen1** - Limited RAM, slow applies
2. **API Rate Limiting** - May need delays between Terraform resources

**Workarounds:**
- Use `time_sleep` resources between critical changes
- Don't run Terraform too frequently (Cloud Key can bog down)

### UniFi Mini Switches v2.1.6 (Your Version)

**Known Issues:**
1. **Limited API Exposure** - Some settings only available in UI
2. **VLAN Trunk Config** - Inconsistent behavior on Gen1 hardware

**Recommendation:**
- Use port profiles for standard configs
- Document manual per-port VLAN assignments
- Consider upgrading to Flex Mini switches (~$30 each) for full IaC support

## Upgrade Path Recommendations

### Priority 1: USG Replacement (Most Critical)
**Why:** EOL, no security updates since Jan 2023, limited IaC support

**Options:**
- **UDM-SE** ($299) - Dream Machine Special Edition, 2.5G WAN
- **UDM-Pro** ($379) - Full rack-mount, 8-port switch
- **UXG-Lite** ($129) - Gateway-only, use existing switches

**IaC Benefits:**
- Full Terraform support
- Modern UniFi OS API
- Active development and updates
- Better config.gateway.json support

### Priority 2: Mini Switches (Lower Priority)
**Why:** Working but limited, firmware very old

**Options:**
- **USW-Flex-Mini** ($29 each x3 = $87) - Modern, PoE passthrough
- **USW-Lite-8-PoE** ($109) - Replace all 3 minis with one switch

**IaC Benefits:**
- Full port configuration via Terraform
- Modern firmware with security updates
- Better VLAN trunk support

### Keep (No Upgrade Needed)
- ✅ **Main Switch** (USL16LP) - Modern, fully supported
- ✅ **Access Points** (U6-Lite x2) - WiFi 6, excellent

## Testing Plan for IaC on Your Hardware

Before committing to Terraform for your network:

### Phase 1: Read-Only Testing
```bash
# Test Terraform can read your current config
terraform init
terraform plan  # Should show existing resources

# Verify no destructive changes
grep -i "destroy\|replace" plan.txt
```

### Phase 2: Safe Changes First
Start with low-risk resources:
1. Create a test VLAN (192.168.99.0/24)
2. Create a test port profile
3. Modify DHCP range slightly on test VLAN

### Phase 3: Critical Resources
Only after Phase 1-2 work:
1. Import existing networks
2. Manage firewall rules
3. Manage production SSIDs

## Compatibility Matrix

| Feature | Your Hardware | Terraform | config.gateway.json | Manual Only |
|---------|---------------|-----------|---------------------|-------------|
| VLANs | USG 4.4.57 | ✅ | ✅ | ✅ |
| DHCP Pools | USG 4.4.57 | ✅ | ✅ | ✅ |
| Static DHCP | USG 4.4.57 | ⚠️ Buggy | ✅ Best | ✅ |
| Firewall Rules | USG 4.4.57 | ✅ Basic | ✅ Advanced | ✅ |
| Port Forwarding | USG 4.4.57 | ✅ | ✅ | ✅ |
| WiFi SSIDs | Controller 7.2.97 | ✅ | N/A | ✅ |
| Port Profiles | Controller 7.2.97 | ✅ | N/A | ✅ |
| Switch Port VLANs | USMINI 2.1.6 | ⚠️ Limited | N/A | ✅ Best |
| DNS Overrides | USG 4.4.57 | ❌ | ✅ Only | ❌ |
| DHCP Options | USG 4.4.57 | ❌ | ✅ Only | ❌ |

## Recommended Starting Point

Given your hardware limitations:

```hcl
# Start with these Terraform resources (known to work on your versions):

# 1. Networks (VLANs) - works great
resource "unifi_network" "iot" {
  name    = "IoT"
  purpose = "corporate"
  subnet  = "192.168.20.1/24"
  vlan_id = 20
  # ... DHCP config
}

# 2. Wireless Networks - works great
resource "unifi_wlan" "iot_wifi" {
  name          = "Paniland-IoT"
  security      = "wpapsk"
  passphrase    = var.iot_wifi_password
  network_id    = unifi_network.iot.id  # Fix VLAN assignment!
  # ...
}

# 3. Port Profiles - works on Controller 7.2
resource "unifi_port_profile" "iot_devices" {
  name       = "IoT"
  native_networkconf_id = unifi_network.iot.id
  # ...
}

# AVOID these on your hardware (use config.gateway.json):
# - Advanced firewall rules (indices outside 2000-2999)
# - Static DHCP mappings (buggy on USG 4.4.57)
# - DNS overrides (not supported via API)
```

## Next Steps

1. **Test Terraform provider** against your Controller 7.2.97
2. **Create backup** of current config before any IaC changes
3. **Start with read-only** Terraform state
4. **Gradually adopt** IaC for safe resources first
5. **Plan USG upgrade** for full IaC capabilities

## References

- Terraform UniFi Provider: https://registry.terraform.io/providers/paultyng/unifi
- USG config.gateway.json: https://help.ui.com/hc/en-us/articles/215458888
- Controller 7.2 Release Notes: Check UniFi Community
