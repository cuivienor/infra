package testenv

import (
	"context"
	"testing"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// DBFixture provides database test helpers
type DBFixture struct {
	t    *testing.T
	DB   *db.DB
	Repo db.Repository
}

// NewDBFixture creates an in-memory database for testing
func NewDBFixture(t *testing.T) *DBFixture {
	t.Helper()
	database, err := db.OpenInMemory()
	if err != nil {
		t.Fatalf("failed to open in-memory database: %v", err)
	}

	t.Cleanup(func() {
		database.Close()
	})

	return &DBFixture{
		t:    t,
		DB:   database,
		Repo: db.NewSQLiteRepository(database),
	}
}

// CreateMovie creates a movie MediaItem for testing
func (f *DBFixture) CreateMovie(name, safeName string) *model.MediaItem {
	f.t.Helper()
	item := &model.MediaItem{
		Type:     model.MediaTypeMovie,
		Name:     name,
		SafeName: safeName,
	}
	if err := f.Repo.CreateMediaItem(context.Background(), item); err != nil {
		f.t.Fatalf("CreateMovie failed: %v", err)
	}
	return item
}

// CreateTVSeason creates a TV season MediaItem for testing
func (f *DBFixture) CreateTVSeason(name, safeName string, season int) *model.MediaItem {
	f.t.Helper()
	item := &model.MediaItem{
		Type:     model.MediaTypeTV,
		Name:     name,
		SafeName: safeName,
		Season:   &season,
	}
	if err := f.Repo.CreateMediaItem(context.Background(), item); err != nil {
		f.t.Fatalf("CreateTVSeason failed: %v", err)
	}
	return item
}

// CreateRipJob creates a rip job for testing
func (f *DBFixture) CreateRipJob(mediaItemID int64, disc *int, status model.JobStatus) *model.Job {
	f.t.Helper()
	job := &model.Job{
		MediaItemID: mediaItemID,
		Stage:       model.StageRip,
		Status:      status,
		Disc:        disc,
	}
	if err := f.Repo.CreateJob(context.Background(), job); err != nil {
		f.t.Fatalf("CreateRipJob failed: %v", err)
	}
	return job
}
