# Transcode Stage Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement H.265 video transcoding with ffmpeg, supporting both software (libx265) and hardware (Intel QSV) encoding, with per-file progress tracking and resume capability.

**Architecture:** The transcode stage processes MKV files from `staging/2-remuxed/` to `staging/3-transcoded/`, re-encoding video to H.265 while copying audio/subtitles. A new `transcode_files` table tracks per-file status and progress. ffmpeg progress is parsed from stderr to update percentage in real-time.

**Tech Stack:** Go, ffmpeg, ffprobe, SQLite, existing logging/config packages

---

## Task 1: Add Transcode Config

Add transcode configuration to the config package with defaults that can be overridden per-job.

**Files:**
- Modify: `internal/config/config.go`
- Modify: `internal/config/config_test.go`

**Step 1: Add TranscodeConfig struct to config.go**

Add after the RemuxConfig struct (around line 20):

```go
// TranscodeConfig holds transcode-specific configuration
type TranscodeConfig struct {
	CRF      int    `yaml:"crf"`       // Quality (0-51, default 20)
	Mode     string `yaml:"mode"`      // "software" or "hardware"
	Preset   string `yaml:"preset"`    // libx265 preset (default "slow")
	HWPreset string `yaml:"hw_preset"` // QSV preset (default "medium")
}
```

**Step 2: Add Transcode field to Config struct**

Add to the Config struct (around line 27):

```go
Transcode TranscodeConfig `yaml:"transcode"` // Transcode configuration
```

**Step 3: Add accessor methods**

Add after RemuxLanguages() method:

```go
// TranscodeCRF returns the CRF value for transcoding
// Defaults to 20 if not configured
func (c *Config) TranscodeCRF() int {
	if c.Transcode.CRF == 0 {
		return 20
	}
	return c.Transcode.CRF
}

// TranscodeMode returns the encoding mode ("software" or "hardware")
// Defaults to "software" if not configured
func (c *Config) TranscodeMode() string {
	if c.Transcode.Mode == "" {
		return "software"
	}
	return c.Transcode.Mode
}

// TranscodePreset returns the libx265 preset
// Defaults to "slow" if not configured
func (c *Config) TranscodePreset() string {
	if c.Transcode.Preset == "" {
		return "slow"
	}
	return c.Transcode.Preset
}

// TranscodeHWPreset returns the QSV preset
// Defaults to "medium" if not configured
func (c *Config) TranscodeHWPreset() string {
	if c.Transcode.HWPreset == "" {
		return "medium"
	}
	return c.Transcode.HWPreset
}
```

**Step 4: Add tests to config_test.go**

Add a new test function:

```go
func TestConfig_TranscodeDefaults(t *testing.T) {
	cfg := &Config{}

	if got := cfg.TranscodeCRF(); got != 20 {
		t.Errorf("TranscodeCRF() = %d, want 20", got)
	}
	if got := cfg.TranscodeMode(); got != "software" {
		t.Errorf("TranscodeMode() = %q, want %q", got, "software")
	}
	if got := cfg.TranscodePreset(); got != "slow" {
		t.Errorf("TranscodePreset() = %q, want %q", got, "slow")
	}
	if got := cfg.TranscodeHWPreset(); got != "medium" {
		t.Errorf("TranscodeHWPreset() = %q, want %q", got, "medium")
	}
}

func TestConfig_TranscodeCustom(t *testing.T) {
	cfg := &Config{
		Transcode: TranscodeConfig{
			CRF:      18,
			Mode:     "hardware",
			Preset:   "medium",
			HWPreset: "fast",
		},
	}

	if got := cfg.TranscodeCRF(); got != 18 {
		t.Errorf("TranscodeCRF() = %d, want 18", got)
	}
	if got := cfg.TranscodeMode(); got != "hardware" {
		t.Errorf("TranscodeMode() = %q, want %q", got, "hardware")
	}
	if got := cfg.TranscodePreset(); got != "medium" {
		t.Errorf("TranscodePreset() = %q, want %q", got, "medium")
	}
	if got := cfg.TranscodeHWPreset(); got != "fast" {
		t.Errorf("TranscodeHWPreset() = %q, want %q", got, "fast")
	}
}
```

**Step 5: Run tests**

```bash
go test ./internal/config/... -v
```

Expected: All tests pass

**Step 6: Commit**

```bash
git add internal/config/config.go internal/config/config_test.go
git commit -m "config: add transcode configuration"
```

---

## Task 2: Database Migration for Transcode Files

Add migration for the `transcode_files` table and `options` column on jobs.

**Files:**
- Create: `internal/db/migrations/004_transcode.sql`

**Step 1: Create migration file**

```sql
-- File: internal/db/migrations/004_transcode.sql
-- Transcode support: per-file tracking and job options

-- Create transcode_files table for per-file progress tracking
CREATE TABLE IF NOT EXISTS transcode_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    relative_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'skipped')),
    input_size INTEGER,
    output_size INTEGER,
    progress INTEGER DEFAULT 0,
    duration_secs REAL,
    started_at TEXT,
    completed_at TEXT,
    error_message TEXT,
    UNIQUE(job_id, relative_path)
);

CREATE INDEX IF NOT EXISTS idx_transcode_files_job ON transcode_files(job_id);
CREATE INDEX IF NOT EXISTS idx_transcode_files_status ON transcode_files(status);

-- Add options column to jobs table for per-job configuration overrides
-- Stores JSON: {"crf": 18, "mode": "hardware"}
ALTER TABLE jobs ADD COLUMN options TEXT;
```

**Step 2: Run migration test**

```bash
go test ./internal/db/... -v -run TestMigrations
```

Expected: Migration applies successfully

**Step 3: Commit**

```bash
git add internal/db/migrations/004_transcode.sql
git commit -m "db: add transcode_files table and job options column"
```

---

## Task 3: Transcode File Model and Repository

Add the TranscodeFile model and repository methods.

**Files:**
- Create: `internal/model/transcode_file.go`
- Modify: `internal/db/repository.go`
- Modify: `internal/db/sqlite.go`

**Step 1: Create transcode_file.go model**

```go
package model

import "time"

// TranscodeFileStatus represents the status of a file being transcoded
type TranscodeFileStatus string

const (
	TranscodeFileStatusPending    TranscodeFileStatus = "pending"
	TranscodeFileStatusInProgress TranscodeFileStatus = "in_progress"
	TranscodeFileStatusCompleted  TranscodeFileStatus = "completed"
	TranscodeFileStatusFailed     TranscodeFileStatus = "failed"
	TranscodeFileStatusSkipped    TranscodeFileStatus = "skipped"
)

// TranscodeFile tracks the status of a single file within a transcode job
type TranscodeFile struct {
	ID           int64
	JobID        int64
	RelativePath string
	Status       TranscodeFileStatus
	InputSize    int64
	OutputSize   int64
	Progress     int // 0-100 percentage
	DurationSecs float64
	StartedAt    *time.Time
	CompletedAt  *time.Time
	ErrorMessage string
}

// SizeSaved returns bytes saved (input - output)
func (f *TranscodeFile) SizeSaved() int64 {
	return f.InputSize - f.OutputSize
}

// CompressionRatio returns the output/input ratio (lower is better compression)
func (f *TranscodeFile) CompressionRatio() float64 {
	if f.InputSize == 0 {
		return 0
	}
	return float64(f.OutputSize) / float64(f.InputSize)
}
```

