# Arch Linux Container Migration - Exploration

**Status**: Idea / Not committed
**Created**: 2025-11-12
**Goal**: Evaluate and plan migration from Debian 12 to Arch Linux for LXC containers

---

## Problem Statement

Current containers run Debian 12 stable, which creates friction:

1. **Hardware support lag**: Intel Arc A380 GPU requires kernel 6.2+ (ideally 6.8+), forcing reliance on backports/testing repos
2. **Package age frustration**: Media processing tools (FFmpeg, MakeMKV) benefit from recent versions
3. **Manual compilation burden**: Some packages require building from source instead of package manager
4. **Philosophical mismatch**: Running bleeding-edge hardware on conservative OS creates constant tension

## Why Consider Arch Linux?

### Hardware Support
- **Intel Arc A380**: Rolling release = immediate access to kernel 6.8+ and current intel-media-driver
- **FFmpeg**: Latest VA-API/QSV support without manual compilation
- **Driver updates**: New GPU features available immediately

### Package Availability
- **MakeMKV**: Available in AUR (vs manual compilation on Debian)
- **Media tools**: Latest FFmpeg with all codec support
- **Bleeding edge**: Aligns hardware (Arc A380) with software support

### Personal Familiarity
- Already running Arch locally
- Familiar with pacman, AUR, Arch patterns
- Comfortable with rolling release model

### Risk Mitigation Factors
- **IaC recovery**: Terraform + Ansible can rebuild containers in minutes
- **Container isolation**: Issues contained to single container, not entire system
- **Non-critical workloads**: Media pipeline isn't production infrastructure
- **Controlled updates**: Can choose when to run `pacman -Syu`
- **Snapshots**: Can snapshot before updates and rollback if needed

---

## Arch Linux in LXC Containers - Research Findings

### Confirmed Working
- Proxmox provides official Arch Linux LXC templates
- Users report "works very well" for LXC containers
- Active community usage confirmed

### Known Requirements
- **Unprivileged containers**: Networking works better in unprivileged mode
- **Manual setup**: More complex initial setup than Debian (GPG keys, mirrors)
- **Template considerations**: Not as "fire and forget" as Debian

### Known Issues (Historical)
- systemd updates occasionally broke LXC networking (e.g., 246→247)
- Kernel updates rarely caused LXC start issues
- AUR packages can have temporary breakage

### Key Insight
These issues are **less severe in containers** than bare metal because:
- Container-level issues don't affect host
- Fast rebuild capability with IaC
- Can pin packages if needed
- Rollback is simple (`pct restore`)

---

## Alternative Considered: NixOS

### Why Not NixOS?
- **Learning curve**: No experience with Nix, steep learning investment
- **LXC complications**: Cannot create via Proxmox UI, broken default templates
- **IaC tension**: Nix wants to be declarative, overlaps with Terraform+Ansible approach
- **Wrong timing**: Would be learning Nix while trying to improve media pipeline
- **Verdict**: Save for future greenfield project where can invest proper learning time

---

## Migration Approach

### Strategy: Gradual Rollout

**Phase 1: Single Container Pilot**
- Choose CT304 (transcoder) as test case
- Tests most critical aspect: GPU hardware passthrough
- Low risk: Transcoder is stateless processing container

**Phase 2: Hardware Passthrough Validation**
- Migrate CT302 (ripper) - optical drive passthrough
- Migrate CT305 (Jellyfin) - dual GPU passthrough
- Confirms all passthrough types work on Arch

**Phase 3: Remaining Containers**
- Migrate CT303 (analyzer)
- Consider keeping CT300/301 (backup, samba) on Debian if no benefit from Arch

**Rollback Plan**
- Keep Debian templates available
- Document Debian container state before migration
- Can rebuild on Debian at any time via IaC

---

## Technical Changes Required

### Terraform Changes (Minimal)

```hcl
# OLD
operating_system {
  template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  type            = "debian"
}

# NEW
operating_system {
  template_file_id = "local:vztmpl/archlinux-base_YYYYMMDD-1_amd64.tar.zst"
  type            = "archlinux"
}
```

**Note**: Need to download Arch template to Proxmox first.

### Ansible Changes (Moderate)

**Package Manager Module:**
```yaml
# OLD (Debian)
- name: Install packages
  apt:
    name: "{{ packages }}"
    state: present

# NEW (Arch)
- name: Install packages
  pacman:
    name: "{{ packages }}"
    state: present
```

**Package Name Mapping:**
| Debian | Arch |
|--------|------|
| `build-essential` | `base-devel` |
| `pkg-config` | `pkgconf` |
| `libavcodec-dev` | `ffmpeg` (includes dev files) |
| `qt5-default` | `qt5-base` |

**AUR Helper (New Requirement):**
```yaml
- name: Install yay (AUR helper)
  block:
    - name: Clone yay
      git:
        repo: https://aur.archlinux.org/yay.git
        dest: /tmp/yay
    - name: Build and install yay
      command: makepkg -si --noconfirm
      args:
        chdir: /tmp/yay
      become_user: media
```

**System Updates:**
```yaml
# OLD (Debian)
- name: Update apt cache
  apt:
    update_cache: yes

# NEW (Arch)
- name: Update package database
  pacman:
    update_cache: yes
```

---

## Testing Strategy

