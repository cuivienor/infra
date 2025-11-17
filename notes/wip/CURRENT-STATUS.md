# Current Work Status

**Date**: 2025-11-16  
**Focus**: Infrastructure stabilization and documentation cleanup

> **System specs**: See `docs/reference/current-state.md`

---

## Recent Achievements

**2025-11-16**: Proxmox host automation deployed
- Automated container updates (weekly, skips busy containers)
- Host config backups to mergerfs pool
- Kernel cleanup and FSTRIM automation
- Pre-commit hooks with linting (shellcheck, ansible-lint, yamllint)

**2025-11-15**: Full networking stack operational
- Tailscale subnet routing with redundant routers (Pi4 + Proxmox)
- AdGuard Home DNS with HaGeZi Pro ad blocking
- Caddy reverse proxy with automatic HTTPS
- Friend sharing via Tailscale ACLs

---

## Current Priorities

### 1. Test Production Workflows
- [ ] Jellyfin - verify playback and transcoding
- [ ] Ripper - test disc ripping end-to-end
- [ ] Transcoder - confirm GPU hardware acceleration
- [ ] Analyzer - test FileBot organization
- [ ] Full pipeline: Rip → Transcode → Organize → Serve

### 2. Switch to Production HTTPS Certificates
- Currently using Let's Encrypt staging
- Set `caddy_acme_staging: false` in proxy playbook
- Re-run to get real certificates

---

## Known Issues

**Medium Priority**
- Legacy library migration to `/media/library` incomplete
- Some old docs may reference legacy container numbers

**Low Priority**
- systemd-hostnamed timeouts in containers (normal for LXC)

---

## Infrastructure Status

**8 containers** running (all IaC-managed):
- Media pipeline: backup, samba, ripper, analyzer, transcoder, jellyfin
- Network services: dns, proxy

**Automated maintenance active**:
- Sat 23:00 - FSTRIM
- Sun 02:00 - Host backup
- Sun 03:00 - Container updates
- Daily 02:00 - Restic to B2

**Storage**: 4.6TB / 35TB used (14%)

---

## Next Steps

### This Week
1. Test media workflows
2. Switch to production HTTPS certificates
3. Complete library migration

### This Month
1. Run full backup restore test
2. Test disaster recovery workflow
3. Consider monitoring solution (Grafana/Prometheus)

---

## Quick Commands

```bash
# Check containers
ssh cuiv@homelab "sudo pct list"

# Apply changes
cd terraform && terraform apply
ansible-playbook ansible/playbooks/<service>.yml --vault-password-file .vault_pass

# Check automation logs
ssh cuiv@homelab "journalctl -u container-update"
ssh cuiv@homelab "journalctl -u host-backup"
```

---

**Last Updated**: 2025-11-16
