# Common Role

Base configuration role applied to all homelab hosts and containers.

## Purpose

Provides common configuration across all infrastructure:
- SSH key distribution
- System configuration (timezone, locale)
- Base package installation
- Standardized settings

## Features

### SSH Key Management
- Automatically deploys all SSH public keys from `ansible/files/ssh-keys/`
- Distributes keys to specified users (default: root)
- Maintains proper permissions on `.ssh/` directory and `authorized_keys`

### System Configuration
- Sets timezone (default: America/New_York)
- Configures locale (default: en_US.UTF-8)
- Sets hostname based on inventory

### Package Management
- Installs common utilities (vim, htop, curl, wget, git, etc.)
- Updates apt cache

## Usage

### Apply to all hosts
```yaml
- name: Configure all hosts
  hosts: all
  roles:
    - common
```

### Apply only SSH keys
```yaml
- name: Sync SSH keys
  hosts: all
  roles:
    - role: common
      tags: ['ssh-keys']
```

## Variables

### SSH Keys
- `ssh_keys_directory`: Path to directory containing `.pub` files (default: `{{ playbook_dir }}/../files/ssh-keys`)
- `ssh_authorized_keys_users`: List of users to deploy keys to (default: `['root']`)

### System
- `timezone`: System timezone (default: `America/New_York`)
- `locale`: System locale (default: `en_US.UTF-8`)

### Packages
- `common_packages`: List of packages to install

## Tags

- `ssh-keys` / `ssh`: SSH key distribution only
- `system`: System configuration only
- `packages`: Package installation only

## Example Playbook

```yaml
- name: Configure homelab infrastructure
  hosts: all
  become: true
  roles:
    - role: common
      vars:
        timezone: "America/Los_Angeles"
        ssh_authorized_keys_users:
          - root
          - media
```