### Pre-Migration Tests (Debian Baseline)
1. Document current performance metrics
   - Transcode speed (CT304)
   - Rip speed (CT302)
   - Jellyfin transcode performance (CT305)
2. Export current configuration
3. Take LXC snapshots

### Post-Migration Tests (Arch)
1. **Hardware passthrough verification:**
   - GPU devices visible: `ls -la /dev/dri/`
   - VA-API functional: `vainfo --display drm --device /dev/dri/renderD128`
   - Optical drive accessible: `ls -la /dev/sr0 /dev/sg4`
2. **Software functionality:**
   - MakeMKV can rip disc
   - FFmpeg can transcode with QSV
   - Jellyfin can serve and transcode
3. **Performance comparison:**
   - Same benchmarks as Debian baseline
   - Should be same or better (newer drivers)
4. **Stability testing:**
   - Run full media pipeline end-to-end
   - Monitor for errors over 1 week

### Acceptance Criteria
- ✅ All hardware passthrough working
- ✅ All scripts functional
- ✅ Performance >= Debian baseline
- ✅ No critical errors during 1-week test
- ✅ Update process documented and tested

---

## Migration Checklist (When Ready)

### Preparation
- [ ] Git branch: `arch-migration`
- [ ] Download Arch LXC template to Proxmox
- [ ] Document current Debian container state
- [ ] Backup current Ansible playbooks
- [ ] Take LXC snapshots of all containers

### Phase 1: CT304 Pilot
- [ ] Update `ct304-transcoder.tf` with Arch template
- [ ] Update Ansible playbook for Arch packages
- [ ] Add AUR helper installation
- [ ] Update package names (FFmpeg, intel-media-driver)
- [ ] Deploy with Terraform
- [ ] Run Ansible playbook
- [ ] Test GPU passthrough
- [ ] Run transcode tests
- [ ] Document any issues

### Phase 2: Rollout (If Pilot Succeeds)
- [ ] Migrate CT302 (ripper)
- [ ] Test optical drive passthrough
- [ ] Migrate CT305 (Jellyfin)
- [ ] Test dual GPU setup
- [ ] Migrate CT303 (analyzer)
- [ ] Full end-to-end media pipeline test

### Phase 3: Stabilization
- [ ] Update container documentation
- [ ] Create update policy
- [ ] Document Arch-specific gotchas
- [ ] Update README with rationale
- [ ] Monitor for 2 weeks
- [ ] Commit or rollback decision

---

## Risks & Mitigation

### Risk: Rolling Release Breakage
**Likelihood**: Medium
**Impact**: Medium (container-isolated)
**Mitigation**:
- Snapshot before updates
- Review Arch news before `pacman -Syu`
- Pin critical packages if needed
- IaC allows fast rebuild

### Risk: AUR Package Issues
**Likelihood**: Low-Medium
**Impact**: Low (specific packages only)
**Mitigation**:
- Build from source if AUR broken
- Use stable alternatives when available
- Document build process

### Risk: Hardware Passthrough Incompatibility
**Likelihood**: Low
**Impact**: High (blocks migration)
**Mitigation**:
- Test in pilot phase (CT304)
- Research Arch + Proxmox GPU passthrough first
- Rollback to Debian if doesn't work

### Risk: Learning Curve / Time Investment
**Likelihood**: Medium
**Impact**: Medium (time spent)
**Mitigation**:
- Already familiar with Arch from local usage
- Start with single container
- Don't rush rollout

---

## Questions to Answer Before Committing

1. **Proxmox Arch template availability**: Is current template recent/stable?
2. **GPU passthrough on Arch LXC**: Any known Proxmox-specific issues?
3. **Ansible module compatibility**: Any gaps in Arch support?
4. **Update frequency**: What's realistic update cadence for homelab?
5. **Community support**: Active Arch+Proxmox LXC community?

---

## Decision Criteria

**Commit to migration if:**
- ✅ Pilot (CT304) successful with no major issues
- ✅ Hardware passthrough works perfectly
- ✅ Performance same or better than Debian
- ✅ Ansible changes straightforward
- ✅ No unexpected complications

**Stay on Debian if:**
- ❌ Pilot reveals major incompatibilities
- ❌ Hardware passthrough unreliable
- ❌ Ansible changes too complex
- ❌ Hidden complexity not worth package freshness
- ❌ Stability issues appear immediately

---

## Resources

### Documentation to Create
- Arch LXC template download instructions
- Arch-specific Ansible playbook examples
- Package name mapping reference
- Update procedure documentation
- Troubleshooting guide

### External Resources
- [Arch Wiki: Hardware Video Acceleration](https://wiki.archlinux.org/title/Hardware_video_acceleration)
- [Proxmox Forum: Arch Linux](https://forum.proxmox.com/tags/arch-linux/)
- [Arch Wiki: LXC](https://wiki.archlinux.org/title/Linux_Containers)

---

## Next Steps (When Ready to Proceed)

1. Research Proxmox Arch template download
2. Create test plan document
3. Set aside time for pilot migration (estimate 4-6 hours)
4. Create git branch for changes
5. Document current Debian baseline
6. Execute pilot migration

---

**Note**: This is an exploration document. No commitment to execute. Keep in ideas/ until decision made to proceed, then move to active/.
