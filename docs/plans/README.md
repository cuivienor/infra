# Plans Directory

Active planning documents for homelab infrastructure improvements.

## Current Plans

### 🔴 Critical - Do Now

1. **[Fix VLAN Isolation (Manual)](../guides/fix-vlan-isolation-manual.md)**
   - **Issue:** IoT and Guest WiFi on wrong VLANs
   - **Impact:** No network isolation, security risk
   - **Time:** 20 minutes
   - **Risk:** Medium (brief WiFi disconnect)
   - **Status:** Ready to execute

### 🟡 High Priority - Plan & Budget

2. **[Hardware Upgrade Plan](hardware-upgrade-plan.md)**
   - **Replace:** USG + Cloud Key + 3x Mini Switches
   - **With:** Cloud Gateway Max + 3x Flex-Mini
   - **Cost:** ~$310 (net ~$135 after selling old hardware)
   - **Benefits:** Full IaC support, security updates, 2.5G WAN
   - **Timeline:** 2 weekends
   - **Status:** Planning, ready to order when budgeted

3. **[Network IaC Implementation](network-iac-implementation-plan.md)**
   - **Goal:** Manage network via Terraform + Ansible
   - **Prerequisites:** Fix VLAN isolation first
   - **Optimal:** Do after hardware upgrade
   - **Coverage:** 60% now, 95% after hardware upgrade
   - **Timeline:** 4 weeks (phased approach)
   - **Status:** Documented, waiting for hardware

### 🟢 Future Ideas

4. **[Storage IaC Plan](storage-iac-plan.md)**
   - Terraform for Proxmox storage management
   - Status: Planning

5. **[Additional Network Ideas](ideas/)**
   - Network DNS architecture
   - Arch Linux container migration
   - Disk upgrade simulation
   - See `ideas/` subdirectory

## Recommended Execution Order

```
1. Fix VLAN Isolation (Manual)     [NOW - 20 minutes]
   └─> Test for a few days

2. Order Hardware                   [When budgeted - $310]
   └─> While waiting: backup configs

3. Hardware Upgrade                 [Weekend 1 - 4 hours]
   └─> Migrate to Cloud Gateway Max
   └─> Replace switches (Weekend 2 - 2 hours)
   └─> Test for 1 week

4. Network IaC Implementation       [Ongoing - 4 weeks]
   └─> Phase 1: Terraform testing
   └─> Phase 2: Import existing config
   └─> Phase 3: Manage via code
   └─> Phase 4: Documentation
```

## Quick Reference

| Plan | Priority | Time | Cost | Status |
|------|----------|------|------|--------|
| Fix VLAN Isolation | 🔴 Critical | 20 min | $0 | Ready |
| Hardware Upgrade | 🟡 High | 2 weekends | ~$135 net | Planning |
| Network IaC | 🟡 High | 4 weeks | $0 | Documented |
| Storage IaC | 🟢 Future | TBD | $0 | Planning |

## Notes

- **VLAN Fix:** Can be done independently, don't wait for hardware
- **Hardware Upgrade:** Good investment for IaC capabilities
- **IaC:** Works better after hardware upgrade, but can start now with limitations

## Related Documentation

- [Current Network State](../reference/network-topology-detailed.md)
- [Hardware Versions](../reference/unifi-hardware-versions.md)
