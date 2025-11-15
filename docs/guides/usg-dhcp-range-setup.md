# USG DHCP Range Configuration

**Created:** 2025-11-14  
**Purpose:** Configure DHCP to avoid static IP ranges  
**Time:** 15 minutes  
**Method:** UniFi Controller UI

## Problem

Your network has:
- Infrastructure devices that need static IPs (.1-.79)
- Containers with static IPs (.50-.99)
- Clients that need DHCP (workstations, phones, etc.)

**Current DHCP range:** 192.168.1.6 - 192.168.1.254 (will assign anywhere!)

**Risk:** DHCP might assign .85 to someone's laptop, then you can't use it for Jellyfin container.

## Solution: Split DHCP Ranges

Configure DHCP to ONLY assign from safe ranges, leaving gaps for your static allocations.

## Recommended DHCP Configuration

### VLAN 1 (192.168.1.0/24) - Primary Network

```
.1              Gateway (USG/Cloud Gateway Max)
.2-.5           Reserved (future routers, VPN endpoints)
.6-.49          ✅ DHCP RANGE 1 (Workstations, trusted devices)
.50-.99         ❌ RESERVED FOR STATIC (Infrastructure, containers)
.100-.149       ❌ RESERVED FOR STATIC (Application containers)
.150-.199       ❌ RESERVED FOR STATIC (IoT before migration, future use)
.200-.254       ✅ DHCP RANGE 2 (Overflow, temporary devices)
```

**DHCP will assign:**
- First available: .6-.49 (44 addresses for workstations)
- If full, use: .200-.254 (55 addresses for overflow)

**DHCP will NEVER assign:**
- .50-.199 (150 addresses reserved for static)

## Step-by-Step: Configure in UniFi Controller

### Option A: Via UniFi Controller UI (Recommended)

**⚠️ WARNING:** Changing DHCP ranges will NOT disconnect existing clients, but new clients get IPs from new ranges.

1. **Login to UniFi Controller**
   - URL: https://192.168.1.7:8443
   - Username: cuiv
   - Password: $Q2bdANgzviarx23YbHBMqX6

2. **Navigate to Networks**
   - Settings (gear icon) → Networks
   - Click on **"Private"** network

3. **Find DHCP Settings**
   - Scroll to **DHCP** section
   - Currently shows:
     - DHCP Mode: DHCP Server
     - DHCP Range: 192.168.1.6 - 192.168.1.254

4. **Change DHCP Range**
   - **DHCP Range Start:** `192.168.1.6`
   - **DHCP Range Stop:** `192.168.1.49`
   - (This reserves .50-.199 for static allocations)

5. **Add Second DHCP Range (Overflow)**

   **⚠️ Note:** UniFi Controller may not support multiple DHCP ranges in the UI.

   **If you see a "+ Add Range" button:**
   - Click it
   - DHCP Range Start: `192.168.1.200`
   - DHCP Range Stop: `192.168.1.254`

   **If you DON'T see "+ Add Range":**
   - You can only configure one range
   - Choose: `192.168.1.6` - `192.168.1.49` (primary range)
   - This gives 44 DHCP addresses (should be enough)
   - OR choose: `192.168.1.6` - `192.168.1.49` AND `192.168.1.200` - `192.168.1.254` via config.gateway.json (advanced, see below)

6. **Save Changes**
   - Click **"Apply Changes"** or **"Save"**
   - Wait for USG to reprovision (30-60 seconds)

7. **Verify**
   - Check the network settings show new range
   - Existing devices keep their current IPs
   - New devices get IPs from .6-.49 range

**✅ Done!** DHCP will never assign .50-.199

### Option B: Advanced - Multiple DHCP Ranges via config.gateway.json

**Only if you want BOTH ranges (.6-.49 AND .200-.254):**

**On your laptop:**

```bash
# Create config.gateway.json
cat > /tmp/config.gateway.json << 'EOF'
{
  "service": {
    "dhcp-server": {
      "shared-network-name": {
        "net_Private_eth1_192.168.1.0-24": {
          "subnet": {
            "192.168.1.0/24": {
              "start": {
                "192.168.1.6": {
                  "stop": "192.168.1.49"
                },
                "192.168.1.200": {
                  "stop": "192.168.1.254"
                }
              }
            }
          }
        }
      }
    }
  }
}
EOF

# Copy to UniFi Controller (Cloud Key)
sshpass -p '0bi4amAni' scp /tmp/config.gateway.json \
  cuiv@192.168.1.7:/usr/lib/unifi/data/sites/default/config.gateway.json

# Force provision USG
curl -k -b /tmp/unifi-cookie.txt -X POST \
  https://192.168.1.7:8443/api/s/default/cmd/devmgr \
  -H "Content-Type: application/json" \
  -d '{"cmd":"force-provision","mac":"f0:9f:c2:16:bf:17"}'

# Wait 60 seconds
sleep 60

# Verify on USG
sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 \
  'vbash -ic "show dhcp server leases"'
```

**✅ Done!** DHCP will assign from .6-.49 first, then .200-.254 if full.

## Verify Configuration

### Check Current DHCP Leases

**Via UniFi Controller UI:**
- Clients → Active Clients
- Look at "IP Address" column
- All should be in .6-.49 range (or .200+ if using dual range)
- None should be in .50-.199 range

**Via SSH to USG:**
```bash
sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 \
  'vbash -ic "show dhcp server leases"'

# Look at IP addresses assigned
# Should all be .6-.49 (or .200-.254)
# None in .50-.199
```

### Test New DHCP Assignment

