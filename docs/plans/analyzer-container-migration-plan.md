# Analyzer Container Migration Plan

**Date**: 2025-11-11  
**Goal**: Migrate CT202 (manual analyzer) to CT303 (IaC-managed analyzer)  
**Status**: Ready for deployment

---

## Executive Summary

This document outlines the migration of the analyzer container from manual management (CT202) to Infrastructure as Code (CT303). The analyzer handles media file analysis, remuxing, and organization in the media pipeline.

**Key Improvements:**
- ✅ Full IaC management (Terraform + Ansible)
- ✅ Enhanced security (restricted storage mount)
- ✅ Automated deployment and configuration
- ✅ Version-controlled scripts and configuration
- ✅ Reproducible and documented

---

## Current State Analysis

### CT202 (Manual Container)

| Property | Value |
|----------|-------|
| **CTID** | 202 |
| **IP** | 192.168.1.72 (DHCP) |
| **Storage Mount** | `/mnt/storage` (full access) |
| **Management** | Manual configuration |
| **Scripts** | 6 scripts manually deployed |
| **Tools** | mkvtoolnix, mediainfo, jq installed |

**Issues:**
- No IaC tracking (changes not version controlled)
- DHCP IP (can change on restart)
- Full storage access (not least privilege)
- Manual script deployment
- Configuration drift risk

---

## Target State: CT303

### Design Goals

1. **IaC Management**: Full Terraform + Ansible deployment
2. **Security**: Restricted storage mount (staging only)
3. **Static IP**: Predictable networking (192.168.1.73)
4. **Automation**: Scripts deployed automatically
5. **Documentation**: Comprehensive guides and references

### Technical Specifications

| Property | Value |
|----------|-------|
| **CTID** | 303 |
| **Hostname** | analyzer |
| **IP** | 192.168.1.73 (static) |
| **Type** | Privileged LXC |
| **Resources** | 2 cores, 4GB RAM, 12GB disk |
| **Storage** | `/mnt/staging` → `/mnt/storage/media/staging` |
| **Management** | Terraform + Ansible |

### Security Model

**Least Privilege Approach:**
```
CT303 Can Access:
  ✅ /mnt/staging/1-ripped/
  ✅ /mnt/staging/2-remuxed/
  ✅ /mnt/staging/3-transcoded/
  ✅ /mnt/staging/4-ready/

CT303 Cannot Access:
  ❌ /mnt/storage/photos/
  ❌ /mnt/storage/backups/
  ❌ /mnt/storage/media/movies/ (final library)
  ❌ /mnt/storage/media/tv/
```

This follows the security pattern established in CT302 (ripper).

---

## Implementation Details

### IaC Components Created

#### 1. Terraform Configuration
**File**: `terraform/ct303-analyzer.tf`

**Features:**
- Container definition with static IP
- 2 cores, 4GB RAM, 12GB disk
- Restricted storage mount (`/mnt/staging`)
- Proper tags and lifecycle management

#### 2. Ansible Role: `media_analyzer`
**Location**: `ansible/roles/media_analyzer/`

**Responsibilities:**
- Install packages (mkvtoolnix, mediainfo, jq, bc, rsync)
- Optional FileBot installation
- Deploy 6 media scripts
- Configure environment variables
- Verify installation

**Scripts Deployed:**
1. `analyze-media.sh` - Media file analysis
2. `organize-and-remux-movie.sh` - Movie processing
3. `organize-and-remux-tv.sh` - TV show processing
4. `promote-to-ready.sh` - Pipeline promotion
5. `filebot-process.sh` - FileBot automation
6. `fix-current-names.sh` - Name fixing utility

#### 3. Ansible Playbook
**File**: `ansible/playbooks/ct303-analyzer.yml`

**Plays:**
1. Configure container (common + media_analyzer roles)
2. Verify deployment (check tools, scripts, mounts)

#### 4. Inventory Update
**File**: `ansible/inventory/hosts.yml`

Added `analyzer_containers` group with CT303 host.

---

## Media Pipeline Integration

### Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   CT302     │     │   CT303     │     │   CT201     │     │   CT303     │
│   Ripper    │ ──> │  Analyzer   │ ──> │ Transcoder  │ ──> │  Analyzer   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
      │                    │                    │                    │
      ↓                    ↓                    ↓                    ↓
  0-raw/              1-ripped/           2-remuxed/           3-transcoded/
  (discs)                │                                           │
                         ↓                                           ↓
                     ANALYZE                                     PROMOTE
                     ORGANIZE                                        ↓
                     REMUX                                      4-ready/
                                                                     │
                                                                     ↓
                                                              FileBot (opt)
                                                                     │
                                                                     ↓
                                                             library/movies/
                                                             library/tv/
