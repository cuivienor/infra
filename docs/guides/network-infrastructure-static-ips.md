# Assign Static IPs to Network Infrastructure

**Created:** 2025-11-14  
**Purpose:** Lock down network equipment IPs before restricting DHCP  
**Time:** 30 minutes  
**Risk:** Low (can revert easily)

## Why Do This First

**Current situation:**
- Your switches/APs have DHCP reservations scattered around (.6, .9, .10, .44, .112, .113)
- Some are in ranges you want for DHCP (.6-.49)
- Some are in ranges you want for containers (.44)

**Better approach:**
1. **First:** Move all network infrastructure to a clean range (.2-.20)
2. **Then:** Restrict DHCP to .21-.49
3. **Result:** Clean separation, logical organization

## Recommended Infrastructure IP Assignments

### Network Equipment Range: .2-.20

```
.1      Gateway (USG/Cloud Gateway Max) - Already set
.2      Reserved (future second gateway, VPN endpoint)
.3      Reserved (future)
.4      Reserved (future)
.5      Main Switch (USL16LP) - Move from .6
.6      Living Room AP (UAL6) - Move from .9
.7      Bedroom AP (UAL6) - Move from .10
.8      Lab Switch (USMINI) - Move from .44
.9      Bedroom Switch (USMINI) - Move from .112
.10     Living Room Switch (USMINI) - Move from .113
.11     UniFi Controller (Cloud Key) - Currently .7, keep or move
.12-.20 Reserved for future switches/APs
```

### Why This Range?

- ✅ **Logical:** All network gear together
- ✅ **Sequential:** Easy to remember (.5 = main switch, .6-.7 = APs, .8-.10 = mini switches)
- ✅ **Room to grow:** Can add more switches/APs in .12-.20
- ✅ **Separate from DHCP:** DHCP will start at .21

## Migration Plan

### Phase 1: Update UniFi Devices (15 minutes)

**All UniFi devices can be changed via Controller UI - they'll auto-update.**

#### Step 1: Main Switch (.6 → .5)

**In UniFi Controller:**
1. Clients → Find "Main Switch" (or Devices → Main Switch)
2. Click on it
3. Settings → Config → Network
4. **Use Fixed IP Address:** ✅ (probably already enabled)
5. **Fixed IP Address:** Change from `192.168.1.6` to `192.168.1.5`
6. Click "Apply"
7. Wait 30 seconds - switch will reprovision with new IP
8. Verify: Switch shows as "Connected" with IP 192.168.1.5

#### Step 2: Living Room AP (.9 → .6)

**In UniFi Controller:**
1. Devices → Find "Living Room AP"
2. Click on it
3. Settings → Config → Network
4. **Use Fixed IP Address:** ✅
5. **Fixed IP Address:** Change from `192.168.1.9` to `192.168.1.6`
6. Apply
7. Wait for reprovision

#### Step 3: Bedroom AP (.10 → .7)

Same process:
- Change from `192.168.1.10` to `192.168.1.7`

#### Step 4: Lab Switch (.44 → .8)

Same process:
- Change from `192.168.1.44` to `192.168.1.8`

#### Step 5: Bedroom Switch (.112 → .9)

Same process:
- Change from `192.168.1.112` to `192.168.1.9`

#### Step 6: Living Room Switch (.113 → .10)

Same process:
- Change from `192.168.1.113` to `192.168.1.10`

**✅ Checkpoint:** All UniFi devices now in .5-.10 range

### Phase 2: Non-UniFi Infrastructure (Optional)

#### Proxmox Host (.56 → Keep or Move?)

**Current:** 192.168.1.56 (good, in infrastructure range .50-.79)

**Options:**

**Option A: Keep at .56** (Recommended)
- ✅ Already documented everywhere
- ✅ In safe "infrastructure services" range (.50-.79)
- ✅ No disruption
- ❌ Not sequential with switches/APs

**Option B: Move to .20**
- ✅ Sequential with network gear
- ❌ Major disruption (SSH sessions, container configs, etc.)
- ❌ Need to update DNS, documentation, everything

