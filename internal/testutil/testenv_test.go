package testutil

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewTestEnv_CreatesStagingDirs(t *testing.T) {
	env := NewTestEnv(t)

	// Verify staging directories exist
	dirs := []string{
		"staging/1-ripped/movies",
		"staging/1-ripped/tv",
		"staging/2-remuxed/movies",
		"staging/2-remuxed/tv",
		"staging/3-transcoded/movies",
		"staging/3-transcoded/tv",
		"library/movies",
		"library/tv",
	}

	for _, dir := range dirs {
		path := filepath.Join(env.BaseDir, dir)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Errorf("directory not created: %s", dir)
		}
	}
}

func TestNewTestEnv_ProvidesInMemoryDB(t *testing.T) {
	env := NewTestEnv(t)

	if env.DB == nil {
		t.Fatal("DB is nil")
	}
	if env.Repo == nil {
		t.Fatal("Repo is nil")
	}
}
