# Wishlist Quick Reference

**Container:** CT307 (192.168.1.186)
**Access:** https://wishlist.paniland.com (public) or http://192.168.1.186:3280 (local)
**User:** wishlist
**Install Path:** /opt/wishlist

## Common Commands

### Service Management
```bash
# Check status
ssh wishlist "systemctl status wishlist"

# View logs
ssh wishlist "journalctl -u wishlist -f"

# Restart service
ssh wishlist "systemctl restart wishlist"
```

### Application Updates
```bash
# SSH to container
ssh wishlist

# Switch to wishlist user
sudo -u wishlist bash

# Navigate to repo
cd /opt/wishlist/repo

# Pull latest changes
git pull origin main

# Install dependencies
pnpm install

# Rebuild application
pnpm build

# Exit back to root
exit

# Restart service
systemctl restart wishlist
```

### Database Management
```bash
# Backup database
ssh wishlist "cp /opt/wishlist/data/prod.db /opt/wishlist/data/prod.db.backup"

# View database size
ssh wishlist "du -sh /opt/wishlist/data/"

# Run Prisma migrations manually
ssh wishlist "sudo -u wishlist bash -c 'cd /opt/wishlist/repo && pnpm prisma migrate deploy'"
```

### Troubleshooting
```bash
# Check if port is listening
ssh wishlist "ss -tlnp | grep 3280"

# Test local connectivity
ssh wishlist "curl -I http://localhost:3280"

# Check Node.js process
ssh wishlist "ps aux | grep node"

# View recent errors
ssh wishlist "journalctl -u wishlist -p err -n 50"
```

## Configuration

**Environment variables:** `/etc/default/wishlist`
**Systemd service:** `/etc/systemd/system/wishlist.service`
**Database:** `/opt/wishlist/data/prod.db` (SQLite)
**Uploads:** `/opt/wishlist/uploads/`

## Infrastructure Management

### Terraform
```bash
cd terraform
terraform plan    # Preview changes
terraform apply   # Apply infrastructure changes
```

### Ansible
```bash
cd ansible
ansible-playbook playbooks/wishlist.yml
ansible-playbook playbooks/wishlist.yml --tags deploy
```

## First-Time Setup

1. Navigate to https://wishlist.paniland.com
2. Create admin account
3. Configure default currency and preferences
4. Create wishlists or groups
5. Invite users via email (requires SMTP config) or share registration link

## User Management

Wishlist uses built-in user accounts. User management is done through the web UI.

**Reset user password:** Requires database access (use Prisma Studio or SQL)

```bash
# Option 1: Prisma Studio (recommended)
ssh wishlist
sudo -u wishlist bash
cd /opt/wishlist/repo
pnpm prisma studio

# Option 2: Direct SQLite access (advanced)
ssh wishlist
sqlite3 /opt/wishlist/data/prod.db
```

## Backup and Restore

### Manual Backup
```bash
ssh wishlist "tar czf /tmp/wishlist-backup.tar.gz /opt/wishlist/data /opt/wishlist/uploads"
scp wishlist:/tmp/wishlist-backup.tar.gz ~/backups/wishlist-$(date +%Y%m%d).tar.gz
```

### Restore from Backup
```bash
scp ~/backups/wishlist-20251124.tar.gz wishlist:/tmp/
ssh wishlist "systemctl stop wishlist && tar xzf /tmp/wishlist-20251124.tar.gz -C / && systemctl start wishlist"
```

## Security Notes

- Wishlist runs as unprivileged user `wishlist`
- Systemd service has security hardening (NoNewPrivileges, PrivateTmp, ProtectSystem)
- Database and uploads are restricted to wishlist user (755)
- Environment file contains sensitive data (600 permissions)
- HTTPS enforced via Caddy reverse proxy with Cloudflare DNS-01
- Tailscale ACLs restrict access to friends group

## Monitoring

- **Service status:** `systemctl status wishlist`
- **Application logs:** `journalctl -u wishlist -f`
- **Resource usage:** `pct exec 307 -- htop`
- **Disk usage:** `pct exec 307 -- df -h`

## Known Issues

- None yet (new deployment)

---

**Maintenance:** Update this document when configuration or procedures change.