**Step 2: Add repository interface methods**

Add to `internal/db/repository.go` in the Repository interface:

```go
	// Transcode files
	CreateTranscodeFile(ctx context.Context, file *model.TranscodeFile) error
	GetTranscodeFile(ctx context.Context, id int64) (*model.TranscodeFile, error)
	ListTranscodeFiles(ctx context.Context, jobID int64) ([]model.TranscodeFile, error)
	UpdateTranscodeFile(ctx context.Context, file *model.TranscodeFile) error
	UpdateTranscodeFileProgress(ctx context.Context, id int64, progress int) error
	UpdateTranscodeFileStatus(ctx context.Context, id int64, status model.TranscodeFileStatus, errorMsg string) error

	// Job options
	GetJobOptions(ctx context.Context, jobID int64) (map[string]interface{}, error)
	SetJobOptions(ctx context.Context, jobID int64, options map[string]interface{}) error
```

**Step 3: Implement repository methods in sqlite.go**

Add at the end of the file:

```go
// CreateTranscodeFile creates a new transcode file record
func (r *SQLiteRepository) CreateTranscodeFile(ctx context.Context, file *model.TranscodeFile) error {
	query := `
		INSERT INTO transcode_files (job_id, relative_path, status, input_size, duration_secs)
		VALUES (?, ?, ?, ?, ?)
	`
	result, err := r.db.db.ExecContext(ctx, query,
		file.JobID,
		file.RelativePath,
		file.Status,
		file.InputSize,
		file.DurationSecs,
	)
	if err != nil {
		return fmt.Errorf("failed to create transcode file: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("failed to get last insert id: %w", err)
	}
	file.ID = id
	return nil
}

// GetTranscodeFile retrieves a transcode file by ID
func (r *SQLiteRepository) GetTranscodeFile(ctx context.Context, id int64) (*model.TranscodeFile, error) {
	query := `
		SELECT id, job_id, relative_path, status, input_size, output_size,
		       progress, duration_secs, started_at, completed_at, error_message
		FROM transcode_files
		WHERE id = ?
	`
	var file model.TranscodeFile
	var startedAt, completedAt sql.NullString
	var outputSize sql.NullInt64
	var errorMsg sql.NullString

	err := r.db.db.QueryRowContext(ctx, query, id).Scan(
		&file.ID,
		&file.JobID,
		&file.RelativePath,
		&file.Status,
		&file.InputSize,
		&outputSize,
		&file.Progress,
		&file.DurationSecs,
		&startedAt,
		&completedAt,
		&errorMsg,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get transcode file: %w", err)
	}

	if outputSize.Valid {
		file.OutputSize = outputSize.Int64
	}
	if startedAt.Valid {
		if t, err := time.Parse(time.RFC3339, startedAt.String); err == nil {
			file.StartedAt = &t
		}
	}
	if completedAt.Valid {
		if t, err := time.Parse(time.RFC3339, completedAt.String); err == nil {
			file.CompletedAt = &t
		}
	}
	if errorMsg.Valid {
		file.ErrorMessage = errorMsg.String
	}

	return &file, nil
}

// ListTranscodeFiles lists all transcode files for a job
func (r *SQLiteRepository) ListTranscodeFiles(ctx context.Context, jobID int64) ([]model.TranscodeFile, error) {
	query := `
		SELECT id, job_id, relative_path, status, input_size, output_size,
		       progress, duration_secs, started_at, completed_at, error_message
		FROM transcode_files
		WHERE job_id = ?
		ORDER BY relative_path
	`
	rows, err := r.db.db.QueryContext(ctx, query, jobID)
	if err != nil {
		return nil, fmt.Errorf("failed to list transcode files: %w", err)
	}
	defer rows.Close()

	var files []model.TranscodeFile
	for rows.Next() {
		var file model.TranscodeFile
		var startedAt, completedAt sql.NullString
		var outputSize sql.NullInt64
		var errorMsg sql.NullString

		if err := rows.Scan(
			&file.ID,
			&file.JobID,
			&file.RelativePath,
			&file.Status,
			&file.InputSize,
			&outputSize,
			&file.Progress,
			&file.DurationSecs,
			&startedAt,
			&completedAt,
			&errorMsg,
		); err != nil {
			return nil, fmt.Errorf("failed to scan transcode file: %w", err)
		}

		if outputSize.Valid {
			file.OutputSize = outputSize.Int64
		}
		if startedAt.Valid {
			if t, err := time.Parse(time.RFC3339, startedAt.String); err == nil {
				file.StartedAt = &t
			}
		}
		if completedAt.Valid {
			if t, err := time.Parse(time.RFC3339, completedAt.String); err == nil {
				file.CompletedAt = &t
			}
		}
		if errorMsg.Valid {
			file.ErrorMessage = errorMsg.String
		}

		files = append(files, file)
	}

	return files, rows.Err()
}

// UpdateTranscodeFile updates a transcode file record
func (r *SQLiteRepository) UpdateTranscodeFile(ctx context.Context, file *model.TranscodeFile) error {
	query := `
		UPDATE transcode_files
		SET status = ?, input_size = ?, output_size = ?, progress = ?,
		    duration_secs = ?, started_at = ?, completed_at = ?, error_message = ?
		WHERE id = ?
	`
	var startedAt, completedAt *string
	if file.StartedAt != nil {
		s := file.StartedAt.UTC().Format(time.RFC3339)
		startedAt = &s
	}
	if file.CompletedAt != nil {
		s := file.CompletedAt.UTC().Format(time.RFC3339)
		completedAt = &s
	}

	_, err := r.db.db.ExecContext(ctx, query,
		file.Status,
		file.InputSize,
		file.OutputSize,
		file.Progress,
		file.DurationSecs,
		startedAt,
		completedAt,
		file.ErrorMessage,
		file.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update transcode file: %w", err)
	}
	return nil
}

// UpdateTranscodeFileProgress updates just the progress percentage
func (r *SQLiteRepository) UpdateTranscodeFileProgress(ctx context.Context, id int64, progress int) error {
	query := `UPDATE transcode_files SET progress = ? WHERE id = ?`
	_, err := r.db.db.ExecContext(ctx, query, progress, id)
	if err != nil {
		return fmt.Errorf("failed to update transcode file progress: %w", err)
	}
	return nil
}

// UpdateTranscodeFileStatus updates status and optionally error message
func (r *SQLiteRepository) UpdateTranscodeFileStatus(ctx context.Context, id int64, status model.TranscodeFileStatus, errorMsg string) error {
	now := time.Now().UTC().Format(time.RFC3339)

	var query string
	var args []interface{}

	if status == model.TranscodeFileStatusInProgress {
		query = `UPDATE transcode_files SET status = ?, started_at = ? WHERE id = ?`
		args = []interface{}{status, now, id}
	} else if status == model.TranscodeFileStatusCompleted || status == model.TranscodeFileStatusFailed {
		query = `UPDATE transcode_files SET status = ?, completed_at = ?, error_message = ? WHERE id = ?`
		args = []interface{}{status, now, errorMsg, id}
	} else {
		query = `UPDATE transcode_files SET status = ?, error_message = ? WHERE id = ?`
		args = []interface{}{status, errorMsg, id}
	}

	_, err := r.db.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update transcode file status: %w", err)
	}
	return nil
}

// GetJobOptions retrieves the JSON options for a job
func (r *SQLiteRepository) GetJobOptions(ctx context.Context, jobID int64) (map[string]interface{}, error) {
	query := `SELECT options FROM jobs WHERE id = ?`
	var optionsJSON sql.NullString

	err := r.db.db.QueryRowContext(ctx, query, jobID).Scan(&optionsJSON)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get job options: %w", err)
	}

	if !optionsJSON.Valid || optionsJSON.String == "" {
		return nil, nil
	}

	var options map[string]interface{}
	if err := json.Unmarshal([]byte(optionsJSON.String), &options); err != nil {
		return nil, fmt.Errorf("failed to parse job options: %w", err)
	}

	return options, nil
}

// SetJobOptions sets the JSON options for a job
func (r *SQLiteRepository) SetJobOptions(ctx context.Context, jobID int64, options map[string]interface{}) error {
	optionsJSON, err := json.Marshal(options)
	if err != nil {
		return fmt.Errorf("failed to marshal job options: %w", err)
	}

	query := `UPDATE jobs SET options = ? WHERE id = ?`
	_, err = r.db.db.ExecContext(ctx, query, string(optionsJSON), jobID)
	if err != nil {
		return fmt.Errorf("failed to set job options: %w", err)
	}
	return nil
}
```

