# MakeMKV Ansible Role

Installs and configures MakeMKV (Blu-ray/DVD ripper) from source with beta key support.

## Requirements

- Debian/Ubuntu based system
- Internet access for downloading MakeMKV source
- Sufficient disk space for compilation (~500MB)

## Role Variables

See `defaults/main.yml` for all variables:

```yaml
makemkv_version: "1.18.2"  # Version to install (update when upgrading)
makemkv_user: "media"      # User to configure MakeMKV for
makemkv_beta_key: ""       # Beta key (set via encrypted vars file)
```

## Dependencies

- `build-essential`, `pkg-config`, Qt5 libraries, ffmpeg libraries

## Example Playbook

```yaml
- hosts: ripper
  vars_files:
    - vars/makemkv_secrets.yml  # Contains makemkv_beta_key
  roles:
    - makemkv
```

## Secrets Management

The beta key should be stored in an encrypted Ansible Vault file:

```bash
# Create encrypted secrets file
ansible-vault create vars/makemkv_secrets.yml

# Add:
---
makemkv_beta_key: "M-YOUR-BETA-KEY-HERE"
```

Get the latest beta key from: https://forum.makemkv.com/forum/viewtopic.php?t=1053

## Version Control

This role supports controlled version upgrades:

1. Update `makemkv_version` in `defaults/main.yml`
2. Re-run playbook
3. Role detects version mismatch and recompiles

## License

MIT

## Author

Homelab IaC Project
