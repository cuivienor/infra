# Media Pipeline

Go + Bubbletea TUI for monitoring media ripping pipeline. Reads state from filesystem.

## COMMANDS

```bash
make build-local   # Dev build
make build         # Linux production
make test          # Unit tests
make test-all      # Unit + contract + E2E
make deploy        # SCP to analyzer container
make run           # Build + deploy + run
```

## ARCHITECTURE

**Pipeline:** Rip → Remux → Transcode → Publish (FileBot)

Each stage creates state dir (`.rip/`, `.remux/`, etc.) with:
- `metadata.json` - Job metadata
- `status` - pending/in_progress/completed/failed
- `*.log` - Processing logs

## CODE STRUCTURE

| Path | Purpose |
|------|---------|
| `internal/model/` | Domain types (Stage, Status, MediaItem) |
| `internal/db/` | SQLite repository pattern |
| `internal/ripper/` | MakeMKV integration |
| `internal/transcode/` | FFmpeg + queue processing |
| `internal/tui/` | Bubbletea views |
| `cmd/media-pipeline/` | Main entry |
| `cmd/mock-makemkv/` | Test mock binary |

## TESTING

- **Unit:** `*_test.go` alongside source
- **Contract:** `internal/pipeline/contracts/` - stage invariants
- **E2E:** `tests/e2e/` - full workflow with mocks
- **Utilities:** `internal/testutil/`

Pattern: Table-driven tests, dependency injection via interfaces.

## TUI NAVIGATION

| View | Description |
|------|-------------|
| Overview | Bar chart per stage |
| StageList | Items at stage |
| ActionNeeded | Grouped by status |
| ItemDetail | Single item details |

Keys: Enter=drill, Esc=back, Tab=toggle view, r=refresh, q=quit

## FILESYSTEM (Production)

```
/mnt/media/staging/{1-ripped,2-remuxed,3-transcoded}/{movies,tv}/
/mnt/media/library/{movies,tv}/
```

## CONVENTIONS

- Standard Go fmt/vet
- Error handling: `if err != nil { return ... }`
- Dependency injection for testability
- CGO-free SQLite (modernc.org/sqlite)
