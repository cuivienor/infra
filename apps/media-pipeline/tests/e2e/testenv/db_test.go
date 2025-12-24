package testenv

import (
	"context"
	"testing"

	"github.com/cuivienor/media-pipeline/internal/model"
)

func TestNewDBFixture(t *testing.T) {
	fixture := NewDBFixture(t)

	// Verify fixture is properly initialized
	if fixture.DB == nil {
		t.Fatal("DBFixture.DB is nil")
	}
	if fixture.Repo == nil {
		t.Fatal("DBFixture.Repo is nil")
	}
}

func TestDBFixture_CreateMovie(t *testing.T) {
	fixture := NewDBFixture(t)

	// Create a movie
	movie := fixture.CreateMovie("The Matrix", "The_Matrix")

	// Verify it has an ID
	if movie.ID == 0 {
		t.Error("movie ID should be set after creation")
	}

	// Verify it's in the database
	retrieved, err := fixture.Repo.GetMediaItem(context.Background(), movie.ID)
	if err != nil {
		t.Fatalf("failed to retrieve movie: %v", err)
	}
	if retrieved == nil {
		t.Fatal("movie not found in database")
	}

	// Verify fields
	if retrieved.Type != model.MediaTypeMovie {
		t.Errorf("Type = %v, want %v", retrieved.Type, model.MediaTypeMovie)
	}
	if retrieved.Name != "The Matrix" {
		t.Errorf("Name = %q, want %q", retrieved.Name, "The Matrix")
	}
	if retrieved.SafeName != "The_Matrix" {
		t.Errorf("SafeName = %q, want %q", retrieved.SafeName, "The_Matrix")
	}
	if retrieved.Season != nil {
		t.Errorf("Season = %v, want nil for movie", retrieved.Season)
	}
}

func TestDBFixture_CreateTVSeason(t *testing.T) {
	fixture := NewDBFixture(t)

	// Create a TV season
	tvSeason := fixture.CreateTVSeason("Breaking Bad", "Breaking_Bad", 2)

	// Verify it has an ID
	if tvSeason.ID == 0 {
		t.Error("TV season ID should be set after creation")
	}

	// Verify it's in the database
	retrieved, err := fixture.Repo.GetMediaItem(context.Background(), tvSeason.ID)
	if err != nil {
		t.Fatalf("failed to retrieve TV season: %v", err)
	}
	if retrieved == nil {
		t.Fatal("TV season not found in database")
	}

	// Verify fields
	if retrieved.Type != model.MediaTypeTV {
		t.Errorf("Type = %v, want %v", retrieved.Type, model.MediaTypeTV)
	}
	if retrieved.Name != "Breaking Bad" {
		t.Errorf("Name = %q, want %q", retrieved.Name, "Breaking Bad")
	}
	if retrieved.SafeName != "Breaking_Bad" {
		t.Errorf("SafeName = %q, want %q", retrieved.SafeName, "Breaking_Bad")
	}
	if retrieved.Season == nil {
		t.Error("Season should not be nil for TV show")
	} else if *retrieved.Season != 2 {
		t.Errorf("Season = %d, want 2", *retrieved.Season)
	}
}

func TestDBFixture_CreateRipJob(t *testing.T) {
	fixture := NewDBFixture(t)

	// Create a movie first
	movie := fixture.CreateMovie("Test Movie", "Test_Movie")

	// Create a rip job
	job := fixture.CreateRipJob(movie.ID, nil, model.JobStatusPending)

	// Verify it has an ID
	if job.ID == 0 {
		t.Error("job ID should be set after creation")
	}

	// Verify it's in the database
	retrieved, err := fixture.Repo.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("failed to retrieve job: %v", err)
	}
	if retrieved == nil {
		t.Fatal("job not found in database")
	}

	// Verify fields
	if retrieved.MediaItemID != movie.ID {
		t.Errorf("MediaItemID = %d, want %d", retrieved.MediaItemID, movie.ID)
	}
	if retrieved.Stage != model.StageRip {
		t.Errorf("Stage = %v, want %v", retrieved.Stage, model.StageRip)
	}
	if retrieved.Status != model.JobStatusPending {
		t.Errorf("Status = %v, want %v", retrieved.Status, model.JobStatusPending)
	}
	if retrieved.Disc != nil {
		t.Errorf("Disc = %v, want nil", retrieved.Disc)
	}
}

