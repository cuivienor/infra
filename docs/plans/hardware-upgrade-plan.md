# Network Hardware Upgrade Plan

**Created:** 2025-11-14  
**Status:** Planning  
**Budget:** ~$400-500  
**Timeline:** Order when ready, implement over 1-2 weekends

## Current Hardware Pain Points

### 🔴 Critical Issues
1. **USG (UGW3)** - End of Life (last update Jan 2023)
   - Security risk (no more patches)
   - Limited IaC support (config.gateway.json workarounds)
   - Only 1 Gbps WAN (your ISP might upgrade)

2. **Cloud Key Gen1** - Resource constrained
   - Slow API responses
   - Limited RAM for Terraform operations
   - Also aging hardware

3. **UniFi Mini Switches (x3)** - Gen1, firmware 2.1.6 (2016-era)
   - Limited API support
   - Missing modern VLAN features
   - Inconsistent behavior with Terraform

### ✅ Keep (Already Good)
- **Main Switch** (USL16LP) - Modern, PoE, fully supported
- **Access Points** (U6-Lite x2) - WiFi 6, actively updated

## Recommended Upgrade Path

### Option A: Full Upgrade (Recommended)

**Total Cost:** ~$450

| Item | Model | Price | Priority | Notes |
|------|-------|-------|----------|-------|
| Gateway + Controller | **Cloud Gateway Max** (UCG-Max-NS) | $199 | Critical | Replaces USG + Cloud Key |
| Small Switches (x3) | **USW-Flex-Mini** | $29 x 3 = $87 | High | Modern, 5-port, PoE passthrough |
| OR Alternative | **USW-Lite-8-PoE** | $109 | High | Replace all 3 minis with 1 switch |

**Benefits:**
- ✅ Modern UniFi OS (full Terraform support)
- ✅ 2.5G WAN port (future-proof)
- ✅ No more config.gateway.json complexity
- ✅ Built-in controller (retire Cloud Key)
- ✅ Full IaC coverage (95%+)
- ✅ Active security updates
- ✅ Better performance

### Option B: Gateway Only (Minimum Viable)

**Total Cost:** ~$199

| Item | Model | Price | Priority |
|------|-------|-------|----------|
| Gateway + Controller | **Cloud Gateway Max** (UCG-Max-NS) | $199 | Critical |

**Benefits:**
- ✅ Fixes USG security risk
- ✅ Modern controller (built-in)
- ✅ 80% IaC coverage (vs 60% with USG)
- ⚠️ Still have old mini switches (limited features)

**Keep for now:**
- Cloud Key Gen1 (as backup controller? Or sell)
- UniFi Mini switches (work, but limited)

### Option C: Ultra-Budget (If money tight)

**Total Cost:** ~$129

| Item | Model | Price | Notes |
|------|-------|-------|-------|
| Gateway only | **UXG-Lite** | $129 | No built-in controller, needs Cloud Key |

**Not recommended because:**
- ❌ Still need Cloud Key Gen1 (resource constrained)
- ❌ Only saves $70 vs Cloud Gateway Max
- ❌ Worse long-term investment

## Detailed: Cloud Gateway Max (UCG-Max-NS)

### Specs
- **WAN:** 1x 2.5 GbE port
- **LAN:** 1x 2.5 GbE port (connect to Main Switch)
- **Throughput:** 2.3 Gbps with IDS/IPS enabled
- **Controller:** Built-in UniFi OS (no separate Cloud Key needed!)
- **Capacity:** 30+ UniFi devices, 300+ clients
- **Storage:** Optional NVR storage (if you add cameras later)
- **Price:** $199

### IaC Compatibility
- ✅ Full Terraform support (UniFi OS-based)
- ✅ Modern API endpoints
- ✅ No config.gateway.json needed for 95% of configs
- ✅ Active development, regular updates
- ✅ Works with `paultyng/unifi` Terraform provider

