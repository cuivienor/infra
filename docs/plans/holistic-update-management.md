# Holistic Update Management Plan

**Created**: 2025-11-16  
**Status**: Planning  
**Priority**: Medium (foundational work complete, enhancements pending)

---

## Current State (Implemented)

### Automated Updates
- **Proxmox Host**: unattended-upgrades for security patches (daily)
- **Raspberry Pis**: unattended-upgrades for security patches (daily)
- **LXC Containers**: Weekly full upgrades via `proxmox_container_updates` role
- **APT Repository Apps**: Jellyfin, Tailscale, Caddy updated with container updates

### Manual Tracking
- **Version tracking doc**: `docs/reference/version-tracking.md`
- **Check script**: `scripts/check-updates.sh` (checks GitHub releases)
- **Quarterly audit**: Documented procedures for manual review

### Known Gaps
- No automated notification for pinned version updates
- No centralized update dashboard
- No security vulnerability scanning
- Terraform provider updates require manual `terraform init -upgrade`

---

## Phase 1: Notification System (Q1 2026)

**Goal**: Get notified when updates are available for pinned versions

### Option A: GitHub Actions Workflow (Recommended)

Create `.github/workflows/check-updates.yml`:

```yaml
name: Check for Software Updates
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM
  workflow_dispatch:

jobs:
  check-updates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check pinned versions
        run: ./scripts/check-updates.sh
      - name: Create issue if updates available
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Software updates available',
              body: 'Run `./scripts/check-updates.sh` to see available updates.',
              labels: ['maintenance', 'updates']
            })
```

**Pros**: Free, integrated with repo, creates trackable issues  
**Cons**: Requires repo on GitHub, public exposure of versions

### Option B: Local Cron + Email

Add to Proxmox host via Ansible:

```yaml
- name: Schedule weekly version check
  ansible.builtin.cron:
    name: "Check for software updates"
    minute: "0"
    hour: "9"
    weekday: "1"
    job: "/path/to/check-updates.sh | mail -s 'Homelab Update Report' you@email.com"
```

**Pros**: Self-hosted, private  
**Cons**: Requires mail setup (msmtp/postfix)

### Option C: RSS Feed Monitoring

Deploy Miniflux or FreshRSS in a container and subscribe to:
- https://github.com/restic/restic/releases.atom
- https://github.com/trapexit/mergerfs/releases.atom
- https://github.com/amadvance/snapraid/releases.atom
- Proxmox release notes RSS

**Pros**: Visual dashboard, covers more than just GitHub  
**Cons**: Another service to maintain

---

## Phase 2: Renovate Bot for IaC (Q1 2026)

**Goal**: Automated PRs for Terraform provider and Ansible collection updates

### Setup

1. Create `renovate.json` in repo root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "enabledManagers": ["terraform"],
  "packageRules": [
    {
      "matchManagers": ["terraform"],
      "automerge": false,
      "schedule": ["before 6am on the first day of the month"]
    }
  ],
  "ignorePaths": [
    "**/node_modules/**",
    "**/.terraform/**"
  ]
}
```

2. Install Renovate GitHub App (if using GitHub)
3. Or self-host Renovate runner

**Benefits**:
- Automatic PRs when providers update
- Changelog included in PR
- Can set automerge for patch versions

---

## Phase 3: Security Scanning (Q2 2026)

**Goal**: Detect known vulnerabilities in installed packages

### Container Vulnerability Scanning

Add to container update script:

```bash
# After updating each container, check for known CVEs
for ctid in $CONTAINERS; do
    echo "Scanning CT$ctid for vulnerabilities..."
    pct exec "$ctid" -- apt list --installed 2>/dev/null | \
        grep -E 'security|CVE' || echo "No known issues"
