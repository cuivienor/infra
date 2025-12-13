// internal/pipeline/properties/database.go
package properties

import (
	"context"
	"fmt"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// AssertJobStatusConsistency verifies all jobs have consistent status and timestamps
// Returns an error if any invariant is violated
func AssertJobStatusConsistency(ctx context.Context, repo *db.SQLiteRepository) error {
	// Get all jobs - we need a method for this
	// For now, check jobs for all media items
	items, err := repo.ListActiveItems(ctx)
	if err != nil {
		return fmt.Errorf("failed to list items: %w", err)
	}

	for _, item := range items {
		jobs, err := repo.ListJobsForMedia(ctx, item.ID)
		if err != nil {
			return fmt.Errorf("failed to list jobs for item %d: %w", item.ID, err)
		}

		for _, job := range jobs {
			if err := validateJobConsistency(&job); err != nil {
				return fmt.Errorf("job %d: %w", job.ID, err)
			}
		}
	}

	return nil
}

func validateJobConsistency(job *model.Job) error {
	switch job.Status {
	case model.JobStatusCompleted:
		if job.CompletedAt == nil {
			return fmt.Errorf("completed job has nil CompletedAt")
		}
		if job.Progress != 100 {
			return fmt.Errorf("completed job has progress %d, want 100", job.Progress)
		}
	case model.JobStatusFailed:
		// Failed jobs should have error message
		if job.ErrorMessage == "" {
			return fmt.Errorf("failed job has empty ErrorMessage")
		}
	case model.JobStatusInProgress:
		if job.StartedAt == nil {
			return fmt.Errorf("in_progress job has nil StartedAt")
		}
	}

	return nil
}