func TestDBFixture_CreateRipJobWithDisc(t *testing.T) {
	fixture := NewDBFixture(t)

	// Create a TV season first
	tvSeason := fixture.CreateTVSeason("The Wire", "The_Wire", 1)

	// Create a rip job with disc
	disc := 1
	job := fixture.CreateRipJob(tvSeason.ID, &disc, model.JobStatusInProgress)

	// Verify it has an ID
	if job.ID == 0 {
		t.Error("job ID should be set after creation")
	}

	// Verify disc field
	retrieved, err := fixture.Repo.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("failed to retrieve job: %v", err)
	}
	if retrieved == nil {
		t.Fatal("job not found in database")
	}

	if retrieved.Disc == nil {
		t.Error("Disc should not be nil")
	} else if *retrieved.Disc != 1 {
		t.Errorf("Disc = %d, want 1", *retrieved.Disc)
	}
}

func TestDBFixture_MultipleJobs(t *testing.T) {
	fixture := NewDBFixture(t)

	// Create a TV season
	tvSeason := fixture.CreateTVSeason("Game of Thrones", "Game_of_Thrones", 1)

	// Create multiple rip jobs for different discs
	disc1 := 1
	disc2 := 2
	disc3 := 3

	job1 := fixture.CreateRipJob(tvSeason.ID, &disc1, model.JobStatusCompleted)
	job2 := fixture.CreateRipJob(tvSeason.ID, &disc2, model.JobStatusInProgress)
	job3 := fixture.CreateRipJob(tvSeason.ID, &disc3, model.JobStatusPending)

	// Verify all jobs are in the database
	jobs, err := fixture.Repo.ListJobsForMedia(context.Background(), tvSeason.ID)
	if err != nil {
		t.Fatalf("failed to list jobs: %v", err)
	}

	if len(jobs) != 3 {
		t.Errorf("found %d jobs, want 3", len(jobs))
	}

	// Verify job IDs are unique
	ids := map[int64]bool{job1.ID: true, job2.ID: true, job3.ID: true}
	if len(ids) != 3 {
		t.Error("job IDs should be unique")
	}
}

func TestEnvironment_WithDB(t *testing.T) {
	env := New(t)

	// Test WithDB method
	env2, dbFixture := env.WithDB(t)

	// Verify same environment is returned
	if env2 != env {
		t.Error("WithDB should return same environment instance")
	}

	// Verify DBFixture is initialized
	if dbFixture == nil {
		t.Fatal("DBFixture is nil")
	}
	if dbFixture.DB == nil {
		t.Error("DBFixture.DB is nil")
	}
	if dbFixture.Repo == nil {
		t.Error("DBFixture.Repo is nil")
	}

	// Verify we can use the fixture
	movie := dbFixture.CreateMovie("Inception", "Inception")
	if movie.ID == 0 {
		t.Error("movie ID should be set")
	}
}

func TestDBFixture_Integration(t *testing.T) {
	fixture := NewDBFixture(t)

	// Create a complete scenario: movie with rip job
	movie := fixture.CreateMovie("Interstellar", "Interstellar")
	ripJob := fixture.CreateRipJob(movie.ID, nil, model.JobStatusCompleted)

	// Verify we can look up the movie by safe name
	retrieved, err := fixture.Repo.GetMediaItemBySafeName(context.Background(), "Interstellar", nil)
	if err != nil {
		t.Fatalf("GetMediaItemBySafeName failed: %v", err)
	}
	if retrieved == nil {
		t.Fatal("movie not found by safe name")
	}
	if retrieved.ID != movie.ID {
		t.Errorf("retrieved wrong movie: ID = %d, want %d", retrieved.ID, movie.ID)
	}

	// Verify job is associated with the movie
	jobs, err := fixture.Repo.ListJobsForMedia(context.Background(), movie.ID)
	if err != nil {
		t.Fatalf("ListJobsForMedia failed: %v", err)
	}
	if len(jobs) != 1 {
		t.Errorf("found %d jobs, want 1", len(jobs))
	}
	if len(jobs) > 0 && jobs[0].ID != ripJob.ID {
		t.Errorf("job ID = %d, want %d", jobs[0].ID, ripJob.ID)
	}
}