**Recommendation:** **Keep Proxmox at .56**. It's a server, not network equipment. It's fine where it is.

#### UniFi Controller / Cloud Key (.7 → .11 or keep?)

**Current:** 192.168.1.7

**Options:**

**Option A: Keep at .7** (Easiest)
- ✅ Already there, works
- ✅ Well-known address
- ❌ Conflicts with new Bedroom AP at .7

**Option B: Move to .11**
- ✅ Sequential with other network gear
- ✅ Frees up .7 for AP
- ⚠️ Need to update bookmarks, DNS

**Since Bedroom AP is moving to .7, you MUST move Cloud Key.**

**Recommendation:** Move Cloud Key to `.11`

**How to move Cloud Key:**

**⚠️ Note:** Cloud Key is a physical device, not managed by UniFi Controller (it IS the controller).

**Method 1: Via SSH (Preferred)**
```bash
# SSH to Cloud Key
ssh cuiv@192.168.1.7

# Edit network config (if using netplan)
sudo nano /etc/netplan/50-cloud-init.yaml

# Change address from 192.168.1.7/24 to 192.168.1.11/24
# Save and exit

# Apply
sudo netplan apply

# Verify
ip addr show
# Should show 192.168.1.11

# Reconnect
ssh cuiv@192.168.1.11

# Verify controller still works
# Open browser: https://192.168.1.11:8443
```

**Method 2: Via UI (if Cloud Key has web UI for network settings)**
- Login to Cloud Key system settings (not UniFi Controller)
- Change IP from .7 to .11
- Apply
- Reconnect

**After changing Cloud Key IP:**
- Update browser bookmarks
- Update DNS entries (if you have any pointing to controller)

#### Raspberry Pi (.114 → .53 for DNS Primary)

**Current:** 192.168.1.114

**Per your DNS plan:** Will become .53 (DNS Primary)

**When:** During DNS setup (separate guide already created)

**For now:** Can leave at .114 or move to .53 preemptively

**Recommendation:** Move during DNS setup, not now.

### Phase 3: Verify All Changes (5 minutes)

**Check all devices are reachable:**

```bash
# Network equipment
ping 192.168.1.5   # Main Switch
ping 192.168.1.6   # Living Room AP
ping 192.168.1.7   # Bedroom AP
ping 192.168.1.8   # Lab Switch
ping 192.168.1.9   # Bedroom Switch
ping 192.168.1.10  # Living Room Switch
ping 192.168.1.11  # UniFi Controller (if moved)

# Verify UniFi Controller accessible
curl -k https://192.168.1.11:8443
# Should connect

# Check in UniFi Controller
# Devices tab - all should show "Connected" with new IPs
```

**✅ Checkpoint:** All infrastructure at new IPs and working

### Phase 4: Update Documentation

**Update allocation strategy doc:**

```bash
cd ~/dev/homelab-notes

# Edit allocation doc
vim docs/reference/ip-allocation-strategy.md

# Update infrastructure section:
# .5  → Main Switch (moved from .6)
# .6  → Living Room AP (moved from .9)
# .7  → Bedroom AP (moved from .10)
# .8  → Lab Switch (moved from .44)
# .9  → Bedroom Switch (moved from .112)
# .10 → Living Room Switch (moved from .113)
# .11 → UniFi Controller (moved from .7)

git add docs/reference/ip-allocation-strategy.md
git commit -m "docs: update infrastructure IPs to .2-.20 range"
```

## After Infrastructure IPs Are Set

**NOW you can safely restrict DHCP:**

```bash
# Previously occupied IPs are now free:
# .44 (was Lab Switch, now .8)
# .112 (was Bedroom Switch, now .9)
# .113 (was Living Room Switch, now .10)

# Safe DHCP range:
# .21-.49 (29 addresses for workstations)
# OR
# .21-.99 if you don't need .50-.99 reserved yet
```

**Configure in UniFi Controller:**
- Settings → Networks → Private
- DHCP Range: `192.168.1.21` to `192.168.1.49`
- (Leaves .2-.20 for infrastructure, .50+ for containers/servers)

## Summary: Before and After

### Before (Current State)