```

### Analyzer Responsibilities

**Stage 1 → 2 (After Ripping):**
- Analyze ripped files from CT302
- Detect potential duplicates
- Categorize main features vs extras
- Remux to remove unwanted audio/subtitle tracks
- Output to `2-remuxed/` for transcoding

**Stage 3 → 4 (After Transcoding):**
- Promote transcoded files to `4-ready/`
- Prepare for library import

**Stage 4 → Library (Optional):**
- Use FileBot for automated organization
- Move to final library structure

---

## Deployment Process

### Prerequisites

1. ✅ Terraform initialized
2. ✅ Ansible configured
3. ✅ SSH access to containers
4. ⏳ CT202 stopped (optional, can run in parallel for testing)

### Step-by-Step Deployment

#### Step 1: Deploy with Terraform (5 minutes)

```bash
cd ~/dev/homelab-notes/terraform

# Preview changes
terraform plan -target=proxmox_virtual_environment_container.analyzer

# Deploy container
terraform apply -target=proxmox_virtual_environment_container.analyzer

# Verify output
# Expected: analyzer_container_id = 303
#           analyzer_container_ip = "192.168.1.73/24"
```

#### Step 2: Wait for Boot (1-2 minutes)

```bash
# Check container status
ssh root@192.168.1.56 "pct list | grep 303"

# Wait for SSH
until ssh -o ConnectTimeout=5 root@192.168.1.73 "echo ready" 2>/dev/null; do
  echo "Waiting for container..."
  sleep 5
done
```

#### Step 3: Configure with Ansible (3-5 minutes)

```bash
cd ~/dev/homelab-notes/ansible

# Test connectivity
ansible ct303 -m ping

# Deploy configuration
ansible-playbook playbooks/ct303-analyzer.yml

# Check output for errors
```

#### Step 4: Verify Deployment (2 minutes)

```bash
# Run verification tasks
ansible-playbook playbooks/ct303-analyzer.yml --tags verify

# Manual checks
ssh root@192.168.1.56 "pct enter 303"
su - media
ls -la ~/scripts/
mkvmerge --version
ls -la /mnt/staging/
```

---

## Testing Plan

### Phase 1: Tool Verification

```bash
pct enter 303
su - media

# Verify tools installed
mkvmerge --version        # Should show v74.0.0+
mediainfo --version       # Should show v23.04+
jq --version             # Should show v1.6+

# Verify mount accessible
ls -la /mnt/staging/
ls -la /mnt/staging/1-ripped/
```

### Phase 2: Script Testing

```bash
# Test analyze script
~/scripts/analyze-media.sh /mnt/staging/1-ripped/movies/<existing-movie>/

# Should show:
# - File listing with sizes/durations
# - Duplicate detection
# - Categorization (main features vs extras)
```

### Phase 3: Workflow Testing

**Test 1: Analyze existing ripped media**
```bash
~/scripts/analyze-media.sh /mnt/staging/1-ripped/movies/Movie_Name/
# Verify output looks correct
```

**Test 2: Remux a movie** (if safe to test)
```bash
# Pick a test movie folder
~/scripts/organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Test_Movie/
# Verify files created in /mnt/staging/2-remuxed/movies/Test_Movie/
```

**Test 3: Promote transcoded files** (if available)
```bash
~/scripts/promote-to-ready.sh /mnt/staging/3-transcoded/movies/Test_Movie/
# Verify files moved to /mnt/staging/4-ready/
```

### Phase 4: Parallel Testing

Run CT303 alongside CT202 for a validation period:
- Process new media through CT303
- Compare results with CT202
- Verify no issues with concurrent operation

---

## Migration Strategy

### Recommended Approach: Gradual Cutover

1. **Deploy CT303** (this week)
2. **Run in parallel with CT202** (1-2 weeks)
   - Use CT303 for new media
   - Keep CT202 as backup
   - Monitor for issues
3. **Update scripts/documentation** to use CT303
4. **Stop CT202** after validation period
5. **Archive CT202** (do not destroy immediately)
6. **Destroy CT202** after 1 month of stable operation

### Alternative: Immediate Cutover

If confident in testing:
1. Deploy CT303
2. Test thoroughly (all scripts)
3. Stop CT202 immediately
4. Use CT303 exclusively
5. Keep CT202 stopped for 1 week as rollback option

**Recommendation**: Use gradual approach for safety.

---

## Rollback Plan

If issues occur with CT303:

### Option 1: Roll Back to CT202

```bash
# Stop CT303
ssh root@192.168.1.56 "pct stop 303"

# Start CT202
ssh root@192.168.1.56 "pct start 202"

# Verify CT202 working
ssh root@192.168.1.72 "su - media -c 'ls ~/scripts/'"
```

### Option 2: Fix CT303 Issues

```bash
# Re-run Ansible to fix configuration
ansible-playbook playbooks/ct303-analyzer.yml