**Step 4: Add json import to sqlite.go**

Add `"encoding/json"` to the imports at the top of sqlite.go.

**Step 5: Run tests**

```bash
go test ./internal/db/... -v
go test ./internal/model/... -v
```

Expected: All tests pass

**Step 6: Commit**

```bash
git add internal/model/transcode_file.go internal/db/repository.go internal/db/sqlite.go
git commit -m "db: add TranscodeFile model and repository methods"
```

---

## Task 4: Repository Tests for Transcode Files

Add tests for the new repository methods.

**Files:**
- Modify: `internal/db/sqlite_test.go`

**Step 1: Add transcode file tests**

```go
func TestSQLiteRepository_TranscodeFiles(t *testing.T) {
	db := setupTestDB(t)
	repo := NewSQLiteRepository(db)
	ctx := context.Background()

	// Create media item and job
	item := &model.MediaItem{
		Type:     model.MediaTypeMovie,
		Name:     "Test Movie",
		SafeName: "Test_Movie",
	}
	if err := repo.CreateMediaItem(ctx, item); err != nil {
		t.Fatalf("failed to create media item: %v", err)
	}

	job := &model.Job{
		MediaItemID: item.ID,
		Stage:       model.StageTranscode,
		Status:      model.JobStatusInProgress,
	}
	if err := repo.CreateJob(ctx, job); err != nil {
		t.Fatalf("failed to create job: %v", err)
	}

	// Test CreateTranscodeFile
	file := &model.TranscodeFile{
		JobID:        job.ID,
		RelativePath: "_main/movie.mkv",
		Status:       model.TranscodeFileStatusPending,
		InputSize:    1024 * 1024 * 1024, // 1GB
		DurationSecs: 7200.5,
	}
	if err := repo.CreateTranscodeFile(ctx, file); err != nil {
		t.Fatalf("CreateTranscodeFile failed: %v", err)
	}
	if file.ID == 0 {
		t.Error("expected file ID to be set")
	}

	// Test GetTranscodeFile
	got, err := repo.GetTranscodeFile(ctx, file.ID)
	if err != nil {
		t.Fatalf("GetTranscodeFile failed: %v", err)
	}
	if got.RelativePath != "_main/movie.mkv" {
		t.Errorf("RelativePath = %q, want %q", got.RelativePath, "_main/movie.mkv")
	}
	if got.InputSize != 1024*1024*1024 {
		t.Errorf("InputSize = %d, want %d", got.InputSize, 1024*1024*1024)
	}

	// Test UpdateTranscodeFileProgress
	if err := repo.UpdateTranscodeFileProgress(ctx, file.ID, 50); err != nil {
		t.Fatalf("UpdateTranscodeFileProgress failed: %v", err)
	}
	got, _ = repo.GetTranscodeFile(ctx, file.ID)
	if got.Progress != 50 {
		t.Errorf("Progress = %d, want 50", got.Progress)
	}

	// Test UpdateTranscodeFileStatus
	if err := repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusInProgress, ""); err != nil {
		t.Fatalf("UpdateTranscodeFileStatus failed: %v", err)
	}
	got, _ = repo.GetTranscodeFile(ctx, file.ID)
	if got.Status != model.TranscodeFileStatusInProgress {
		t.Errorf("Status = %v, want in_progress", got.Status)
	}
	if got.StartedAt == nil {
		t.Error("expected StartedAt to be set")
	}

	// Test ListTranscodeFiles
	file2 := &model.TranscodeFile{
		JobID:        job.ID,
		RelativePath: "_extras/extra.mkv",
		Status:       model.TranscodeFileStatusPending,
		InputSize:    500 * 1024 * 1024,
		DurationSecs: 1800.0,
	}
	repo.CreateTranscodeFile(ctx, file2)

	files, err := repo.ListTranscodeFiles(ctx, job.ID)
	if err != nil {
		t.Fatalf("ListTranscodeFiles failed: %v", err)
	}
	if len(files) != 2 {
		t.Errorf("got %d files, want 2", len(files))
	}

	// Test UpdateTranscodeFile (full update)
	file.Status = model.TranscodeFileStatusCompleted
	file.OutputSize = 500 * 1024 * 1024 // 500MB
	file.Progress = 100
	now := time.Now()
	file.CompletedAt = &now
	if err := repo.UpdateTranscodeFile(ctx, file); err != nil {
		t.Fatalf("UpdateTranscodeFile failed: %v", err)
	}
	got, _ = repo.GetTranscodeFile(ctx, file.ID)
	if got.OutputSize != 500*1024*1024 {
		t.Errorf("OutputSize = %d, want %d", got.OutputSize, 500*1024*1024)
	}
}

func TestSQLiteRepository_JobOptions(t *testing.T) {
	db := setupTestDB(t)
	repo := NewSQLiteRepository(db)
	ctx := context.Background()

	// Create media item and job
	item := &model.MediaItem{
		Type:     model.MediaTypeMovie,
		Name:     "Test Movie",
		SafeName: "Test_Movie",
	}
	repo.CreateMediaItem(ctx, item)

	job := &model.Job{
		MediaItemID: item.ID,
		Stage:       model.StageTranscode,
		Status:      model.JobStatusPending,
	}
	repo.CreateJob(ctx, job)

	// Test GetJobOptions (initially nil)
	opts, err := repo.GetJobOptions(ctx, job.ID)
	if err != nil {
		t.Fatalf("GetJobOptions failed: %v", err)
	}
	if opts != nil {
		t.Errorf("expected nil options, got %v", opts)
	}

	// Test SetJobOptions
	options := map[string]interface{}{
		"crf":  float64(18),
		"mode": "hardware",
	}
	if err := repo.SetJobOptions(ctx, job.ID, options); err != nil {
		t.Fatalf("SetJobOptions failed: %v", err)
	}

	// Verify
	opts, err = repo.GetJobOptions(ctx, job.ID)
	if err != nil {
		t.Fatalf("GetJobOptions failed: %v", err)
	}
	if opts["mode"] != "hardware" {
		t.Errorf("mode = %v, want hardware", opts["mode"])
	}
	if opts["crf"] != float64(18) {
		t.Errorf("crf = %v, want 18", opts["crf"])
	}
}
```