done
```

### Trivy Scanner (Advanced)

Deploy Trivy for deeper scanning:

```bash
# Scan container filesystem
trivy rootfs /var/lib/lxc/<ctid>/rootfs
```

### NIST NVD Integration

Subscribe to NIST NVD feeds for packages you use:
- Linux kernel CVEs
- OpenSSL vulnerabilities
- Specific application CVEs

---

## Phase 4: Monitoring Dashboard (Q2-Q3 2026)

**Goal**: Visual overview of update status across infrastructure

### Grafana + Prometheus Stack

1. Deploy monitoring stack in container
2. Create custom metrics:
   - Last update timestamp per host
   - Pending security updates count
   - Reboot required status
   - Version drift from latest

### Dashboard Panels

- **Host Update Status**: Table showing last update time, pending updates
- **Container Health**: Update success/failure rates
- **Version Matrix**: Current vs latest for pinned software
- **Security Alerts**: CVE count, severity levels

### Alerting Rules

```yaml
# Alert if host hasn't updated in 7 days
- alert: StaleUpdates
  expr: time() - last_update_timestamp > 604800
  labels:
    severity: warning
  annotations:
    summary: "Host {{ $labels.host }} hasn't updated in 7 days"
```

---

## Phase 5: Staged Rollout Strategy (Q3 2026)

**Goal**: Safe update deployment with rollback capability

### Container Update Staging

1. **Test Container (CTID 199)**: Update first, run tests
2. **Non-Critical Services**: backup, analyzer (low impact if down)
3. **Important Services**: transcoder, ripper (media pipeline)
4. **Critical Services**: dns, proxy, jellyfin (user-facing)

### Update Windows

```
Week 1: Test container
Week 2: Non-critical if test passes
Week 3: Important services
Week 4: Critical services (manual approval)
```

### Rollback Procedures

1. **Containers**: Restore from Restic backup (automated)
2. **Proxmox Host**: Boot previous kernel, restore config
3. **Applications**: Version pin in Ansible, re-run playbook

---

## Phase 6: Compliance Reporting (Q4 2026)

**Goal**: Track update compliance over time

### Monthly Report Generation

```bash
#!/bin/bash
# Generate monthly update compliance report

echo "=== Update Compliance Report $(date +%B\ %Y) ==="
echo ""
echo "## Host Updates"
for host in homelab pi4 pi3; do
    echo "### $host"
    ssh $host "cat /var/log/unattended-upgrades/unattended-upgrades.log | grep 'Packages that will be upgraded' | tail -30"
done

echo "## Container Updates"
tail -100 /var/log/container-updates.log | grep -E 'SUCCESS|FAILED'

echo "## Pending Reboots"
# Check each host for reboot-required
```

### Metrics to Track

- Days since last security update per host
- Number of packages updated per month
- Failed update attempts
- Time to apply critical CVE patches
- Version lag for pinned software

---

## Implementation Priority

| Phase | Timeline | Effort | Impact |
|-------|----------|--------|--------|
| 1. Notifications | Q1 2026 | Low | High |
| 2. Renovate Bot | Q1 2026 | Low | Medium |
| 3. Security Scanning | Q2 2026 | Medium | High |
| 4. Monitoring Dashboard | Q2-Q3 2026 | High | Medium |
| 5. Staged Rollouts | Q3 2026 | Medium | High |
| 6. Compliance Reporting | Q4 2026 | Low | Low |

---

## Quick Wins (This Week)

1. **Set calendar reminder** for quarterly version audits (Jan, Apr, Jul, Oct)
2. **Star GitHub repos** for pinned software to get release notifications
3. **Complete Pi3 setup** once current upgrade finishes
4. **Document current versions** in version-tracking.md with "Last Checked" dates

---

## Resource Requirements

- **Phase 1-2**: No additional infrastructure
- **Phase 3**: Trivy binary (~50MB) or container
- **Phase 4**: Grafana + Prometheus containers (2-4GB RAM)
- **Phase 5-6**: No additional infrastructure, just automation scripts

---

## Success Criteria

- [ ] No software more than 1 minor version behind
- [ ] Security updates applied within 7 days of release
- [ ] Zero manual intervention needed for routine updates
- [ ] Complete audit trail of all updates applied
- [ ] Ability to rollback any update within 1 hour

---

## References

- [Debian Security Information](https://www.debian.org/security/)
- [Proxmox Security Advisories](https://www.proxmox.com/en/news/security-advisories)
- [Renovate Documentation](https://docs.renovatebot.com/)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)
- [r/homelab Update Best Practices](https://www.reddit.com/r/homelab/wiki/software)

---

**Next Review**: Q1 2026 (after Phase 1-2 implementation)