**Connect a new device to network:**
- Should get IP between .6-.49
- If .6-.49 is full, should get .200-.254 (if dual range configured)
- Should NEVER get .50-.199

## Static IP Reservations (Optional)

**For UniFi devices, you can use DHCP reservations instead of pure static:**

### Add DHCP Reservation via UI

**When to use:** Network infrastructure (switches, APs) that you want to manage via DHCP but guarantee same IP.

1. **UniFi Controller → Clients**
2. **Find device** (e.g., Main Switch)
3. **Click on device**
4. **Settings → Network**
5. **Use Fixed IP Address:** ✅ Enable
6. **Fixed IP Address:** `192.168.1.6` (or whatever you want)
7. **Save**

**This tells DHCP:** "Always give MAC address XX:XX:XX:XX:XX:XX the IP 192.168.1.6"

**Pros:**
- Managed centrally in UniFi
- Device gets same IP always
- Easy to change later

**Cons:**
- Requires UniFi to be up to work
- More complex than static IP in device config

### Current Recommendations

| Device Type | Method | Reason |
|-------------|--------|--------|
| **UniFi Switches/APs** | DHCP Reservation | Managed by controller anyway |
| **Proxmox Host** | DHCP Reservation | Physical server, easier to manage centrally |
| **Raspberry Pi** | Static on device | Independent of network infrastructure |
| **LXC Containers** | Static in config | Defined in Terraform/Proxmox config |

**Your current DHCP reservations** (keep these):
```
192.168.1.6   → 24:5a:4c:59:77:d7  (Main Switch)
192.168.1.9   → 24:5a:4c:11:47:58  (Living Room AP)
192.168.1.10  → 24:5a:4c:11:47:d4  (Bedroom AP)
192.168.1.44  → 68:d7:9a:31:c8:de  (Lab Switch)
192.168.1.56  → 70:85:c2:a5:c3:c4  (Proxmox Host)
192.168.1.112 → 68:d7:9a:31:c9:19  (Bedroom Switch)
192.168.1.113 → 68:d7:9a:31:c9:26  (Living Room Switch)
```

**All these are in safe ranges** (either .6-.49 or outside DHCP entirely).

## What About Containers?

**Containers don't use DHCP** - they have static IPs configured in Proxmox.

**When you create a container:**
```bash
# In Proxmox UI or Terraform
IP: 192.168.1.85/24  # Static, not from DHCP
Gateway: 192.168.1.1
```

**DHCP doesn't know about this IP** - it's outside the DHCP system.

**The problem:** If DHCP range includes .85, DHCP might give .85 to a laptop, then you have a conflict when you try to use .85 for Jellyfin.

**The solution:** Restrict DHCP to .6-.49 (and optionally .200-.254), so .85 is never assigned by DHCP.

## VLAN 20 (IoT) - Already Configured

**Current DHCP range:** 192.168.20.6 - 192.168.20.254

**This is fine!** IoT devices use DHCP, no static allocations needed.

**Leave as-is.**

## After Cloud Gateway Max Upgrade

**Same configuration applies:**
1. Configure DHCP ranges in UniFi Network settings
2. Set to .6-.49 (and optionally .200-.254)
3. Static allocations in .50-.199 safe from DHCP

**Cloud Gateway Max has same DHCP options as USG.**

## Summary

### Current State (Before Change)
```
DHCP Range: 192.168.1.6 - 192.168.1.254
Risk: DHCP can assign .85 (conflicts with Jellyfin container)
```

### After Configuration (Recommended)
```
DHCP Range: 192.168.1.6 - 192.168.1.49
Static Range: 192.168.1.50 - 192.168.1.199 (safe from DHCP)
Optional Overflow: 192.168.1.200 - 192.168.1.254 (DHCP if .6-.49 full)
```

### IP Allocation at a Glance

```
192.168.1.0/24
├─ .1           Gateway
├─ .2-.5        Reserved
├─ .6-.49       DHCP (44 addresses) ← Change DHCP to THIS
├─ .50-.79      Your infrastructure (DNS, Proxmox, switches via reservation)
├─ .80-.99      Your containers (Jellyfin, Samba, etc.)
├─ .100-.149    Future containers
├─ .150-.199    Reserved/future
└─ .200-.254    DHCP overflow (optional)
```

### How to Do It

**Easiest:** UniFi Controller UI → Networks → Private → DHCP Range → Change to `6` - `49`

**Advanced:** config.gateway.json for dual DHCP ranges

**Time:** 5 minutes via UI, 15 minutes via config.gateway.json

## Quick Commands Reference

**Check current DHCP config:**
```bash
sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 \
  'vbash -ic "show dhcp server statistics"'
```

**Check active leases:**
```bash
sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 \
  'vbash -ic "show dhcp server leases"'
```

**Check what range is configured:**
```bash
sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 \
  'cat /config/config.boot | grep -A5 "dhcp-server"'
```

## Next Steps

1. **Change DHCP range** (UniFi Controller UI or config.gateway.json)
2. **Verify** no new clients get IPs in .50-.199
3. **Document** your static allocations (already done in `ip-allocation-strategy.md`)
4. **Deploy containers** with confidence using .50-.199 range

---

**Related:**
- [IP Allocation Strategy](../reference/ip-allocation-strategy.md) - What IPs to use for what
- [Network Topology](../reference/network-topology-detailed.md) - Current network state
- [Fix VLAN Isolation](fix-vlan-isolation-manual.md) - Critical security fix

---

**TL;DR:** Change DHCP range in UniFi Controller from `.6-.254` to `.6-.49`. Done. Now .50-.199 is safe for your static containers.
