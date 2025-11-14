# Media Pipeline Control Plane - Implementation Plan

This plan details the implementation of a Go-based control plane for the media pipeline, with state management, job orchestration, and interactive TUI using Bubbletea.

**Status:** Planning (Not Started)  
**Last Updated:** 2025-11-14

---

## Executive Summary

### Goals
1. **State Management** - Track media items through pipeline stages (ripped → remuxed → transcoded → library)
2. **Job Orchestration** - Coordinate work across containers (CT302 ripper, CT303 analyzer, CT304 transcoder)
3. **Interactive TUI** - Bubbletea-based interface for approvals and monitoring
4. **Automation** - Auto-progress items through pipeline with human approval gates
5. **Learning** - Gain experience with Go systems programming and Bubbletea

### Architecture Overview

```
┌─────────────────────────────────────────┐
│  Bubbletea TUI (Go)                     │
│  media-pipeline [status|approve|list]   │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│  Pipeline Controller (Go) - CT303       │
│  - State machine & SQLite DB            │
│  - Filesystem watchers (fsnotify)       │
│  - Job dispatcher (shared fs)           │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
    ┌───────┐ ┌───────┐ ┌───────┐
    │Worker │ │Worker │ │Worker │
    │CT302  │ │CT303  │ │CT304  │
    │ Rip   │ │ Remux │ │Trans  │
    └───────┘ └───────┘ └───────┘
         │         │         │
         └─────────┴─────────┘
                   │
           (Call bash scripts)
```

### Key Decisions

1. **Language:** Go (easier than Zig, more systemic than Python)
2. **State Storage:** Hybrid (filesystem markers + SQLite database)
3. **RPC Mechanism:** Shared filesystem (no network layer needed)
4. **Existing Scripts:** Keep unchanged (3-line completion markers added)
5. **Migration Path:** Zig rewrites possible later (worker binaries)

### Topology

- **CT303 (analyzer)** → Control plane (controller daemon, state DB)
- **CT302 (ripper)** → Worker node (rip jobs)
- **CT304 (transcoder)** → Worker node (transcode jobs)
- **CT303 (analyzer)** → Also runs remux tasks (lightweight, colocated with controller)

---

## Phase 1: Foundation & State Tracking (Week 1-2)

**Goal:** Basic Go project with SQLite database, read existing filesystem state

### 1.1 Project Setup

**Create Go project structure:**
```
media-pipeline/
├── cmd/
│   ├── controller/          # Daemon (runs on CT303)
│   │   └── main.go
│   ├── worker/             # Worker daemon (CT302, CT304)
│   │   └── main.go
│   └── media-pipeline/     # CLI/TUI tool
│       └── main.go
├── internal/
│   ├── state/              # Database layer
│   │   ├── db.go           # SQLite wrapper
│   │   ├── models.go       # Media item, transitions
│   │   └── migrations.go   # Schema management
│   ├── scanner/            # Filesystem scanner
│   │   └── scanner.go      # Read existing markers
│   └── config/
│       └── config.go       # YAML config
├── scripts/                # Existing bash (unchanged)
│   ├── rip-disc.sh
│   ├── organize-and-remux-movie.sh
│   ├── organize-and-remux-tv.sh
│   ├── transcode-queue.sh
│   └── filebot-process.sh
├── go.mod
├── go.sum
└── README.md
```

**Initialize project:**
```bash
cd /home/media
mkdir media-pipeline && cd media-pipeline
go mod init github.com/yourusername/media-pipeline

# Dependencies
go get github.com/mattn/go-sqlite3
go get github.com/charmbracelet/bubbletea
go get github.com/charmbracelet/lipgloss
go get github.com/charmbracelet/bubbles
go get gopkg.in/yaml.v3
```

### 1.2 Database Schema

