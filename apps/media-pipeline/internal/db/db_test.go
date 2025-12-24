package db

import (
	"os"
	"path/filepath"
	"testing"
)

func TestOpen_InMemory(t *testing.T) {
	database, err := OpenInMemory()
	if err != nil {
		t.Fatalf("OpenInMemory() error = %v", err)
	}
	defer database.Close()

	// Verify tables exist
	var count int
	err = database.db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='media_items'").Scan(&count)
	if err != nil {
		t.Fatalf("Query error: %v", err)
	}
	if count != 1 {
		t.Errorf("media_items table not created")
	}
}

func TestOpen_MigrationsApplied(t *testing.T) {
	database, err := OpenInMemory()
	if err != nil {
		t.Fatalf("OpenInMemory() error = %v", err)
	}
	defer database.Close()

	// Verify all expected tables
	tables := []string{"media_items", "jobs", "log_events"}
	for _, table := range tables {
		var count int
		err = database.db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", table).Scan(&count)
		if err != nil {
			t.Fatalf("Query error for %s: %v", table, err)
		}
		if count != 1 {
			t.Errorf("table %s not created", table)
		}
	}
}

func TestOpen_ForeignKeysEnabled(t *testing.T) {
	database, err := OpenInMemory()
	if err != nil {
		t.Fatalf("OpenInMemory() error = %v", err)
	}
	defer database.Close()

	// Verify foreign keys are enabled
	var enabled int
	err = database.db.QueryRow("PRAGMA foreign_keys").Scan(&enabled)
	if err != nil {
		t.Fatalf("Query error: %v", err)
	}
	if enabled != 1 {
		t.Errorf("foreign_keys = %d, want 1", enabled)
	}
}

func TestOpen_IndexesCreated(t *testing.T) {
	database, err := OpenInMemory()
	if err != nil {
		t.Fatalf("OpenInMemory() error = %v", err)
	}
	defer database.Close()

	// Verify expected indexes exist
	indexes := []string{"idx_jobs_media_item", "idx_jobs_status", "idx_log_events_job"}
	for _, index := range indexes {
		var count int
		err = database.db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name=?", index).Scan(&count)
		if err != nil {
			t.Fatalf("Query error for %s: %v", index, err)
		}
		if count != 1 {
			t.Errorf("index %s not created", index)
		}
	}
}

func TestOpen_FileBased(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	// Open database
	database, err := Open(dbPath)
	if err != nil {
		t.Fatalf("Open() error = %v", err)
	}
	defer database.Close()

	// Verify database file was created
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		t.Errorf("database file not created at %s", dbPath)
	}

	// Verify tables exist
	var count int
	err = database.db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='media_items'").Scan(&count)
	if err != nil {
		t.Fatalf("Query error: %v", err)
	}
	if count != 1 {
		t.Errorf("media_items table not created in file-based database")
	}
}

func TestOpen_ReopensExistingDatabase(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	// Create database
	db1, err := Open(dbPath)
	if err != nil {
		t.Fatalf("Open() error = %v", err)
	}
	db1.Close()

	// Reopen database
	db2, err := Open(dbPath)
	if err != nil {
		t.Fatalf("Reopen() error = %v", err)
	}
	defer db2.Close()

	// Verify migrations don't fail on existing tables
	var count int
	err = db2.db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='jobs'").Scan(&count)
	if err != nil {
		t.Fatalf("Query error: %v", err)
	}
	if count != 1 {
		t.Errorf("jobs table not found in reopened database")
	}
}
