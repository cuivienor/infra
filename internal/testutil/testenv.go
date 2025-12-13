package testutil

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// TestEnv provides an isolated test environment with temp directories and in-memory database
type TestEnv struct {
	t          *testing.T
	BaseDir    string
	StagingDir string
	LibraryDir string
	DB         *db.DB
	Repo       *db.SQLiteRepository
}

// NewTestEnv creates a new isolated test environment
func NewTestEnv(t *testing.T) *TestEnv {
	t.Helper()

	baseDir := t.TempDir()

	// Create staging directories
	stagingDirs := []string{
		"staging/1-ripped/movies",
		"staging/1-ripped/tv",
		"staging/2-remuxed/movies",
		"staging/2-remuxed/tv",
		"staging/3-transcoded/movies",
		"staging/3-transcoded/tv",
	}
	for _, dir := range stagingDirs {
		if err := os.MkdirAll(filepath.Join(baseDir, dir), 0755); err != nil {
			t.Fatalf("failed to create staging dir %s: %v", dir, err)
		}
	}

	// Create library directories
	libraryDirs := []string{
		"library/movies",
		"library/tv",
	}
	for _, dir := range libraryDirs {
		if err := os.MkdirAll(filepath.Join(baseDir, dir), 0755); err != nil {
			t.Fatalf("failed to create library dir %s: %v", dir, err)
		}
	}

	// Open in-memory database
	database, err := db.OpenInMemory()
	if err != nil {
		t.Fatalf("failed to open in-memory database: %v", err)
	}

	repo := db.NewSQLiteRepository(database)

	env := &TestEnv{
		t:          t,
		BaseDir:    baseDir,
		StagingDir: filepath.Join(baseDir, "staging"),
		LibraryDir: filepath.Join(baseDir, "library"),
		DB:         database,
		Repo:       repo,
	}

	t.Cleanup(func() {
		database.Close()
	})

	return env
}

// CreateMediaItem creates a media item in the test database
func (e *TestEnv) CreateMediaItem(safeName string, mediaType model.MediaType) *model.MediaItem {
	e.t.Helper()
	ctx := context.Background()

	// Derive human-readable name from safe name
	name := strings.ReplaceAll(safeName, "_", " ")

	item := &model.MediaItem{
		Type:       mediaType,
		Name:       name,
		SafeName:   safeName,
		ItemStatus: model.ItemStatusActive,
	}

	if err := e.Repo.CreateMediaItem(ctx, item); err != nil {
		e.t.Fatalf("CreateMediaItem failed: %v", err)
	}

	return item
}

// CreateJob creates a pending job for a media item
func (e *TestEnv) CreateJob(mediaItemID int64, stage model.Stage) *model.Job {
	e.t.Helper()
	ctx := context.Background()

	job := &model.Job{
		MediaItemID: mediaItemID,
		Stage:       stage,
		Status:      model.JobStatusPending,
	}

	if err := e.Repo.CreateJob(ctx, job); err != nil {
		e.t.Fatalf("CreateJob failed: %v", err)
	}

	return job
}

// CreateCompletedJob creates a completed job with the specified output directory
func (e *TestEnv) CreateCompletedJob(mediaItemID int64, stage model.Stage, outputDir string) *model.Job {
	e.t.Helper()
	ctx := context.Background()

	now := time.Now()
	job := &model.Job{
		MediaItemID: mediaItemID,
		Stage:       stage,
		Status:      model.JobStatusCompleted,
		OutputDir:   outputDir,
		Progress:    100,
		StartedAt:   &now,
		CompletedAt: &now,
	}

	if err := e.Repo.CreateJob(ctx, job); err != nil {
		e.t.Fatalf("CreateCompletedJob failed: %v", err)
	}

	return job
}
