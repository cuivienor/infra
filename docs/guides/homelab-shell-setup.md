# Homelab Shell Environment Setup

**Status**: Active  
**Last Updated**: 2025-11-17  
**Deployed via**: Ansible `common` role

---

## Overview

All homelab hosts and containers now use a standardized, minimal shell environment with modern CLI tools for improved quality of life.

## What's Deployed

### Packages Installed

**Core tools** (all hosts):
- `zsh` - Better shell
- `tmux` - Terminal multiplexer
- `bat` - Syntax-highlighted cat
- `ripgrep` (rg) - Fast grep
- `fd-find` (fd) - Fast find
- `fzf` - Fuzzy finder
- `starship` - Minimal prompt

**Optional enhanced** (Proxmox host only):
- `eza` - Modern ls (if available)
- `zoxide` - Smart cd (if available)

### Configuration Files

From `~/dotfiles/stow/homelab/`:

**`.zshrc`**:
- Fast startup (no oh-my-zsh)
- Smart history (10k lines, shared, arrow key search)
- Auto-completion with case-insensitive matching
- Tool initialization (starship, zoxide, fzf)

**`.config/zsh/aliases.bash`**:
- Modern replacements: `ls`→`eza`, `cat`→`bat`, `grep`→`rg`
- Quality of life: `..`, `...`, `c` (clear), `h` (history)
- Git shortcuts: `g`, `gs`, `gd`, `gl`, `ga`, `gc`
- Safer operations: `rm -i`, `mv -i`, `cp -i`

**`.config/starship/starship.toml`**:
- Minimal two-line prompt
- Shows: `user@host` in `directory` [git status]
- Fast command timeout (500ms)
- Disabled unnecessary modules

## Deployment

### Users Configured

- `root` - Always
- `media` - On media pipeline containers (when `media_user_enabled: true`)

### How to Deploy

**Full deployment** (all containers):
```bash
ansible-playbook ansible/playbooks/site.yml --tags homelab-shell
```

**Specific service**:
```bash
ansible-playbook ansible/playbooks/ripper.yml --tags homelab-shell
```

**Just update dotfiles** (after editing ~/dotfiles):
```bash
ansible-playbook ansible/playbooks/site.yml --tags homelab-shell --skip-tags packages
```

### First-time Setup for New Hosts

The `homelab-shell` tasks are included in the `common` role and run automatically when you deploy any playbook that includes it (e.g., `base-setup.yml`, `site.yml`).

## Usage

After deployment, SSH into any container:

```bash
ssh root@192.168.1.131  # ripper container
```

You'll see the starship prompt:
```
┌─root@ripper in /mnt/storage/media/staging/1-ripped on  main !1
└─$
```

Modern tools work automatically:
```bash
ls          # Uses eza (colorized, with icons)
cat file    # Uses bat (syntax highlighted)
grep foo    # Uses ripgrep (faster)
```

History search with arrow keys:
```bash
makemkv<UP> # Shows previous makemkv commands
```

## Configuration Variables

In `ansible/roles/common/defaults/main.yml`:

```yaml
# Enable/disable homelab shell
homelab_shell_enabled: true

# Packages to install
homelab_shell_packages:
  - zsh
  - tmux
  - bat
  - ripgrep
  - fd-find
  - fzf

# Enhanced packages (may not be in repos)
homelab_shell_enhanced: false
homelab_shell_enhanced_packages:
  - eza
  - zoxide

# Dotfiles source
homelab_dotfiles_enabled: true
homelab_dotfiles_local_path: "{{ playbook_dir }}/../../dotfiles/stow/homelab"

# Users to configure
homelab_dotfiles_users:
  - root
```

## Updating the Configuration

1. **Edit dotfiles** in `~/dotfiles/stow/homelab/`
2. **Test locally** (optional):
   ```bash
   cd ~/dotfiles/stow
   stow -t ~ homelab
   ```
3. **Deploy via Ansible**:
   ```bash
   ansible-playbook ansible/playbooks/site.yml --tags homelab-shell
   ```

## Troubleshooting

**Tools not found after deployment?**
- Check package installation: `ssh root@host "which bat zsh starship"`
- Re-run with verbose: `ansible-playbook ... -vv`

**Starship not showing?**
- Verify installation: `ssh root@host "starship --version"`
- Check .zshrc sourcing: `ssh root@host "cat ~/.zshrc | grep starship"`

**Still using bash?**
- Check default shell: `ssh root@host "echo \$SHELL"`
- Manually switch: `ssh root@host "chsh -s /usr/bin/zsh"`

## Design Decisions

**Why not oh-my-zsh?**
- Too heavy for containers
- Slow startup (500ms+ vs <50ms)
- We only need basic features

**Why not full dev environment?**
- Don't need LSP/IDE features on servers
- Use local nvim via SSH for editing
- Keep containers minimal

**Why local copy vs git clone?**
- Simpler (no auth needed)
- Controlled updates (only when ansible runs)
- Dotfiles repo is private

## Future Improvements

- [ ] Consider making dotfiles repo public (just shell configs)
- [ ] Add eza/zoxide from external repos if worth it
- [ ] Create shared tmux config for homelab
- [ ] Add bash compatibility mode for scripts