**Create SQLite schema:**
```sql
-- internal/state/migrations/001_initial.sql

CREATE TABLE media_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,              -- 'movie' or 'tv'
    title TEXT NOT NULL,
    disc_label TEXT,                 -- 'S02 Disc1' for TV
    state TEXT NOT NULL,             -- 'RIPPED', 'REMUXED', 'TRANSCODED', 'IN_LIBRARY'
    folder_path TEXT,                -- Current location
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSON                    -- Flexible storage
);

CREATE TABLE state_transitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL,
    from_state TEXT,
    to_state TEXT NOT NULL,
    trigger TEXT NOT NULL,           -- 'auto', 'manual', 'approval'
    notes TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(item_id) REFERENCES media_items(id)
);

CREATE TABLE human_approvals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL,
    approval_type TEXT NOT NULL,     -- 'remux_review', 'filebot_confirm'
    status TEXT DEFAULT 'pending',   -- 'pending', 'approved', 'rejected'
    prompt_data JSON,                -- What to show user
    response_data JSON,              -- User's decision
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP,
    FOREIGN KEY(item_id) REFERENCES media_items(id)
);

CREATE INDEX idx_media_items_state ON media_items(state);
CREATE INDEX idx_media_items_path ON media_items(folder_path);
CREATE INDEX idx_approvals_status ON human_approvals(status);
```

### 1.3 Completion Markers in Scripts

**Minimal changes to existing bash scripts:**

Add to end of each script (3 lines):
```bash
# In organize-and-remux-movie.sh (after "✓ Complete!")
mkdir -p "$OUTPUT_DIR/.pipeline"
touch "$OUTPUT_DIR/.pipeline/remux.done"
date -Iseconds > "$OUTPUT_DIR/.pipeline/remux.timestamp"
```

**Scripts to update:**
- `rip-disc.sh` → creates `rip.done`
- `organize-and-remux-movie.sh` → creates `remux.done`
- `organize-and-remux-tv.sh` → creates `remux.done`
- `transcode-queue.sh` → creates `transcode.done`
- `filebot-process.sh` → creates `filebot.done`

**Marker format:**
```
/mnt/staging/2-remuxed/movies/Movie_Title/.pipeline/
  remux.done           # Signal completion (written by script)
  remux.timestamp      # When completed (written by script)
  state                # Current state (written by controller)
  metadata.json        # Rich data (written by controller)
```

### Phase 1 Deliverables

- [ ] Go project initialized with dependencies
- [ ] SQLite database with schema created
- [ ] Filesystem scanner reading existing items
- [ ] Basic CLI showing media items and states
- [ ] Completion markers added to bash scripts
- [ ] Database populated from filesystem scan
- [ ] Documentation of schema and patterns

**Testing:**
- Can scan existing staging directories
- Database correctly reflects filesystem state
- CLI displays items grouped by state
- Completion markers created when scripts run

---

## Phase 2: State Machine & Orchestration (Week 3-4)

**Goal:** Controller daemon that watches for changes and triggers transitions

### 2.1 Filesystem Watcher

**Use fsnotify to watch for completion markers**

### 2.2 State Machine Controller

**Implement state transitions and business logic**

### 2.3 Script Executor

**Wrapper to call bash scripts from Go**

### 2.4 Controller Daemon

**Main daemon process running on CT303**

### 2.5 Systemd Service

**Deploy as system service**

### Phase 2 Deliverables

- [ ] Filesystem watcher using fsnotify
- [ ] State machine with transition logic
- [ ] Script executor wrapper
- [ ] Controller daemon running on CT303
- [ ] Systemd service installed
- [ ] Auto-detection of completed scripts
- [ ] State markers written by controller

---

## Phase 3: Job Orchestration (Week 5-6)

**Goal:** Job queue system using shared filesystem for cross-container work

### 3.1 Job Queue Structure

