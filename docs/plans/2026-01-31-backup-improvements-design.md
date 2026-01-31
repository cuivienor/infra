# Backup Infrastructure Improvements - Design Document

**Date:** 2026-01-31
**Status:** Approved

## Problem

Current backup only covers `/mnt/storage` (NAS). Critical service databases on container-local SSDs are not backed up:
- LLDAP (user directory)
- Authelia (SSO sessions)
- Mealie (recipes)
- Wishlist (gift lists)
- Jellyfin (library metadata)
- Caddy (TLS certs)
- CouchDB/Vault (family notes)

## Solution

Centralized pull architecture: CT300 (backup) rsyncs from each service container to `/mnt/storage/backups/`, then existing Restic job backs up to B2.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Proxmox Host                                 │
│                                                                      │
│  /mnt/storage/backups/                                               │
│  ├── lldap/          ◄── rsync from CT308                           │
│  ├── authelia/       ◄── rsync from CT312                           │
│  ├── mealie/         ◄── rsync from CT314 (+ pg_dump)               │
│  ├── wishlist/       ◄── rsync from CT307                           │
│  ├── jellyfin/       ◄── rsync from CT305 (excl. cache)             │
│  ├── caddy/          ◄── rsync from CT311                           │
│  └── vault/          ◄── rsync from CT321                           │
│                                                                      │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  CT300 (backup)                                                      │
│  /mnt/storage (read-only mount)                                      │
│       │                                                              │
│       └──► Restic daily backup ──► Backblaze B2 (homelab-data)      │
└──────────────────────────────────────────────────────────────────────┘
```

## Design Decisions

1. **SSD performance preserved** - Data stays on container-local SSD, synced to HDD for backup
2. **Centralized pull** - Backup container pulls from services (vs distributed push)
3. **SSH-based access** - Backup container gets SSH key, pubkey distributed via common role
4. **pg_dump for Mealie** - PostgreSQL needs proper dump, not file copy
5. **Exclude Jellyfin cache** - `/var/cache/jellyfin/` is 50GB+ transcoding cache

## Backup Paths

| Service | Paths | Notes |
|---------|-------|-------|
| **LLDAP** | `/var/lib/lldap/`, `/opt/lldap/lldap_config.toml` | SQLite + private_key |
| **Authelia** | `/var/lib/authelia/`, `/etc/authelia/` | Includes oidc.pem |
| **Mealie** | `/opt/mealie/data/`, `/opt/mealie/.env`, `/tmp/mealie_backup.sql` | pg_dump before rsync |
| **Wishlist** | `/opt/wishlist/data/`, `/opt/wishlist/uploads/` | SQLite + uploads |
| **Jellyfin** | `/var/lib/jellyfin/`, `/etc/jellyfin/` | Exclude `/var/cache/jellyfin/` |
| **Caddy** | `/var/lib/caddy/.local/share/caddy/`, `/etc/caddy/`, `/etc/default/caddy` | TLS certs + API token |
| **Vault** | `/var/lib/couchdb/`, `/opt/couchdb/etc/local.d/` | CouchDB data + config |

## Schedule

| Time | Action |
|------|--------|
| 2:30 AM | Pre-backup sync (rsync from all containers) |
| 3:00 AM | Restic backup to B2 (existing job) |

## Implementation

### 1. SSH Key Setup

- Generate key pair on CT300 (backup container)
- Store public key in Ansible variable
- Distribute via `common` role to all service containers

### 2. New Files

```
ansible/roles/backup/
├── tasks/
│   └── main.yml           # Add SSH key gen, pre-backup sync setup
├── templates/
│   └── pre-backup-sync.sh.j2   # New sync script
└── defaults/
    └── main.yml           # Add backup_sync_targets

ansible/roles/common/
└── tasks/
    └── main.yml           # Add backup SSH pubkey to authorized_keys
```

### 3. Sync Script

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/mnt/storage/backups"

# Mealie: pg_dump first
ssh mealie "sudo -u postgres pg_dump mealie > /tmp/mealie_backup.sql"

# Sync all services
rsync -az lldap:/var/lib/lldap/ "$BACKUP_DIR/lldap/"
rsync -az lldap:/opt/lldap/lldap_config.toml "$BACKUP_DIR/lldap/"
# ... etc for each service

# Jellyfin: exclude cache
rsync -az --exclude='*.cache*' jellyfin:/var/lib/jellyfin/ "$BACKUP_DIR/jellyfin/"
```

## Rollout

1. Run `common` role on all service containers (distributes SSH pubkey)
2. Run `backup` role on CT300 (sets up sync script and timer)
3. Verify: manual run of pre-backup-sync.sh
4. Next scheduled backup includes all service data

## Testing

After implementation:
1. Manual sync run: `/etc/restic/scripts/pre-backup-sync.sh`
2. Verify files appear in `/mnt/storage/backups/<service>/`
3. Run Restic backup manually
4. Test restore of one service from B2
