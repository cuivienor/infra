# WSL2 SSH Connectivity Issue

## Problem
SSH connections from WSL2 to local network hosts (192.168.1.x) hang and timeout, while the same connections work fine from Windows host.

## Symptoms
- `ssh root@192.168.1.56` hangs indefinitely
- Connection stuck in SYN-SENT state
- Ping works fine to the target host
- Raw TCP connections succeed (bash `/dev/tcp` test works)
- Windows SSH on same machine works perfectly
- Proxmox web interface accessible

## Root Cause
SSH's default IPQoS (IP Quality of Service) setting conflicts with WSL2's network stack and NAT implementation. WSL2 uses a lower MTU (1280) and the QoS packet tagging causes issues with packet routing through the WSL2 virtual NAT gateway (172.17.112.1).

## Diagnosis Steps Taken
1. Checked for stuck SSH processes - found PID in SYN-SENT state
2. Verified network connectivity with ping - successful
3. Tested raw TCP connection with bash - successful
4. Tested from Windows host - successful
5. Tried various SSH options until IPQoS setting identified as culprit

## Solution

### Immediate Workaround
Use SSH with IPQoS disabled:
```bash
ssh -o IPQoS=none root@192.168.1.56
```

Or with throughput QoS:
```bash
ssh -o IPQoS=throughput root@192.168.1.56
```

### Permanent Fix
Create or edit `~/.ssh/config` and add:

```
# Fix for WSL2 SSH connectivity issues
Host 192.168.1.*
    IPQoS none
```

Or apply to all hosts:
```
Host *
    IPQoS none
```

### Alternative: WSL2 Mirrored Networking
Edit/create `C:\Users\<USERNAME>\.wslconfig` on Windows:
```ini
[wsl2]
networkingMode=mirrored
```

Then restart WSL:
```powershell
wsl --shutdown
```

This uses Windows' native networking instead of NAT (requires Windows 11 22H2+ or Windows 10 with recent updates).

## Environment Details
- **OS**: WSL2 on Windows (Arch Linux)
- **WSL Kernel**: 6.6.87.2-microsoft-standard-WSL2
- **SSH Version**: OpenSSH_10.2p1
- **WSL2 MTU**: 1280 (eth0)
- **WSL2 Network**: 172.17.127.32/20 via gateway 172.17.112.1
- **Target Network**: 192.168.1.0/24 (local homelab)
- **Date**: 2025-11-09

## References
- This is a known WSL2 issue with certain network configurations
- IPQoS default setting: `af21` (assured forwarding) which sets DSCP bits
- WSL2 NAT may not properly handle DSCP-tagged packets

## TODO
- [ ] Implement permanent fix in ~/.ssh/config
- [ ] Consider testing WSL2 mirrored networking mode
- [ ] Document if other services have similar issues