**Step 2: Run tests**

```bash
go test ./internal/db/... -v -run TestSQLiteRepository_TranscodeFiles
go test ./internal/db/... -v -run TestSQLiteRepository_JobOptions
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add internal/db/sqlite_test.go
git commit -m "db: add transcode file and job options tests"
```

---

## Task 5: ffprobe Duration Parser

Create ffprobe wrapper to get video duration.

**Files:**
- Create: `internal/transcode/ffprobe.go`
- Create: `internal/transcode/ffprobe_test.go`

**Step 1: Create ffprobe.go**

```go
package transcode

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

// GetDuration returns the duration of a media file in seconds
func GetDuration(inputPath string) (float64, error) {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-show_entries", "format=duration",
		"-of", "csv=p=0",
		inputPath,
	)

	output, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return 0, fmt.Errorf("ffprobe failed: %s", string(exitErr.Stderr))
		}
		return 0, fmt.Errorf("ffprobe failed: %w", err)
	}

	durationStr := strings.TrimSpace(string(output))
	if durationStr == "" || durationStr == "N/A" {
		return 0, fmt.Errorf("could not determine duration")
	}

	duration, err := strconv.ParseFloat(durationStr, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse duration %q: %w", durationStr, err)
	}

	return duration, nil
}

// CheckHardwareSupport checks if Intel QSV is available
func CheckHardwareSupport() error {
	cmd := exec.Command("ffmpeg",
		"-hide_banner",
		"-init_hw_device", "qsv=hw",
		"-f", "lavfi",
		"-i", "nullsrc=s=256x256:d=1",
		"-vf", "hwupload=extra_hw_frames=64,format=qsv",
		"-c:v", "hevc_qsv",
		"-f", "null",
		"-",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("QSV not available: %s", strings.TrimSpace(string(output)))
	}

	return nil
}
```

**Step 2: Create ffprobe_test.go (integration test)**

```go
package transcode

import (
	"os/exec"
	"testing"
)

func TestGetDuration_Integration(t *testing.T) {
	// Skip if ffprobe not available
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not available")
	}

	// This test requires a real MKV file
	// In practice, use a test fixture or skip in CI
	t.Skip("requires test fixture")
}

func TestCheckHardwareSupport(t *testing.T) {
	// Skip if ffmpeg not available
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not available")
	}

	err := CheckHardwareSupport()
	// Just log the result - don't fail if QSV not available
	if err != nil {
		t.Logf("QSV not available: %v", err)
	} else {
		t.Log("QSV is available")
	}
}
```

**Step 3: Run tests**

```bash
go test ./internal/transcode/... -v
```

Expected: Tests pass (may skip hardware test)

**Step 4: Commit**

```bash
git add internal/transcode/ffprobe.go internal/transcode/ffprobe_test.go
git commit -m "transcode: add ffprobe duration parser"
```

---

## Task 6: ffmpeg Runner with Progress Parsing

Create ffmpeg wrapper that parses progress from stderr.

**Files:**
- Create: `internal/transcode/ffmpeg.go`
- Create: `internal/transcode/ffmpeg_test.go`

**Step 1: Create ffmpeg.go**

```go
package transcode

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// TranscodeOptions configures the transcoding operation
type TranscodeOptions struct {
	CRF         int
	Mode        string // "software" or "hardware"
	Preset      string // libx265 preset
	HWPreset    string // QSV preset
	DurationSec float64
}

// ProgressCallback is called with progress updates (0-100)
type ProgressCallback func(percent int)

// timeRegex matches ffmpeg's time= output
var timeRegex = regexp.MustCompile(`time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})`)

// TranscodeFile transcodes a single file using ffmpeg
func TranscodeFile(ctx context.Context, inputPath, outputPath string, opts TranscodeOptions, onProgress ProgressCallback) error {
	// Ensure output directory exists
	if err := os.MkdirAll(outputPath[:len(outputPath)-len("/"+inputPath[strings.LastIndex(inputPath, "/")+1:])], 0755); err != nil {
		// Ignore - will fail on ffmpeg if dir doesn't exist
	}

	args := buildFFmpegArgs(inputPath, outputPath, opts)

	cmd := exec.CommandContext(ctx, "ffmpeg", args...)

	// ffmpeg writes progress to stderr
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to get stderr pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start ffmpeg: %w", err)
	}

	// Parse progress from stderr
	lastPercent := 0
	scanner := bufio.NewScanner(stderr)
	scanner.Split(scanFFmpegLines)

	for scanner.Scan() {
		line := scanner.Text()
		if percent := parseProgress(line, opts.DurationSec); percent > lastPercent {
			lastPercent = percent
			if onProgress != nil {
				onProgress(percent)
			}
		}
	}

	if err := cmd.Wait(); err != nil {
		// Clean up partial output
		os.Remove(outputPath)
		if exitErr, ok := err.(*exec.ExitError); ok {
			return fmt.Errorf("ffmpeg failed with exit code %d", exitErr.ExitCode())
		}
		return fmt.Errorf("ffmpeg failed: %w", err)
	}

	// Final progress update
	if onProgress != nil && lastPercent < 100 {
		onProgress(100)
	}

	return nil
}

// buildFFmpegArgs constructs the ffmpeg command arguments
func buildFFmpegArgs(inputPath, outputPath string, opts TranscodeOptions) []string {
	var args []string

	// Common input args
	args = append(args, "-nostdin", "-y")

	if opts.Mode == "hardware" {
		// Intel QSV hardware encoding
		args = append(args,
			"-hwaccel", "qsv",
			"-hwaccel_output_format", "qsv",
			"-i", inputPath,
			"-c:v", "hevc_qsv",
			"-preset", opts.HWPreset,
			"-global_quality", strconv.Itoa(opts.CRF),
		)
	} else {
		// Software encoding (libx265)
		args = append(args,
			"-i", inputPath,
			"-map", "0:v:0",
			"-map", "0:a",
			"-map", "0:s?",
			"-c:v", "libx265",
			"-preset", opts.Preset,
			"-crf", strconv.Itoa(opts.CRF),
		)
	}

	// Common output args: copy audio and subtitles
	args = append(args,
		"-c:a", "copy",
		"-c:s", "copy",
		outputPath,
	)

	return args
}

// parseProgress extracts progress percentage from ffmpeg output
func parseProgress(line string, totalDuration float64) int {
	if totalDuration <= 0 {
		return 0
	}

	matches := timeRegex.FindStringSubmatch(line)
	if matches == nil {
		return 0
	}

	hours, _ := strconv.Atoi(matches[1])
	minutes, _ := strconv.Atoi(matches[2])
	seconds, _ := strconv.Atoi(matches[3])
	centisecs, _ := strconv.Atoi(matches[4])

	currentSecs := float64(hours*3600+minutes*60+seconds) + float64(centisecs)/100.0
	percent := int((currentSecs / totalDuration) * 100)

	if percent > 100 {
		percent = 100
	}

	return percent
}

// scanFFmpegLines is a split function for bufio.Scanner that handles ffmpeg's CR-delimited progress output
func scanFFmpegLines(data []byte, atEOF bool) (advance int, token []byte, err error) {
	if atEOF && len(data) == 0 {
		return 0, nil, nil
	}

	// Look for CR (carriage return) which ffmpeg uses for progress updates
	if i := strings.IndexAny(string(data), "\r\n"); i >= 0 {
		return i + 1, data[0:i], nil
	}

	if atEOF {
		return len(data), data, nil
	}

	return 0, nil, nil
}
```

