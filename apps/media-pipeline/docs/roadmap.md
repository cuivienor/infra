# Media Pipeline - Self-Contained Application

## Summary

Evolve media-pipeline from a monitoring TUI into a **self-contained application** that includes:
- Go TUI for monitoring (MVP complete ✓)
- Bash scripts for processing (rip, remux, transcode, filebot)
- GitHub releases for distribution
- Ansible role for installation

**Current Status:** MVP TUI complete. Now consolidating scripts and setting up releases.

## Decisions Made

| Decision | Choice |
|----------|--------|
| Language | Go + Bubbletea (learning Go is a goal) |
| Integration | Gradual migration - scripts coexist, TUI orchestrates later |
| Packaging | GitHub releases with tarball |
| Repo Structure | `cmd/` for all commands (Go + bash) |
| IaC Pattern | Version-pinned Ansible role |
| GitHub | `github.com/cuivienor/media-pipeline` |

## What's Done (MVP Complete ✓)

- Go TUI with pipeline overview, stage list, action-needed, item detail views
- Filesystem scanner reading `.rip/.remux/.transcode/.filebot` state dirs
- Build and deploy via Makefile
- Deployed and working on analyzer container

---

## Target Repository Structure

```
media-pipeline/
├── cmd/
│   ├── media-pipeline/        # Go TUI (existing)
│   │   └── main.go
│   ├── rip/                   # Bash script
│   │   └── rip-disc.sh
│   ├── remux/                 # Bash script
│   │   └── remux.sh
│   ├── transcode/             # Bash script
│   │   └── transcode.sh
│   └── filebot/               # Bash script
│       └── filebot.sh
├── internal/                  # Go packages (existing)
│   ├── model/
│   ├── scanner/
│   └── tui/
├── .github/
│   └── workflows/
│       └── release.yml        # Build on tag, create release
├── Makefile                   # Build + package
├── go.mod
└── README.md
```

## Release Artifact

```
media-pipeline-v0.1.0-linux-amd64.tar.gz
└── bin/
    ├── media-pipeline         # Go binary
    ├── rip-disc               # Script (executable)
    ├── remux                  # Script (executable)
    ├── transcode              # Script (executable)
    └── filebot                # Script (executable)
```

---

## Immediate Task: Consolidate Content into Repo

Copy scripts and docs into media-pipeline repo so it's self-contained.

### Task 1: Copy Scripts

```bash
mkdir -p cmd/rip cmd/remux cmd/transcode cmd/filebot
cp ~/dev/homelab-notes/scripts/media/production/rip-disc.sh cmd/rip/
cp ~/dev/homelab-notes/scripts/media/production/remux.sh cmd/remux/
cp ~/dev/homelab-notes/scripts/media/production/transcode.sh cmd/transcode/
cp ~/dev/homelab-notes/scripts/media/production/filebot.sh cmd/filebot/
```

### Task 2: Copy Documentation

```bash
mkdir -p docs
# Copy ripping guide
cp ~/dev/homelab-notes/docs/guides/ripping-guide.md docs/
# Copy this plan as roadmap
cp ~/.claude/plans/toasty-waddling-pine.md docs/roadmap.md
```

### Task 3: Commit Changes

Commit the consolidated content to the repo.

---

## Future Work (Phase 1 - Not Now)

After content is consolidated, these tasks remain for making it a proper release:

1. Update go.mod module path to `cuivienor`
2. Update Makefile for packaging
3. Create GitHub Actions release workflow
4. Push to GitHub
5. Create first release (v0.1.0)

---

## Phase 2: Update Deployment (Future)

After Phase 1 is stable and tested, update homelab-notes to consume releases.

### Task 2.1: Create Ansible Role

**Create new role: `ansible/roles/media_pipeline/`**

```yaml
# tasks/main.yml
- name: Create media bin directory
  file:
    path: /home/media/bin
    state: directory
    owner: media
    group: media
    mode: '0755'

- name: Download media-pipeline release
  get_url:
    url: "https://github.com/cuivienor/media-pipeline/releases/download/{{ media_pipeline_version }}/media-pipeline-{{ media_pipeline_version }}-linux-amd64.tar.gz"
    dest: /tmp/media-pipeline.tar.gz
  register: download

- name: Extract media-pipeline
  unarchive:
    src: /tmp/media-pipeline.tar.gz
    dest: /home/media/
    remote_src: yes
    owner: media
    group: media
  when: download.changed

- name: Cleanup download
  file:
    path: /tmp/media-pipeline.tar.gz
    state: absent
```

```yaml
# defaults/main.yml
media_pipeline_version: "v0.1.0"
```

### Task 2.2: Update Playbooks

Add `media_pipeline` role to relevant playbooks (analyzer, ripper, transcoder).

### Task 2.3: Remove Old Scripts

After confirming the new role works:
1. Remove `scripts/media/production/` from homelab-notes
2. Update any Ansible roles that referenced the old script locations
3. Update `media_analyzer` role to use `media_pipeline` role instead

### Phase 2 Success Criteria

- [ ] Ansible role created and working
- [ ] Playbooks updated to use new role
- [ ] Old scripts removed from homelab-notes
- [ ] All containers using release artifacts