### What You Gain vs USG
| Feature | USG 4.4.57 | Cloud Gateway Max |
|---------|------------|-------------------|
| IaC Support | ~60% (config.gateway.json workarounds) | ~95% (native Terraform) |
| Security Updates | ❌ EOL (Jan 2023) | ✅ Active |
| WAN Speed | 1 Gbps | 2.5 Gbps |
| IDS/IPS Speed | ~250 Mbps | 2.3 Gbps |
| Built-in Controller | ❌ (need Cloud Key) | ✅ Yes |
| Terraform Provider | ⚠️ Limited | ✅ Full |
| Config Management | config.gateway.json | Native API |

## Detailed: Switch Options

### Option 1: USW-Flex-Mini (x3) - $87 total

**Per switch:**
- 5 ports (1 PoE in, 4 out)
- PoE passthrough (powers itself from PoE)
- Modern firmware
- Full Terraform support
- Gigabit

**Replacement plan:**
- Bedroom Switch (USMINI) → USW-Flex-Mini
- Lab Switch (USMINI) → USW-Flex-Mini
- Living Room Switch (USMINI) → USW-Flex-Mini

**Pros:**
- ✅ Direct 1:1 replacement
- ✅ No rewiring needed
- ✅ PoE passthrough (powered from Main Switch)
- ✅ Modern, supported

**Cons:**
- ⚠️ Still 3 separate switches to manage

### Option 2: USW-Lite-8-PoE - $109

**Specs:**
- 8 ports total
- 4x PoE+ ports (60W total budget)
- Rack/wall mountable
- Modern firmware
- Full Terraform support

**Replacement plan:**
- Replace ALL 3 mini switches with 1 central switch
- Requires running longer cables from central location

**Pros:**
- ✅ Simpler topology (1 switch instead of 3)
- ✅ More PoE budget
- ✅ Easier to manage
- ✅ Saves 2 switch licenses (if that matters)

**Cons:**
- ⚠️ Need to run longer Ethernet cables
- ⚠️ Might not have enough ports if rooms are far apart

**Verdict:** Only choose this if you can centralize the switch location

### Recommendation: Go with Flex-Mini (x3)
Unless you're willing to rewire, stick with 3x Flex-Mini for direct replacement.

## Migration Plan

### Phase 1: Order Hardware (Week 0)

**Shopping list:**
```
[ ] Cloud Gateway Max (UCG-Max-NS) - $199
[ ] USW-Flex-Mini x3 - $87
[ ] (Optional) Extra Ethernet cables if needed
Total: ~$286 + tax
```

**Where to buy:**
- ui.com store (official)
- Amazon (if in stock, check seller is legit)
- B&H Photo (often has stock)

### Phase 2: Pre-Migration Prep (Week 1)

**Before touching hardware:**

1. **Backup everything**
   ```bash
   # UniFi Controller backup
   # Settings → System → Backup → Download

   # USG config backup
   sshpass -p '0bi4amAni' ssh cuiv@192.168.1.1 \
     'vbash -ic "show configuration commands"' \
     > backups/usg-config-$(date +%Y%m%d).txt

   # Document current state
   cd ~/dev/homelab-notes
   git add -A
   git commit -m "docs: pre-upgrade network state snapshot"
   ```

2. **Document current setup**
   - All static IPs (you have this in docs/)
   - WiFi passwords
   - Firewall rules
   - Port forwarding (none currently)

3. **Test restore** (optional but recommended)
   - Restore backup on current controller
   - Verify everything still works
   - Confirms backup is valid

4. **Schedule maintenance window**
   - 2-4 hours with no critical internet needs
   - Weekend morning ideal
   - Have phone hotspot as backup

### Phase 3: Migrate to Cloud Gateway Max (Weekend 1)

**Prerequisites:**
- ✅ Backup complete
- ✅ Maintenance window scheduled
- ✅ Wired connection to laptop
- ✅ Phone with LTE (backup internet)
- ✅ USG and Cloud Gateway Max both powered on