**Step 2: Create ffmpeg_test.go**

```go
package transcode

import (
	"testing"
)

func TestParseProgress(t *testing.T) {
	tests := []struct {
		name     string
		line     string
		duration float64
		want     int
	}{
		{
			name:     "beginning",
			line:     "frame=  120 fps=24 q=28.0 size=    1024kB time=00:00:05.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 100.0,
			want:     5,
		},
		{
			name:     "middle",
			line:     "frame= 1200 fps=24 q=28.0 size=   10240kB time=00:00:50.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 100.0,
			want:     50,
		},
		{
			name:     "near end",
			line:     "frame= 2400 fps=24 q=28.0 size=   20480kB time=00:01:35.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 100.0,
			want:     95,
		},
		{
			name:     "long video",
			line:     "frame=86400 fps=24 q=28.0 size=  204800kB time=01:00:00.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 7200.0, // 2 hours
			want:     50,
		},
		{
			name:     "no time field",
			line:     "frame=  120 fps=24 q=28.0 size=    1024kB",
			duration: 100.0,
			want:     0,
		},
		{
			name:     "zero duration",
			line:     "frame=  120 fps=24 q=28.0 size=    1024kB time=00:00:05.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 0,
			want:     0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseProgress(tt.line, tt.duration)
			if got != tt.want {
				t.Errorf("parseProgress() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestBuildFFmpegArgs_Software(t *testing.T) {
	opts := TranscodeOptions{
		CRF:    20,
		Mode:   "software",
		Preset: "slow",
	}

	args := buildFFmpegArgs("/input/movie.mkv", "/output/movie.mkv", opts)

	// Check key args are present
	contains := func(args []string, want string) bool {
		for _, a := range args {
			if a == want {
				return true
			}
		}
		return false
	}

	if !contains(args, "libx265") {
		t.Error("expected libx265 codec")
	}
	if !contains(args, "-crf") {
		t.Error("expected -crf flag")
	}
	if !contains(args, "slow") {
		t.Error("expected slow preset")
	}
}

func TestBuildFFmpegArgs_Hardware(t *testing.T) {
	opts := TranscodeOptions{
		CRF:      20,
		Mode:     "hardware",
		HWPreset: "medium",
	}

	args := buildFFmpegArgs("/input/movie.mkv", "/output/movie.mkv", opts)

	contains := func(args []string, want string) bool {
		for _, a := range args {
			if a == want {
				return true
			}
		}
		return false
	}

	if !contains(args, "hevc_qsv") {
		t.Error("expected hevc_qsv codec")
	}
	if !contains(args, "-global_quality") {
		t.Error("expected -global_quality flag")
	}
	if !contains(args, "qsv") {
		t.Error("expected qsv hwaccel")
	}
}
```

**Step 3: Run tests**

```bash
go test ./internal/transcode/... -v
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add internal/transcode/ffmpeg.go internal/transcode/ffmpeg_test.go
git commit -m "transcode: add ffmpeg runner with progress parsing"
```

---

## Task 7: Transcoder Orchestrator

Create the main Transcoder that coordinates file discovery, database updates, and ffmpeg execution.

**Files:**
- Create: `internal/transcode/transcoder.go`
- Create: `internal/transcode/transcoder_test.go`

**Step 1: Create transcoder.go**

