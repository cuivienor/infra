# Manual Fix: WiFi VLAN Isolation

**Created:** 2025-11-14  
**Status:** Ready to execute  
**Risk Level:** Medium (will cause brief WiFi disconnection)  
**Time Required:** 15-20 minutes

## Problem Summary

Your `Paniland-IoT` and `Paniland-Guest` WiFi networks are currently on the **default VLAN** instead of their designated VLANs (20 and 10). This means:
- ❌ IoT devices can access your Private network (192.168.1.x)
- ❌ Guest devices can access your Private network
- ❌ Your network isolation is completely bypassed

## What We'll Fix

| SSID | Current VLAN | Should Be | Impact |
|------|--------------|-----------|--------|
| Paniland-IoT | Default (Private) | VLAN 20 (IoT) | IoT devices will get 192.168.20.x IPs |
| Paniland-Guest | Default (Private) | VLAN 10 (Guest) | Guest devices will get 192.168.10.x IPs |

## Prerequisites

- ✅ Access to UniFi Controller at https://192.168.1.7:8443
- ✅ Admin credentials (user: cuiv)
- ⚠️ **Schedule during a maintenance window** (WiFi will briefly disconnect)
- ⚠️ **Be on wired connection** during this change (not WiFi!)

## Step-by-Step Instructions

### Phase 1: Backup Current Configuration (5 minutes)

#### 1.1 Login to UniFi Controller
```
URL: https://192.168.1.7:8443
Username: cuiv
Password: $Q2bdANgzviarx23YbHBMqX6
```

#### 1.2 Create Backup
1. Click **Settings** (gear icon, bottom left)
2. Navigate to **System** → **Backup**
3. Click **Download Backup**
4. Save file as: `unifi-backup-before-vlan-fix-20251114.unf`
5. Store somewhere safe (Downloads folder)

**✅ Checkpoint:** You should have a `.unf` backup file downloaded

#### 1.3 Verify Current State
1. Go to **Settings** → **Networks**
2. You should see:
   - **Private** (192.168.1.1/24) - No VLAN
   - **IoT** (192.168.20.1/24) - VLAN 20
   - **Paniland-Guest** (192.168.10.1/24) - VLAN 10

3. Go to **Settings** → **WiFi**
4. For each SSID, click to expand and note current settings:
   - **Paniland-IoT** → Network: ??? (probably "Private" or "Default")
   - **Paniland-Guest** → Network: ??? (probably "Private" or "Default")

**✅ Checkpoint:** Confirmed what networks the SSIDs are currently using

### Phase 2: Fix IoT WiFi VLAN (5 minutes)

#### 2.1 Edit Paniland-IoT SSID
1. Go to **Settings** → **WiFi**
2. Find **Paniland-IoT** in the list
3. Click on it to expand/edit

#### 2.2 Change Network Assignment
1. Look for **Network** dropdown (should be near the top)
2. Current value: Probably shows "Private" or "Default"
3. **Change to:** `IoT`
4. Click **Apply** or **Save**

**⚠️ WARNING:** This will cause devices connected to Paniland-IoT to disconnect and reconnect!

#### 2.3 Verify Access Point Reprovision
1. Watch the top of the screen for provisioning notification
2. You should see: "Provisioning access points..."
3. Wait for: "Access points provisioned successfully"
4. This takes 30-60 seconds

**✅ Checkpoint:** Paniland-IoT now shows "Network: IoT" in WiFi settings

### Phase 3: Fix Guest WiFi VLAN (5 minutes)

#### 3.1 Edit Paniland-Guest SSID
1. Still in **Settings** → **WiFi**
2. Find **Paniland-Guest** in the list
3. Click on it to expand/edit

#### 3.2 Change Network Assignment
1. Look for **Network** dropdown
2. Current value: Probably shows "Private" or "Default"
3. **Change to:** `Paniland-Guest`
4. Click **Apply** or **Save**

**⚠️ WARNING:** Guest network will briefly disconnect!

#### 3.3 Verify Provisioning
1. Wait for access points to reprovision
2. Should take 30-60 seconds

**✅ Checkpoint:** Paniland-Guest now shows "Network: Paniland-Guest" in WiFi settings

