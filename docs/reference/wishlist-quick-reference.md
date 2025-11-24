# Wishlist Quick Reference

**Container:** CT307 (192.168.1.186)
**Access:** https://wishlist.paniland.com (public) or http://192.168.1.186:3280 (local)
**User:** wishlist
**Install Path:** /opt/wishlist

## Common Commands

### Service Management
```bash
# Check status
ssh root@192.168.1.186 "systemctl status wishlist"

# View logs
ssh root@192.168.1.186 "journalctl -u wishlist -f"

# Restart service
ssh root@192.168.1.186 "systemctl restart wishlist"
```

### Application Updates
```bash
# SSH to container
ssh root@192.168.1.186

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
ssh root@192.168.1.186 "cp /opt/wishlist/data/prod.db /opt/wishlist/data/prod.db.backup"

# View database size
ssh root@192.168.1.186 "du -sh /opt/wishlist/data/"

# Run Prisma migrations manually
ssh root@192.168.1.186 "sudo -u wishlist bash -c 'cd /opt/wishlist/repo && pnpm prisma migrate deploy'"
```

### Troubleshooting
```bash
# Check if port is listening
ssh root@192.168.1.186 "ss -tlnp | grep 3280"

# Test local connectivity
ssh root@192.168.1.186 "curl -I http://localhost:3280"

# Check Node.js process
ssh root@192.168.1.186 "ps aux | grep node"

# View recent errors
ssh root@192.168.1.186 "journalctl -u wishlist -p err -n 50"
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
# Full deployment
ansible-playbook ansible/playbooks/wishlist.yml --vault-password-file .vault_pass

# Specific tasks
ansible-playbook ansible/playbooks/wishlist.yml --vault-password-file .vault_pass --tags deploy
ansible-playbook ansible/playbooks/wishlist.yml --vault-password-file .vault_pass --tags systemd
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
ssh root@192.168.1.186
sudo -u wishlist bash
cd /opt/wishlist/repo
pnpm prisma studio

# Option 2: Direct SQLite access (advanced)
ssh root@192.168.1.186
sqlite3 /opt/wishlist/data/prod.db
```

## Backup and Restore

### Manual Backup
```bash
ssh root@192.168.1.186 "tar czf /tmp/wishlist-backup.tar.gz /opt/wishlist/data /opt/wishlist/uploads"
scp root@192.168.1.186:/tmp/wishlist-backup.tar.gz ~/backups/wishlist-$(date +%Y%m%d).tar.gz
```

### Restore from Backup
```bash
scp ~/backups/wishlist-20251124.tar.gz root@192.168.1.186:/tmp/
ssh root@192.168.1.186 "systemctl stop wishlist && tar xzf /tmp/wishlist-20251124.tar.gz -C / && systemctl start wishlist"
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
