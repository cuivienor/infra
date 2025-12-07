package db

import (
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strings"

	_ "modernc.org/sqlite"
)

//go:embed migrations/*.sql
var migrations embed.FS

// DB wraps a SQLite database connection
type DB struct {
	db *sql.DB
}

// Open opens a SQLite database at the given path
func Open(path string) (*DB, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Enable foreign keys
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to enable foreign keys: %w", err)
	}

	database := &DB{db: db}
	if err := database.migrate(); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	return database, nil
}

// OpenInMemory opens an in-memory SQLite database for testing
func OpenInMemory() (*DB, error) {
	return Open(":memory:")
}

// Close closes the database connection
func (d *DB) Close() error {
	return d.db.Close()
}

// migrate runs all SQL migrations
func (d *DB) migrate() error {
	entries, err := fs.ReadDir(migrations, "migrations")
	if err != nil {
		return fmt.Errorf("failed to read migrations: %w", err)
	}

	// Sort by filename to ensure order
	var files []string
	for _, entry := range entries {
		if strings.HasSuffix(entry.Name(), ".sql") {
			files = append(files, entry.Name())
		}
	}
	sort.Strings(files)

	for _, file := range files {
		content, err := fs.ReadFile(migrations, "migrations/"+file)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", file, err)
		}

		if _, err := d.db.Exec(string(content)); err != nil {
			return fmt.Errorf("failed to execute %s: %w", file, err)
		}
	}

	return nil
}