### Phase 4: Verification (10 minutes)

#### 4.1 Check WiFi Settings
1. Go to **Settings** → **WiFi**
2. Verify each SSID:
   - **Paniland** → Network: `Private` (192.168.1.1/24)
   - **Paniland-2.4** → Network: `Private` (192.168.1.1/24)
   - **Paniland-IoT** → Network: `IoT` (192.168.20.1/24, VLAN 20) ✅
   - **Paniland-Guest** → Network: `Paniland-Guest` (192.168.10.1/24, VLAN 10) ✅

**✅ Checkpoint:** All SSIDs show correct network assignment

#### 4.2 Test IoT Device Connection

**From your phone or laptop:**

1. Disconnect from current WiFi
2. Connect to **Paniland-IoT**
3. Check IP address:
   - **Expected:** 192.168.20.x (VLAN 20)
   - **If you get:** 192.168.1.x → Fix didn't work, see Troubleshooting

4. Test internet access:
   ```bash
   ping 8.8.8.8
   # Should work ✅
   ```

5. Test Private network isolation:
   ```bash
   ping 192.168.1.1
   # Should FAIL ❌ (timeout or "Destination Host Unreachable")
   ```

**✅ Expected Result:** IoT device can reach internet but NOT Private network

#### 4.3 Test Guest Network (if you have guest device)

1. Connect device to **Paniland-Guest**
2. Check IP address:
   - **Expected:** 192.168.10.x (VLAN 10)

3. Test internet access (should work)
4. Test Private network isolation:
   ```bash
   ping 192.168.1.1
   # Should FAIL ❌
   ```

**✅ Expected Result:** Guest device isolated from Private network

#### 4.4 Verify Existing IoT Devices Reconnect

Check these devices reconnect and get 192.168.20.x IPs:

**Your IoT Devices (from network scan):**
- Levoit Air Purifiers/Humidifiers (x5)
- Nest Cameras (x2)
- Nanit Baby Monitor
- Google TV
- iRobot Vacuum
- Rest Sound Machines (x2)
- Denon AVR (wired, should stay at 192.168.20.25)

**How to check:**
1. Go to **Clients** in UniFi Controller
2. Look for these device names
3. Verify they show:
   - **Network:** IoT
   - **IP:** 192.168.20.x
   - **Status:** Connected

**⚠️ If devices don't reconnect automatically:**
- Power cycle the device (unplug for 10 seconds)
- Or "forget network" and reconnect manually

#### 4.5 Check Firewall Rule is Working

From a device on **Private network** (192.168.1.x):

```bash
# SSH to USG
ssh cuiv@192.168.1.1
# Password: 0bi4amAni

# Check firewall statistics
vbash -ic "show firewall statistics"

# Look for rule 2000 in WAN_IN chain:
# rule 2000: DenyNewTrafficFromIoTtoPrivate
# Check if packet count increases when IoT devices try to reach Private
```