**Filesystem-based job queue:**
```
/mnt/staging/.pipeline/jobs/
  pending/
    job_001_rip_MovieTitle_20251114_120000/
      spec.json
      state              # "PENDING"
      
  running/
    job_002_transcode_MovieTitle_20251114_120500/
      spec.json
      state              # "RUNNING"
      claimed_by         # "ct304"
      claimed_at         # "2025-11-14T12:05:00Z"
      pid                # "12345"
      
  completed/
    job_003_remux_MovieTitle_20251114_110000/
      spec.json
      state              # "COMPLETED"
      result.json
      completed_at       # "2025-11-14T11:15:00Z"
```

### 3.2 Job Dispatcher

**Controller creates jobs**

### 3.3 Worker Daemon

**Worker watches and claims jobs using atomic filesystem operations**

### 3.4 Worker Configuration

**Deploy workers on CT302 (ripper) and CT304 (transcoder)**

### 3.5 Controller Job Monitoring

**Controller watches completed jobs and updates state**

### Phase 3 Deliverables

- [ ] Job queue directory structure created
- [ ] Job dispatcher in controller
- [ ] Worker daemon implementation
- [ ] Workers deployed on CT302, CT304
- [ ] Controller monitoring job completions
- [ ] End-to-end job flow working
- [ ] Job cancellation support

---

## Phase 4: Bubbletea TUI (Week 7-8)

**Goal:** Interactive terminal UI for status monitoring and approvals

### 4.1 Status Dashboard

**Main view showing all items in a table**

### 4.2 Approval Interface

**Interactive approval for remux review and FileBot confirmation**

### 4.3 Main CLI Router

**Route commands to appropriate views**

### 4.4 Real-time Updates

**Make TUI reactive to state changes**

### Phase 4 Deliverables

- [ ] Status dashboard showing all items
- [ ] Approval interface for remux review
- [ ] Approval interface for FileBot confirm
- [ ] Real-time updates in TUI
- [ ] Keyboard navigation working
- [ ] Styled output with lipgloss

---

## Phase 5: Polish & Deployment (Week 9-10)

**Goal:** Production-ready deployment with docs and tooling

### 5.1 Configuration Management

**YAML config file**

### 5.2 Logging

**Structured logging to files**

### 5.3 Error Handling & Recovery

**Graceful degradation and recovery**

### 5.4 Deployment Automation

**Ansible role for deployment**

### 5.5 Build & Deploy Script

**Makefile for building and deploying**

### 5.6 Documentation

**User guide and admin documentation**

### Phase 5 Deliverables

- [ ] YAML configuration system
- [ ] Structured logging
- [ ] Error handling and recovery
- [ ] Ansible deployment role
- [ ] Build and deploy scripts
- [ ] User documentation
- [ ] Admin documentation

---

## Future Enhancements (Post-MVP)

### Zig Migration Path

**When ready to learn Zig, replace components incrementally:**

1. **File watcher in Zig** - High-performance inotify wrapper
2. **Worker binary in Zig** - Replace Go worker with Zig version
3. **Script rewrites** - Replace bash scripts with Zig binaries

**Integration:**
- Controller doesn't care if worker is Go or Zig
- Just dispatches jobs to filesystem queue
- Worker (Zig or Go) claims and executes
- No architecture changes needed!

### Additional Features

- **Web UI**: Bubbletea + web dashboard
- **Notifications**: ntfy.sh integration for approvals
- **Analytics**: Track processing times, compression ratios
- **Multi-worker**: Multiple transcode workers for parallel processing
- **Priority queue**: High-priority items jump queue
- **Scheduling**: Transcode only during off-peak hours

---

## Testing Strategy

### Unit Tests
- Database operations
- State transitions
- Job queue logic

### Integration Tests
- End-to-end pipeline flow
- Worker job claiming (test atomic operations)
- State synchronization

### Manual Testing Checklist

- [ ] Rip movie disc → auto-remux triggered
- [ ] Remux completes → approval requested
- [ ] Approve remux → transcode job created
- [ ] Worker claims transcode job
- [ ] Transcode completes → FileBot approval
- [ ] Approve FileBot → moved to library
- [ ] Check all state transitions logged
- [ ] Verify markers written correctly
- [ ] TUI displays current state
- [ ] Cancellation works