**Migration steps (2-3 hours):**

#### 3.1 Set up Cloud Gateway Max (30 min)

1. **Unbox and power** Cloud Gateway Max
2. **Connect temporarily in parallel**:
   ```
   [Modem] ----+---- [USG] ---- [Main Switch] (production)
               |
               +---- [Cloud Gateway Max] ---- [Your laptop]
   ```

3. **Initial setup**:
   - Browse to device IP (check DHCP from modem)
   - Or use UniFi app to discover
   - Create local admin account (NOT Ubiquiti cloud account)
   - **Username:** cuiv
   - **Password:** (new, strong password - store in password manager)

4. **Adopt Main Switch to new controller** (test):
   - SSH to Main Switch: `ssh ubnt@192.168.1.6`
   - Set inform URL: `set-inform http://<cloud-gateway-ip>:8080/inform`
   - Watch it adopt to Cloud Gateway Max

#### 3.2 Restore Configuration (30 min)

1. **Upload backup** to Cloud Gateway Max:
   - Settings → System → Backup
   - Upload the `.unf` file from old controller
   - Restore

2. **Verify networks created**:
   - Private (192.168.1.1/24)
   - IoT (192.168.20.1/24, VLAN 20)
   - Guest (192.168.10.1/24, VLAN 10)

3. **Verify wireless networks**:
   - All 4 SSIDs present
   - Passwords correct
   - VLANs assigned correctly

#### 3.3 Cutover (30 min)

**⚠️ POINT OF NO RETURN**

1. **Disconnect USG from modem**
2. **Connect Cloud Gateway Max to modem**:
   ```
   [Modem] ---- [Cloud Gateway Max WAN port]

   [Cloud Gateway Max LAN port] ---- [Main Switch Port ???]
   ```

3. **Wait for WAN to come up**:
   - Cloud Gateway Max should get WAN IP from ISP
   - Check: Dashboard → Internet shows "Connected"

4. **Test internet from wired device**:
   ```bash
   ping 8.8.8.8
   ping google.com
   ```

5. **Adopt all devices**:
   - Go to Devices tab
   - Main Switch, APs, other switches should show "Pending adoption"
   - Click "Adopt" for each
   - Wait for provisioning (5-10 min)

#### 3.4 Verification (30 min)

**Test checklist:**

- [ ] Internet working from wired device
- [ ] All switches adopted and showing "Connected"
- [ ] All APs adopted and showing "Connected"
- [ ] WiFi SSIDs broadcasting
- [ ] Can connect to each SSID
- [ ] Devices get correct IPs:
  - Paniland → 192.168.1.x
  - Paniland-IoT → 192.168.20.x
  - Paniland-Guest → 192.168.10.x
- [ ] IoT devices cannot ping Private network
- [ ] Homelab server (192.168.1.56) accessible
- [ ] Pi-hole (192.168.1.107) working

**If everything works:**
- ✅ **Power off old USG** (keep as backup for now)
- ✅ **Power off old Cloud Key** (keep as backup)

**If problems:**
- Revert: Disconnect Cloud Gateway Max, reconnect USG
- Troubleshoot issue
- Try again later

### Phase 4: Replace Mini Switches (Weekend 2, optional)

**Only do this if Phase 3 went smoothly**

1. **Replace one at a time**:
   - Start with least critical (Bedroom Switch)
   - Power off old USMINI
   - Connect USW-Flex-Mini in same location
   - Power via PoE from Main Switch
   - Adopt in Cloud Gateway Max controller
   - Verify devices reconnect
   - Move to next switch

2. **Configuration**:
   - Port profiles will need to be reassigned
   - Check each port assignment in controller

3. **Testing**:
   - Verify all devices on that switch working
   - Check VLANs correctly assigned

**Timeline:** 30 min per switch = 1.5 hours total