**Note:** The rule might not work correctly (it's in wrong chain), but at least VLAN isolation via routing will work.

## Rollback Procedure

If something goes wrong:

### Option A: Restore Backup (Nuclear Option)
1. Go to **Settings** → **System** → **Backup**
2. Click **Choose File**
3. Select: `unifi-backup-before-vlan-fix-20251114.unf`
4. Click **Restore**
5. Wait 2-3 minutes for controller to restart
6. All settings reverted to before the change

### Option B: Manual Revert (Surgical Option)
1. Go to **Settings** → **WiFi**
2. Edit **Paniland-IoT**
3. Change Network back to: `Private`
4. Save

## Success Criteria

✅ All checks must pass:

- [ ] Paniland-IoT SSID → Network shows "IoT" in settings
- [ ] Paniland-Guest SSID → Network shows "Paniland-Guest" in settings
- [ ] IoT device gets 192.168.20.x IP address
- [ ] IoT device can ping 8.8.8.8 (internet)
- [ ] IoT device CANNOT ping 192.168.1.1 (Private gateway)
- [ ] Guest device gets 192.168.10.x IP address (if tested)
- [ ] All existing IoT devices reconnected successfully
- [ ] No device is "stuck" on old VLAN

## Troubleshooting

### Issue: IoT device still gets 192.168.1.x IP

**Cause:** Device cached old DHCP lease

**Fix:**
1. Disconnect device from WiFi
2. "Forget network" on the device
3. Power cycle the device
4. Reconnect to Paniland-IoT
5. Should now get 192.168.20.x IP

### Issue: Access Points not reprovisioning

**Symptoms:** No "provisioning" notification after changing SSID settings

**Fix:**
1. Go to **Devices**
2. Click on each Access Point (Living Room AP, Bedroom AP)
3. Click **Provision** button (or three-dot menu → Provision)
4. Wait 60 seconds
5. Check if SSID changes took effect

### Issue: IoT device CAN still ping Private network

**This means the firewall rule isn't working (expected with USG 4.4.57)**

**What's happening:**
- Rule 2000 is in WAN_IN chain (wrong place)
- Should be in LAN_IN chain for inter-VLAN blocking

**Options:**
1. **Accept it** - At least devices are on different VLANs (basic segmentation)
2. **Fix manually** - Add firewall rule in correct chain (advanced, not covered here)
3. **Wait for hardware upgrade** - Cloud Gateway Max will handle this correctly via Terraform

**To fix manually (advanced):**
```bash
# SSH to USG
ssh cuiv@192.168.1.1

# Add rule to LAN_IN chain
configure
set firewall name LAN_IN rule 2000 action drop
set firewall name LAN_IN rule 2000 description "Block IoT to Private"
set firewall name LAN_IN rule 2000 source address 192.168.20.0/24
set firewall name LAN_IN rule 2000 destination address 192.168.1.0/24
set firewall name LAN_IN rule 2000 state new enable
commit
save
exit
```

**⚠️ WARNING:** This change will be LOST on next USG reprovision from Controller!

### Issue: Can't login to UniFi Controller

**Fix:**
1. Check you're on wired connection (192.168.1.x)
2. Try incognito/private browser window
3. Clear browser cache/cookies
4. Try different browser

## Post-Fix Documentation

After successful fix, update your documentation:

```bash
cd ~/dev/homelab-notes

# Update network topology doc
vim docs/reference/network-topology-detailed.md

# Find the "Wireless Networks (SSIDs)" section
# Change:
#   ⚠️ Paniland-IoT | WPA-PSK | Default (should be VLAN 20!) | IoT | Active ⚠️
# To:
#   ✅ Paniland-IoT | WPA-PSK | VLAN 20 | IoT | Active ✅

# Commit the fix
git add docs/reference/network-topology-detailed.md
git commit -m "docs: update network topology after fixing VLAN isolation

- Paniland-IoT now correctly on VLAN 20
- Paniland-Guest now correctly on VLAN 10
- IoT devices isolated from Private network
- Fixed manually via UniFi Controller UI on 2025-11-14"

git push
```

## Timeline

**Total time:** ~20 minutes

- Backup: 5 min
- Fix IoT SSID: 5 min
- Fix Guest SSID: 5 min
- Verification: 10 min

**Best time to do this:**
- Evening when fewer people home
- NOT during important video calls
- Have wired connection available

## Questions Before You Start?

Before you begin, make sure you understand:

1. ✅ This will cause WiFi to briefly disconnect
2. ✅ You should be on a wired connection during this
3. ✅ You have the backup file downloaded
4. ✅ You know how to rollback if needed
5. ✅ You've scheduled this during a good time

## Next Steps After Fix

Once VLAN isolation is working:

1. **Test for a few days** - Make sure all IoT devices work correctly
2. **Document any issues** - Some IoT devices might need special config
3. **Plan hardware upgrade** - Cloud Gateway Max ($199) for full IaC
4. **Consider additional VLANs** - Separate Management, Servers, Clients

## Related Documents

- `docs/reference/network-topology-detailed.md` - Current network state
- `docs/plans/network-iac-implementation-plan.md` - Future IaC strategy
- `docs/reference/unifi-hardware-versions.md` - Hardware compatibility

---

**Ready to proceed?** Follow the steps above carefully, one section at a time.

**Need help?** Review the Troubleshooting section or restore the backup.
