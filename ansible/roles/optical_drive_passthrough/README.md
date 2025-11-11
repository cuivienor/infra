# Optical Drive Passthrough Ansible Role

Configures LXC container to access the host's optical drive (Blu-ray/DVD) via device passthrough.

## Requirements

- Proxmox VE host
- Privileged LXC container
- Optical drive present on host (`/dev/sr0`, `/dev/sg4`)

## Role Variables

See `defaults/main.yml` for all variables:

```yaml
container_id: 302  # LXC container ID (REQUIRED)
optical_drive_block_device: "/dev/sr0"
optical_drive_scsi_device: "/dev/sg4"
```

## Important Notes

- **This role must run on the Proxmox host**, not the container
- Container must be privileged (`unprivileged: false` in Terraform)
- Container will be restarted if changes are made

## Example Playbook

```yaml
- hosts: homelab  # Proxmox host
  vars:
    container_id: 302
  roles:
    - optical_drive_passthrough
```

## What It Configures

Adds to `/etc/pve/lxc/<container_id>.conf`:

```
lxc.cgroup2.devices.allow: c 11:0 rwm
lxc.cgroup2.devices.allow: c 21:4 rwm
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
lxc.mount.entry: /dev/sg4 dev/sg4 none bind,optional,create=file
```

## Verification

After role completes, verify in container:

```bash
pct enter <container_id>
ls -la /dev/sr0 /dev/sg4
makemkvcon info disc:0  # If MakeMKV installed
```

## Reusability

This role is designed to be reusable for any container needing optical drive access. Just set `container_id` and include the role.

## License

MIT

## Author

Homelab IaC Project