### Phase 5: Terraform Migration (Week 2+)

Once hardware is stable:

1. **Follow IaC implementation plan**
   - `docs/plans/network-iac-implementation-plan.md`
   - Start with Phase 1 (Terraform testing)
   - Import existing config
   - Manage going forward via code

2. **No more manual changes**
   - All changes via Terraform
   - Commit to Git
   - Review via PR

## Rollback Plan

### If Cloud Gateway Max fails during migration:

1. **Disconnect Cloud Gateway Max**
2. **Reconnect old USG to modem**
3. **Power on old Cloud Key**
4. **Wait 5 min for controller to start**
5. **Devices should reconnect to old controller**
6. **Force provision if needed**:
   - SSH to each device
   - `set-inform http://192.168.1.7:8080/inform`

**Recovery time:** ~15 minutes

### If switches fail:

1. **Reconnect old USMINI**
2. **Power cycle to reset**
3. **Adopt back to controller**

**Recovery time:** ~5 minutes per switch

## Cost Breakdown

### Recommended Package (Option A)
```
Cloud Gateway Max:      $199
USW-Flex-Mini x3:       $ 87
---------------------------------
Subtotal:               $286
Tax (est 8%):           $ 23
---------------------------------
Total:                  ~$309
```

### What to do with old hardware:

**Sell:**
- USG-3P: ~$50-80 (eBay, /r/homelabsales)
- Cloud Key Gen1: ~$30-50
- UniFi Mini x3: ~$15 each = $45

**Recovery:** ~$125-175

**Net cost:** ~$134-184 for entire upgrade!

**Keep as backup:**
- USG (emergency backup gateway)
- Cloud Key (can run standalone controller for troubleshooting)

## Questions to Answer Before Ordering

1. **Is your ISP faster than 1 Gbps?**
   - No → 2.5G WAN is future-proofing
   - Yes → 2.5G WAN is immediately useful

2. **Can you be offline for 2-4 hours?**
   - Yes → Proceed with migration
   - No → Schedule better time

3. **Do you want to sell old hardware?**
   - Yes → Clean up, take photos, list before upgrade
   - No → Keep as backup/lab equipment

4. **Budget approved?**
   - Yes → Order now
   - No → Save up, fix VLAN issue manually for now

## Timeline Summary

```
Week 0: Order hardware
Week 1: Prep (backups, documentation, testing)
Weekend 1 (Day): Migrate to Cloud Gateway Max (3-4 hours)
Weekend 1 (Evening): Test everything, verify stability
Week 2: Monitor for issues
Weekend 2 (Optional): Replace mini switches (2 hours)
Week 3+: Terraform migration (ongoing)
```

**Total hands-on time:** 5-6 hours spread across 2 weekends

## Success Criteria

After upgrade complete:

- ✅ Internet working reliably
- ✅ All devices adopted to new controller
- ✅ WiFi VLANs working correctly
- ✅ IoT isolation working
- ✅ No performance degradation
- ✅ Can manage via Terraform (80%+ coverage)
- ✅ Old hardware powered off (or sold)

## Next Steps

1. **Decide:** Option A (full upgrade) or Option B (gateway only)?
2. **Budget:** Get approval/save money
3. **Schedule:** Pick migration weekend
4. **Order:** Buy from ui.com or Amazon
5. **Prep:** While waiting for delivery, do backups
6. **Execute:** Follow Phase 3 migration plan
7. **IaC:** Once stable, implement Terraform

## Related Documents

- `docs/guides/fix-vlan-isolation-manual.md` - Manual VLAN fix (do NOW)
- `docs/plans/network-iac-implementation-plan.md` - Terraform migration (do AFTER hardware upgrade)
- `docs/reference/unifi-hardware-versions.md` - Current hardware details
- `docs/reference/network-topology-detailed.md` - Current network state

---

**Ready to upgrade?** Start with fixing the VLAN isolation manually, then plan the hardware upgrade.
