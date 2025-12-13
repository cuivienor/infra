package testutil

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/cuivienor/media-pipeline/internal/db"
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
