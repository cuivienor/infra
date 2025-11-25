# Connecting to Samba Share

**Share**: `smb://samba.home.arpa/storage`
**Username**: `media`
**Password**: In `ansible/vars/secrets.yml` (view with `ansible-vault view vars/secrets.yml` from ansible/)

---

## macOS

**Finder**: Cmd+K → `smb://samba.home.arpa/storage` → Connect as `media`

## Windows

**File Explorer**: `\\samba.home.arpa\storage` → Use credentials `media` / password

## Linux

```bash
sudo apt install cifs-utils
sudo mkdir -p /mnt/storage
sudo mount -t cifs //samba.home.arpa/storage /mnt/storage -o username=media,uid=1000,gid=1000
```

## iPhone/iPad

**Files app** → Three dots → Connect to Server → `smb://samba.home.arpa/storage` → `media` / password

## Android

Install **Cx File Explorer** or **Solid Explorer** → Network → SMB → `samba.home.arpa` → share `storage` → `media` / password