```go
package transcode

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// Logger interface for transcoder logging
type Logger interface {
	Info(format string, args ...interface{})
	Error(format string, args ...interface{})
}

// Transcoder handles video transcoding operations
type Transcoder struct {
	repo   db.Repository
	logger Logger
	opts   TranscodeOptions
}

// NewTranscoder creates a new Transcoder
func NewTranscoder(repo db.Repository, logger Logger, opts TranscodeOptions) *Transcoder {
	return &Transcoder{
		repo:   repo,
		logger: logger,
		opts:   opts,
	}
}

// TranscodeJob processes all files for a transcode job
func (t *Transcoder) TranscodeJob(ctx context.Context, job *model.Job, inputDir, outputDir string, isTV bool) error {
	// Build queue of files to process
	files, err := t.buildQueue(ctx, job.ID, inputDir, isTV)
	if err != nil {
		return fmt.Errorf("failed to build queue: %w", err)
	}

	if len(files) == 0 {
		t.logger.Info("No files to transcode")
		return nil
	}

	t.logger.Info("Found %d file(s) to transcode", len(files))

	// Count pending/completed for resume
	pending := 0
	completed := 0
	for _, f := range files {
		switch f.Status {
		case model.TranscodeFileStatusPending:
			pending++
		case model.TranscodeFileStatusCompleted:
			completed++
		}
	}

	if completed > 0 {
		t.logger.Info("Resuming: %d completed, %d remaining", completed, pending)
	}

	// Process each file
	var lastErr error
	for i, file := range files {
		if file.Status == model.TranscodeFileStatusCompleted {
			continue
		}
		if file.Status == model.TranscodeFileStatusSkipped {
			continue
		}

		inputPath := filepath.Join(inputDir, file.RelativePath)
		outputPath := filepath.Join(outputDir, file.RelativePath)

		t.logger.Info("[%d/%d] Transcoding: %s", i+1, len(files), file.RelativePath)

		if err := t.transcodeFile(ctx, &file, inputPath, outputPath); err != nil {
			t.logger.Error("Failed: %s - %v", file.RelativePath, err)
			lastErr = err
			// Continue with other files
		} else {
			ratio := file.CompressionRatio()
			savedMB := file.SizeSaved() / (1024 * 1024)
			t.logger.Info("Completed: %s (%.1f%% of original, saved %dMB)",
				file.RelativePath, ratio*100, savedMB)
		}
	}

	// Log summary
	t.logSummary(ctx, job.ID)

	return lastErr
}

// buildQueue discovers files and creates/updates database records
func (t *Transcoder) buildQueue(ctx context.Context, jobID int64, inputDir string, isTV bool) ([]model.TranscodeFile, error) {
	// Check for existing files in database (resume case)
	existing, err := t.repo.ListTranscodeFiles(ctx, jobID)
	if err != nil {
		return nil, err
	}

	existingMap := make(map[string]*model.TranscodeFile)
	for i := range existing {
		existingMap[existing[i].RelativePath] = &existing[i]
	}

	// Determine source subdirectory
	var srcSubdir string
	if isTV {
		srcSubdir = "_episodes"
	} else {
		srcSubdir = "_main"
	}
	srcDir := filepath.Join(inputDir, srcSubdir)

	// Find MKV files
	var files []model.TranscodeFile

	err = filepath.Walk(srcDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(strings.ToLower(info.Name()), ".mkv") {
			return nil
		}

		relPath, _ := filepath.Rel(inputDir, path)

		// Check if already in database
		if existing, ok := existingMap[relPath]; ok {
			files = append(files, *existing)
			return nil
		}

		// Get duration
		duration, err := GetDuration(path)
		if err != nil {
			t.logger.Error("Could not get duration for %s: %v", relPath, err)
			duration = 0
		}

		// Create new record
		file := &model.TranscodeFile{
			JobID:        jobID,
			RelativePath: relPath,
			Status:       model.TranscodeFileStatusPending,
			InputSize:    info.Size(),
			DurationSecs: duration,
		}

		if err := t.repo.CreateTranscodeFile(ctx, file); err != nil {
			return fmt.Errorf("failed to create transcode file record: %w", err)
		}

		files = append(files, *file)
		return nil
	})

	if err != nil {
		return nil, err
	}

	// Also check for extras (but don't transcode them - just copy)
	extrasDir := filepath.Join(inputDir, "_extras")
	if _, err := os.Stat(extrasDir); err == nil {
		// Mark extras as skipped (will be copied)
		err = filepath.Walk(extrasDir, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() {
				return err
			}
			if !strings.HasSuffix(strings.ToLower(info.Name()), ".mkv") {
				return nil
			}

			relPath, _ := filepath.Rel(inputDir, path)

			if _, ok := existingMap[relPath]; ok {
				return nil
			}

			file := &model.TranscodeFile{
				JobID:        jobID,
				RelativePath: relPath,
				Status:       model.TranscodeFileStatusSkipped, // Extras are copied, not transcoded
				InputSize:    info.Size(),
			}
			t.repo.CreateTranscodeFile(ctx, file)
			return nil
		})
	}

	return files, nil
}

// transcodeFile processes a single file
func (t *Transcoder) transcodeFile(ctx context.Context, file *model.TranscodeFile, inputPath, outputPath string) error {
	// Delete any partial output from previous attempt
	os.Remove(outputPath)

	// Ensure output directory exists
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Mark as in progress
	if err := t.repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusInProgress, ""); err != nil {
		return err
	}

	// Set duration for progress calculation
	opts := t.opts
	opts.DurationSec = file.DurationSecs

	// Track last progress to avoid too many updates
	lastProgress := 0

	// Run ffmpeg with progress callback
	err := TranscodeFile(ctx, inputPath, outputPath, opts, func(percent int) {
		// Only update on 1% increments
		if percent > lastProgress {
			lastProgress = percent
			t.repo.UpdateTranscodeFileProgress(ctx, file.ID, percent)
		}
	})

	if err != nil {
		t.repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusFailed, err.Error())
		return err
	}

	// Get output size
	info, err := os.Stat(outputPath)
	if err != nil {
		t.repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusFailed, "output file not found")
		return fmt.Errorf("output file not found: %w", err)
	}

	// Update file record with results
	file.Status = model.TranscodeFileStatusCompleted
	file.OutputSize = info.Size()
	file.Progress = 100
	if err := t.repo.UpdateTranscodeFile(ctx, file); err != nil {
		return err
	}

	return nil
}

// logSummary logs the final summary
func (t *Transcoder) logSummary(ctx context.Context, jobID int64) {
	files, err := t.repo.ListTranscodeFiles(ctx, jobID)
	if err != nil {
		return
	}

	var completed, failed, skipped int
	var totalInput, totalOutput int64

	for _, f := range files {
		switch f.Status {
		case model.TranscodeFileStatusCompleted:
			completed++
			totalInput += f.InputSize
			totalOutput += f.OutputSize
		case model.TranscodeFileStatusFailed:
			failed++
		case model.TranscodeFileStatusSkipped:
			skipped++
		}
	}

	t.logger.Info("Summary: %d completed, %d failed, %d skipped", completed, failed, skipped)

	if totalInput > 0 {
		savedGB := float64(totalInput-totalOutput) / (1024 * 1024 * 1024)
		ratio := float64(totalOutput) / float64(totalInput) * 100
		t.logger.Info("Total: %.2fGB -> %.2fGB (%.1f%%, saved %.2fGB)",
			float64(totalInput)/(1024*1024*1024),
			float64(totalOutput)/(1024*1024*1024),
			ratio, savedGB)
	}
}

// CopyExtras copies the _extras directory without transcoding
func (t *Transcoder) CopyExtras(inputDir, outputDir string) error {
	extrasIn := filepath.Join(inputDir, "_extras")
	extrasOut := filepath.Join(outputDir, "_extras")

	if _, err := os.Stat(extrasIn); os.IsNotExist(err) {
		return nil // No extras to copy
	}

	t.logger.Info("Copying extras...")
	return copyDirectory(extrasIn, extrasOut)
}

// copyDirectory copies a directory recursively
func copyDirectory(src, dst string) error {
	if err := os.MkdirAll(dst, 0755); err != nil {
		return err
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())

		if entry.IsDir() {
			if err := copyDirectory(srcPath, dstPath); err != nil {
				return err
			}
		} else {
			if err := copyFile(srcPath, dstPath); err != nil {
				return err
			}
		}
	}

	return nil
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}
```

**Step 2: Create transcoder_test.go**

```go
package transcode

import (
	"testing"
)

func TestTranscoder_BuildQueue(t *testing.T) {
	// This would need a mock repository
	// For now, just verify the package compiles
	t.Log("Transcoder package compiles correctly")
}
```

**Step 3: Run tests**

```bash
go test ./internal/transcode/... -v
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add internal/transcode/transcoder.go internal/transcode/transcoder_test.go
git commit -m "transcode: add transcoder orchestrator"
```

---

## Task 8: Transcode Command Implementation

Replace the stub transcode command with the full implementation.

**Files:**
- Modify: `cmd/transcode/main.go`

**Step 1: Replace main.go with full implementation**