# Or manually fix specific issues
pct enter 303
# ... manual fixes ...
```

### Option 3: Destroy and Redeploy CT303

```bash
# Destroy container
cd terraform
terraform destroy -target=proxmox_virtual_environment_container.analyzer

# Redeploy from scratch
terraform apply -target=proxmox_virtual_environment_container.analyzer
ansible-playbook playbooks/ct303-analyzer.yml
```

---

## Documentation Created

### Deployment Guides
- **`docs/guides/ct303-analyzer-deployment.md`** - Complete deployment walkthrough

### Quick Reference
- **`docs/containers/ct303-analyzer.md`** - Operational documentation

### Planning Documents
- **`docs/plans/analyzer-container-migration-plan.md`** - This document

### IaC Definitions
- **`terraform/ct303-analyzer.tf`** - Terraform configuration
- **`ansible/playbooks/ct303-analyzer.yml`** - Ansible playbook
- **`ansible/roles/media_analyzer/`** - Ansible role

### Updated Documentation
- **`docs/containers/README.md`** - Added CT303 to index
- **`ansible/inventory/hosts.yml`** - Added CT303 host

---

## Success Criteria

CT303 migration is successful when:

- [x] IaC code created and tested
- [ ] Container deployed via Terraform
- [ ] Configuration applied via Ansible
- [ ] All 6 scripts deployed and executable
- [ ] All tools installed (mkvtoolnix, mediainfo, jq)
- [ ] Storage mount accessible
- [ ] analyze-media.sh runs successfully
- [ ] organize-and-remux-movie.sh works on test media
- [ ] No errors in verification playbook
- [ ] Documentation complete and accurate
- [ ] Can process media end-to-end
- [ ] Running stable for 1 week

---

## Timeline

### Week 1 (Current)
- [x] Create IaC code
- [x] Write documentation
- [ ] Deploy CT303
- [ ] Test basic functionality

### Week 2
- [ ] Run CT303 in parallel with CT202
- [ ] Process new media through CT303
- [ ] Monitor for issues
- [ ] Update any scripts if needed

### Week 3
- [ ] Full cutover to CT303
- [ ] Stop CT202
- [ ] Update all references

### Month 2
- [ ] Destroy CT202 after stable operation
- [ ] Mark migration complete

---

## Risk Assessment

### Low Risk
- ✅ Non-destructive deployment (new container, different IP)
- ✅ Can run in parallel with CT202
- ✅ Easy rollback to CT202
- ✅ Well-tested pattern from CT302

### Medium Risk
- ⚠️ Restricted storage mount (might break unexpected workflows)
- ⚠️ Script path changes if scripts reference full paths
- ⚠️ Environment variable differences

### Mitigation Strategies
- Run in parallel for validation period
- Test all scripts thoroughly before cutover
- Keep CT202 available for rollback
- Document any path/environment differences

---

## Lessons Learned (from CT302)

### What Worked Well
- ✅ Terraform + Ansible pattern
- ✅ Restricted storage mounts (security)
- ✅ Comprehensive documentation
- ✅ Verification tasks in playbook

### What to Improve
- 📝 Test with actual workload before declaring "production"
- 📝 Document expected behavior more clearly
- 📝 Add monitoring/alerting (future enhancement)

---

## Next Steps

1. **Deploy CT303**
   ```bash
   cd ~/dev/homelab-notes
   terraform apply -target=proxmox_virtual_environment_container.analyzer
   ansible-playbook ansible/playbooks/ct303-analyzer.yml
   ```

2. **Test thoroughly**
   - Run all scripts
   - Process test media
   - Verify output quality

3. **Run in parallel**
   - Use CT303 for new media
   - Monitor for issues

4. **Document any issues**
   - Update troubleshooting guide
   - Fix and re-deploy if needed

5. **Plan cutover**
   - After 1-2 weeks of stable operation
   - Stop CT202
   - Update references

---

## Related Documentation

- **Deployment Guide**: `docs/guides/ct303-analyzer-deployment.md`
- **Quick Reference**: `docs/containers/ct303-analyzer.md`
- **Terraform**: `terraform/ct303-analyzer.tf`
- **Ansible Playbook**: `ansible/playbooks/ct303-analyzer.yml`
- **Ansible Role**: `ansible/roles/media_analyzer/README.md`
- **Original Setup**: `docs/guides/ct202-analyzer-setup.md`
- **Media Pipeline**: `docs/reference/media-pipeline-quick-reference.md`
- **IaC Strategy**: `docs/reference/homelab-iac-strategy.md`

---

**Status**: ✅ Ready for deployment  
**Created**: 2025-11-11  
**Author**: Homelab IaC Migration Project