---

## Rollback Plan

### If Go Implementation Fails

**Fallback to manual workflow:**
1. Stop controller: `systemctl stop media-pipeline-controller`
2. Continue running bash scripts manually
3. Filesystem markers don't break anything
4. Database is just a cache, can be ignored

**Cleanup:**
```bash
# Remove Go binaries
rm /home/media/pipeline/bin/*

# Remove systemd services
sudo systemctl disable media-pipeline-controller
sudo rm /etc/systemd/system/media-pipeline-controller.service

# Keep database and markers for future retry
```

### If Zig Migration Fails

- Go implementation still works
- Revert to Go worker/components
- Zig was optional enhancement

---

## Success Criteria

After full implementation, the system should:

- ✅ Auto-detect script completions via filesystem markers
- ✅ Track all media items in SQLite database
- ✅ Dispatch jobs to appropriate workers (CT302, CT304)
- ✅ Request human approval at critical gates
- ✅ Provide interactive TUI for monitoring
- ✅ Run as systemd service on CT303
- ✅ Workers running on CT302, CT304
- ✅ Bash scripts unchanged (just 3-line markers added)
- ✅ Clean migration path to Zig later
- ✅ Comprehensive logging and error handling

---

## Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1 | 2 weeks | Foundation, state tracking, basic CLI |
| Phase 2 | 2 weeks | Controller daemon, state machine |
| Phase 3 | 2 weeks | Job orchestration, workers |
| Phase 4 | 2 weeks | Bubbletea TUI |
| Phase 5 | 2 weeks | Polish, deployment, docs |
| **Total** | **10 weeks** | Production-ready control plane |

---

## Resources

### Go Learning
- Official Tour: https://go.dev/tour/
- Effective Go: https://go.dev/doc/effective_go
- Go by Example: https://gobyexample.com

### Libraries
- Bubbletea: https://github.com/charmbracelet/bubbletea
- Bubbletea Tutorials: https://github.com/charmbracelet/bubbletea/tree/master/tutorials
- fsnotify: https://github.com/fsnotify/fsnotify
- go-sqlite3: https://github.com/mattn/go-sqlite3
- Lipgloss (styling): https://github.com/charmbracelet/lipgloss
- Bubbles (components): https://github.com/charmbracelet/bubbles

### Zig (Future)
- Zig Learn: https://ziglearn.org
- Zig Documentation: https://ziglang.org/documentation/

---

## Key Architectural Decisions

### Why Hybrid State Management?

**Filesystem markers** (authoritative):
- Scripts write completion markers
- Survives controller crashes
- Works without controller running
- Easy debugging: `cat .pipeline/state`

**SQLite database** (cache + history):
- Fast queries for TUI
- Rich history and analytics
- Relationships (TV season tracking)
- Can be rebuilt from markers

### Why Filesystem for RPC?

**Instead of HTTP/gRPC:**
- No network configuration needed
- Atomic operations (rename) prevent races
- Works over shared NFS/CIFS mount
- Auditable (can see jobs in filesystem)
- No ports, no firewall rules
- Simple debugging

**Tradeoffs:**
- Slight polling delay (or use inotify for instant)
- Not suitable for high-frequency jobs (fine for media)
- Requires shared filesystem (already have it)

### Why Go over Python/Zig?

**vs Python:**
- More "systems programming" feel
- Single binary deployment
- Better Bubbletea experience
- Easier path to Zig later

**vs Zig from start:**
- 3x faster development
- Mature ecosystem
- Still learning systems concepts
- Can migrate to Zig incrementally

---

## Notes

- This plan is iterative - adjust as you learn
- Each phase builds on previous, but can be paused
- MVP is Phase 1-3 (state + orchestration)
- Phases 4-5 are UX polish
- Zig migration is optional future work
- Keep existing bash scripts working throughout
- Focus on learning Go and systems programming
- Bubbletea makes it fun and visual

---

**Last Updated:** 2025-11-14