```
.1      Gateway
.6      Main Switch (DHCP reservation)
.7      UniFi Controller
.9      Living Room AP (DHCP reservation)
.10     Bedroom AP (DHCP reservation)
.44     Lab Switch (DHCP reservation)
.56     Proxmox Host (DHCP reservation)
.112    Bedroom Switch (DHCP reservation)
.113    Living Room Switch (DHCP reservation)

DHCP: .6-.254 (can assign anywhere, conflicts possible)
```

### After (Proposed)

```
.1      Gateway
.2-.4   Reserved
.5      Main Switch (DHCP reservation)
.6      Living Room AP (DHCP reservation)
.7      Bedroom AP (DHCP reservation)
.8      Lab Switch (DHCP reservation)
.9      Bedroom Switch (DHCP reservation)
.10     Living Room Switch (DHCP reservation)
.11     UniFi Controller (static)
.12-.20 Reserved for future network gear
.21-.49 DHCP range (workstations)
.50-.79 Infrastructure services (Proxmox .56, future DNS .53/.54)
.80-.99 Container services (Jellyfin .85, Samba .82, etc.)
.100+   Future use

DHCP: .21-.49 (clean range, no conflicts)
```

## Alternative: Minimal Changes

**Don't want to renumber everything?**

**Keep current IPs, just organize DHCP around them:**

```
.1-.20   Network infrastructure (current: .5-.11 after moves)
.21-.49  DHCP range
.50-.99  Your containers/servers (Proxmox .56, Jellyfin .85, etc.)
.100+    Future
```

**This still achieves the goal:** DHCP won't conflict with your container IPs.

## Rollback Plan

**If something breaks during infrastructure IP changes:**

1. **UniFi devices:** Change back to old IP via Controller UI
2. **Cloud Key:** SSH in, change netplan back, apply
3. **Everything auto-recovers** - UniFi devices adopt to controller wherever it is

**Recovery time:** 5-10 minutes per device

## Recommended Approach

**Conservative (Recommended for you):**

1. ✅ **Move UniFi devices** (.5-.10) - Easy via UI, auto-provisions
2. ✅ **Move Cloud Key** (.11) - One-time change
3. ❌ **Leave Proxmox** at .56 - Don't mess with hypervisor
4. ✅ **Set DHCP** to .21-.49 - Clean range

**Aggressive (Clean slate):**

1. Move everything to perfect sequential IPs
2. More disruption
3. Prettier documentation

**Your choice!** Conservative gets you 90% of the benefit with 10% of the risk.

## Quick Decision Matrix

| Device | Current | Move To | Difficulty | Do It? |
|--------|---------|---------|------------|--------|
| Main Switch | .6 | .5 | Easy (UI) | ✅ Yes |
| Living Room AP | .9 | .6 | Easy (UI) | ✅ Yes |
| Bedroom AP | .10 | .7 | Easy (UI) | ✅ Yes |
| Lab Switch | .44 | .8 | Easy (UI) | ✅ Yes |
| Bedroom Switch | .112 | .9 | Easy (UI) | ✅ Yes |
| Living Room Switch | .113 | .10 | Easy (UI) | ✅ Yes |
| UniFi Controller | .7 | .11 | Medium (SSH) | ✅ Yes |
| Proxmox Host | .56 | .56 | N/A | ❌ Keep |

## Next Steps

1. **Do Phase 1** (move UniFi devices) - 15 minutes
2. **Do Phase 2** (move Cloud Key) - 5 minutes
3. **Verify** everything works - 5 minutes
4. **Then** follow `usg-dhcp-range-setup.md` to restrict DHCP

---

**Related:**
- [USG DHCP Range Setup](usg-dhcp-range-setup.md) - Do AFTER this
- [IP Allocation Strategy](../reference/ip-allocation-strategy.md) - The plan
- [Network Topology](../reference/network-topology-detailed.md) - Current state

---

**TL;DR:** Move all switches/APs to .5-.10 via UniFi Controller UI (15 min), move Cloud Key to .11 via SSH (5 min), then set DHCP to .21-.49. Clean, organized, no conflicts.