```go
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/cuivienor/media-pipeline/internal/config"
	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/logging"
	"github.com/cuivienor/media-pipeline/internal/model"
	"github.com/cuivienor/media-pipeline/internal/transcode"
)

func main() {
	var jobID int64
	var dbPath string

	flag.Int64Var(&jobID, "job-id", 0, "Job ID to execute")
	flag.StringVar(&dbPath, "db", "", "Path to database")
	flag.Parse()

	if jobID == 0 || dbPath == "" {
		fmt.Fprintln(os.Stderr, "Usage: transcode -job-id <id> -db <path>")
		os.Exit(1)
	}

	if err := run(jobID, dbPath); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run(jobID int64, dbPath string) error {
	ctx := context.Background()

	// Open database
	database, err := db.Open(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	repo := db.NewSQLiteRepository(database)

	// Get job
	job, err := repo.GetJob(ctx, jobID)
	if err != nil {
		return fmt.Errorf("failed to get job: %w", err)
	}

	// Get media item
	item, err := repo.GetMediaItem(ctx, job.MediaItemID)
	if err != nil {
		return fmt.Errorf("failed to get media item: %w", err)
	}

	// Load config
	cfg, err := config.LoadFromMediaBase()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Set up logging
	if err := cfg.EnsureJobLogDir(jobID); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}
	logPath := cfg.JobLogPath(jobID)
	logger, err := logging.NewForJob(logPath, true, nil)
	if err != nil {
		return fmt.Errorf("failed to create logger: %w", err)
	}
	defer logger.Close()

	logger.Info("Starting transcode: type=%s name=%q", item.Type, item.Name)

	// Get transcode options (defaults from config, overridable per-job)
	opts := transcode.TranscodeOptions{
		CRF:      cfg.TranscodeCRF(),
		Mode:     cfg.TranscodeMode(),
		Preset:   cfg.TranscodePreset(),
		HWPreset: cfg.TranscodeHWPreset(),
	}

	// Check for per-job overrides
	jobOpts, err := repo.GetJobOptions(ctx, jobID)
	if err == nil && jobOpts != nil {
		if crf, ok := jobOpts["crf"].(float64); ok {
			opts.CRF = int(crf)
		}
		if mode, ok := jobOpts["mode"].(string); ok {
			opts.Mode = mode
		}
	}

	logger.Info("Transcode options: CRF=%d, mode=%s, preset=%s", opts.CRF, opts.Mode, opts.Preset)

	// Check hardware support if requested
	if opts.Mode == "hardware" {
		if err := transcode.CheckHardwareSupport(); err != nil {
			logger.Error("Hardware encoding requested but not available: %v", err)
			return fmt.Errorf("hardware encoding not available: %w", err)
		}
		logger.Info("Hardware encoding (QSV) available")
	}

	// Find input directory from remux job
	inputDir, err := findRemuxOutput(ctx, repo, job)
	if err != nil {
		logger.Error("Failed to find input: %v", err)
		return fmt.Errorf("failed to find input: %w", err)
	}

	// Determine output directory
	outputDir, err := buildOutputPath(ctx, repo, cfg, item, job)
	if err != nil {
		logger.Error("Failed to build output path: %v", err)
		return fmt.Errorf("failed to build output path: %w", err)
	}

	logger.Info("Input directory: %s", inputDir)
	logger.Info("Output directory: %s", outputDir)

	// Update job to in_progress
	job.Status = model.JobStatusInProgress
	job.InputDir = inputDir
	job.OutputDir = outputDir
	now := time.Now()
	job.StartedAt = &now
	if err := repo.UpdateJob(ctx, job); err != nil {
		return fmt.Errorf("failed to update job status: %w", err)
	}

	// Create transcoder and process
	transcoder := transcode.NewTranscoder(repo, logger, opts)
	isTV := item.Type == model.MediaTypeTV

	err = transcoder.TranscodeJob(ctx, job, inputDir, outputDir, isTV)
	if err != nil {
		logger.Error("Transcode failed: %v", err)
		if updateErr := repo.UpdateJobStatus(ctx, jobID, model.JobStatusFailed, err.Error()); updateErr != nil {
			logger.Error("Failed to update job status: %v", updateErr)
		}
		return err
	}

	// Copy extras
	if err := transcoder.CopyExtras(inputDir, outputDir); err != nil {
		logger.Error("Failed to copy extras: %v", err)
		// Non-fatal - continue
	}

	// Mark job as complete
	if err := repo.UpdateJobStatus(ctx, jobID, model.JobStatusCompleted, ""); err != nil {
		return fmt.Errorf("failed to update job status: %w", err)
	}

	// Update media item stage
	if err := repo.UpdateMediaItemStage(ctx, item.ID, model.StageTranscode, model.StatusCompleted); err != nil {
		return fmt.Errorf("failed to update item stage: %w", err)
	}

	logger.Info("Transcode finished successfully")
	return nil
}

// findRemuxOutput finds the output directory from the remux stage
func findRemuxOutput(ctx context.Context, repo db.Repository, job *model.Job) (string, error) {
	jobs, err := repo.ListJobsForMedia(ctx, job.MediaItemID)
	if err != nil {
		return "", err
	}

	// Find the most recent completed remux job
	for i := len(jobs) - 1; i >= 0; i-- {
		j := jobs[i]
		if j.Stage == model.StageRemux && j.Status == model.JobStatusCompleted {
			if j.OutputDir != "" {
				return j.OutputDir, nil
			}
		}
	}

	return "", fmt.Errorf("no completed remux job found for media item %d", job.MediaItemID)
}

// buildOutputPath constructs the output directory for transcoded files
func buildOutputPath(ctx context.Context, repo db.Repository, cfg *config.Config, item *model.MediaItem, job *model.Job) (string, error) {
	mediaTypeDir := "movies"
	if item.Type == model.MediaTypeTV {
		mediaTypeDir = "tv"
	}

	baseName := item.SafeName
	if item.Type == model.MediaTypeTV && job.SeasonID != nil {
		season, err := repo.GetSeason(ctx, *job.SeasonID)
		if err != nil {
			return "", fmt.Errorf("failed to get season: %w", err)
		}
		baseName = fmt.Sprintf("%s/Season_%02d", item.SafeName, season.Number)
	}

	return filepath.Join(cfg.StagingBase, "3-transcoded", mediaTypeDir, baseName), nil
}
```

**Step 2: Build and verify**

```bash
go build ./cmd/transcode/...
```

Expected: Build succeeds

**Step 3: Commit**

```bash
git add cmd/transcode/main.go
git commit -m "transcode: implement full transcode command"
```

---

## Task 9: Update Test Environment Script

Add transcode config to the test environment setup.

**Files:**
- Modify: `scripts/setup-test-env.sh`

**Step 1: Update config.yaml generation**

Find the section that creates config.yaml (around line 50-60) and update it to include transcode config:

```bash
# Create config file
cat > "$MEDIA_BASE/pipeline/config.yaml" << EOF
staging_base: $MEDIA_BASE/staging
library_base: $MEDIA_BASE/library

dispatch:
  rip: ""
  remux: ""
  transcode: ""
  publish: ""

remux:
  languages:
    - eng
    - bul

transcode:
  crf: 20
  mode: software
  preset: ultrafast
EOF
```

Note: Use `ultrafast` preset in test environment for faster tests.

**Step 2: Test the script**

```bash
./scripts/setup-test-env.sh
cat /tmp/media-test-*/pipeline/config.yaml
```

Expected: Config includes transcode section

**Step 3: Commit**

```bash
git add scripts/setup-test-env.sh
git commit -m "scripts: add transcode config to test environment"
```

---

## Task 10: Integration Test

Create an integration test that runs the full transcode pipeline.

**Files:**
- Create: `internal/transcode/integration_test.go`

**Step 1: Create integration test**

```go
package transcode

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// testLogger implements Logger for tests
type testLogger struct {
	t *testing.T
}

func (l *testLogger) Info(format string, args ...interface{}) {
	l.t.Logf("[INFO] "+format, args...)
}

func (l *testLogger) Error(format string, args ...interface{}) {
	l.t.Logf("[ERROR] "+format, args...)
}

func TestTranscoder_Integration(t *testing.T) {
	// Skip if ffmpeg not available
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not available")
	}
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not available")
	}

	// Create temp directories
	tmpDir := t.TempDir()
	inputDir := filepath.Join(tmpDir, "input")
	outputDir := filepath.Join(tmpDir, "output")
	os.MkdirAll(filepath.Join(inputDir, "_main"), 0755)

	// Generate a short test video
	testVideo := filepath.Join(inputDir, "_main", "test.mkv")
	err := exec.Command("ffmpeg",
		"-f", "lavfi",
		"-i", "testsrc=duration=2:size=320x240:rate=24",
		"-f", "lavfi",
		"-i", "anullsrc=r=48000:cl=stereo:d=2",
		"-c:v", "libx264", "-preset", "ultrafast",
		"-c:a", "aac",
		"-shortest",
		"-y", testVideo,
	).Run()
	if err != nil {
		t.Fatalf("Failed to create test video: %v", err)
	}

	// Set up database
	dbPath := filepath.Join(tmpDir, "test.db")
	database, err := db.Open(dbPath)
	if err != nil {
		t.Fatalf("Failed to open database: %v", err)
	}
	defer database.Close()

	repo := db.NewSQLiteRepository(database)
	ctx := context.Background()

	// Create media item and job
	item := &model.MediaItem{
		Type:     model.MediaTypeMovie,
		Name:     "Test Movie",
		SafeName: "Test_Movie",
	}
	if err := repo.CreateMediaItem(ctx, item); err != nil {
		t.Fatalf("Failed to create media item: %v", err)
	}

	job := &model.Job{
		MediaItemID: item.ID,
		Stage:       model.StageTranscode,
		Status:      model.JobStatusInProgress,
		InputDir:    inputDir,
		OutputDir:   outputDir,
	}
	now := time.Now()
	job.StartedAt = &now
	if err := repo.CreateJob(ctx, job); err != nil {
		t.Fatalf("Failed to create job: %v", err)
	}

	// Create transcoder
	opts := TranscodeOptions{
		CRF:    28, // Higher CRF for faster test
		Mode:   "software",
		Preset: "ultrafast",
	}
	logger := &testLogger{t}
	transcoder := NewTranscoder(repo, logger, opts)

	// Run transcode
	err = transcoder.TranscodeJob(ctx, job, inputDir, outputDir, false)
	if err != nil {
		t.Fatalf("TranscodeJob failed: %v", err)
	}

	// Verify output exists
	outputVideo := filepath.Join(outputDir, "_main", "test.mkv")
	if _, err := os.Stat(outputVideo); os.IsNotExist(err) {
		t.Error("Output video not created")
	}

	// Verify database records
	files, err := repo.ListTranscodeFiles(ctx, job.ID)
	if err != nil {
		t.Fatalf("Failed to list transcode files: %v", err)
	}
	if len(files) != 1 {
		t.Errorf("Expected 1 transcode file, got %d", len(files))
	}
	if files[0].Status != model.TranscodeFileStatusCompleted {
		t.Errorf("Expected completed status, got %v", files[0].Status)
	}
	if files[0].Progress != 100 {
		t.Errorf("Expected 100%% progress, got %d%%", files[0].Progress)
	}
	if files[0].OutputSize == 0 {
		t.Error("Expected non-zero output size")
	}

	t.Logf("Input size: %d, Output size: %d, Ratio: %.1f%%",
		files[0].InputSize, files[0].OutputSize,
		float64(files[0].OutputSize)/float64(files[0].InputSize)*100)
}
```

**Step 2: Run integration test**

```bash
go test ./internal/transcode/... -v -run TestTranscoder_Integration
```

Expected: Test passes (may take 10-20 seconds for ffmpeg)

**Step 3: Commit**

```bash
git add internal/transcode/integration_test.go
git commit -m "transcode: add integration test"
```

---

## Task 11: TUI Transcode View Updates

Update TUI to show transcode progress with per-file details.

**Files:**
- Modify: `internal/tui/itemdetail.go`

**Step 1: Add transcode progress display**

Find the section that displays job status (around line 150-200) and add transcode-specific progress:

```go
// Add this helper function
func (a *App) renderTranscodeProgress(job *model.Job) string {
	if job.Stage != model.StageTranscode || job.Status != model.JobStatusInProgress {
		return ""
	}

	ctx := context.Background()
	files, err := a.repo.ListTranscodeFiles(ctx, job.ID)
	if err != nil || len(files) == 0 {
		return ""
	}

	var b strings.Builder
	b.WriteString("\n\nTranscode Progress:\n")

	completed := 0
	var currentFile *model.TranscodeFile
	for i := range files {
		switch files[i].Status {
		case model.TranscodeFileStatusCompleted:
			completed++
		case model.TranscodeFileStatusInProgress:
			currentFile = &files[i]
		}
	}

	b.WriteString(fmt.Sprintf("  Files: %d/%d completed\n", completed, len(files)))

	if currentFile != nil {
		b.WriteString(fmt.Sprintf("  Current: %s (%d%%)\n",
			filepath.Base(currentFile.RelativePath),
			currentFile.Progress))
	}

	return b.String()
}
```

Then call this in the job display section.

**Step 2: Build and verify**

```bash
go build ./cmd/media-pipeline/...
```

Expected: Build succeeds

**Step 3: Commit**

```bash
git add internal/tui/itemdetail.go
git commit -m "tui: add transcode progress display"
```

---

## Task 12: End-to-End Verification

Build everything and run a full test.

**Files:** None (verification only)

**Step 1: Build all binaries**

```bash
make build-local
```

Expected: All binaries build successfully

**Step 2: Run all tests**

```bash
make test
```

Expected: All tests pass

**Step 3: Manual verification with test environment**

```bash
./scripts/setup-test-env.sh
# Note the path, e.g., /tmp/media-test-XXXXXXXXXX

# In the TUI, create a movie, rip, organize, remux, then transcode
MEDIA_BASE=/tmp/media-test-XXXXXXXXXX MAKEMKVCON_PATH=/tmp/media-test-XXXXXXXXXX/bin/mock-makemkv /tmp/media-test-XXXXXXXXXX/bin/media-pipeline
```

Verify:
- Transcode job starts and shows progress
- Log file created at `pipeline/logs/jobs/{id}/job.log`
- Output created in `staging/3-transcoded/movies/{name}/`
- Database shows transcode_files with progress

**Step 4: Commit verification notes (optional)**

```bash
git add -A
git commit -m "transcode: complete implementation verified"
```

---

## Summary

This plan implements:

1. **Config** - TranscodeConfig with CRF, mode, presets
2. **Database** - transcode_files table, job options column
3. **Model** - TranscodeFile with status/progress tracking
4. **ffprobe** - Duration parser for progress calculation
5. **ffmpeg** - Runner with progress parsing from stderr
6. **Transcoder** - Orchestrator with resume support
7. **Command** - Full cmd/transcode with logging
8. **TUI** - Progress display with per-file details
9. **Tests** - Unit and integration tests

Key behaviors:
- Sequential file processing
- Resume capability (pending files only)
- Progress updates at 1% increments
- Partial files deleted on failure/interrupt
- Hardware mode fails if QSV unavailable
- Extras copied without transcoding
