package testutil

import (
	"context"
	"os"
	"path/filepath"

	"github.com/cuivienor/media-pipeline/internal/model"
)

// AssertJobCompleted verifies a job exists and has completed status
func (e *TestEnv) AssertJobCompleted(jobID int64) {
	e.t.Helper()
	ctx := context.Background()

	job, err := e.Repo.GetJob(ctx, jobID)
	if err != nil {
		e.t.Fatalf("AssertJobCompleted: GetJob error: %v", err)
	}
	if job == nil {
		e.t.Fatalf("AssertJobCompleted: job %d not found", jobID)
	}
	if job.Status != model.JobStatusCompleted {
		e.t.Errorf("AssertJobCompleted: job %d status = %v, want %v", jobID, job.Status, model.JobStatusCompleted)
	}
}

// AssertJobFailed verifies a job exists and has failed status
func (e *TestEnv) AssertJobFailed(jobID int64) {
	e.t.Helper()
	ctx := context.Background()

	job, err := e.Repo.GetJob(ctx, jobID)
	if err != nil {
		e.t.Fatalf("AssertJobFailed: GetJob error: %v", err)
	}
	if job == nil {
		e.t.Fatalf("AssertJobFailed: job %d not found", jobID)
	}
	if job.Status != model.JobStatusFailed {
		e.t.Errorf("AssertJobFailed: job %d status = %v, want %v", jobID, job.Status, model.JobStatusFailed)
	}
}

// AssertDirExists verifies a directory exists relative to BaseDir
func (e *TestEnv) AssertDirExists(relPath string) {
	e.t.Helper()

	fullPath := filepath.Join(e.BaseDir, relPath)
	info, err := os.Stat(fullPath)
	if os.IsNotExist(err) {
		e.t.Errorf("AssertDirExists: directory does not exist: %s", relPath)
		return
	}
	if err != nil {
		e.t.Fatalf("AssertDirExists: stat error: %v", err)
	}
	if !info.IsDir() {
		e.t.Errorf("AssertDirExists: path is not a directory: %s", relPath)
	}
}

// AssertFileExists verifies a file exists relative to BaseDir
func (e *TestEnv) AssertFileExists(relPath string) {
	e.t.Helper()

	fullPath := filepath.Join(e.BaseDir, relPath)
	info, err := os.Stat(fullPath)
	if os.IsNotExist(err) {
		e.t.Errorf("AssertFileExists: file does not exist: %s", relPath)
		return
	}
	if err != nil {
		e.t.Fatalf("AssertFileExists: stat error: %v", err)
	}
	if info.IsDir() {
		e.t.Errorf("AssertFileExists: path is a directory, not a file: %s", relPath)
	}
}

// AssertFileNonEmpty verifies a file exists and has non-zero size
func (e *TestEnv) AssertFileNonEmpty(relPath string) {
	e.t.Helper()

	fullPath := filepath.Join(e.BaseDir, relPath)
	info, err := os.Stat(fullPath)
	if os.IsNotExist(err) {
		e.t.Errorf("AssertFileNonEmpty: file does not exist: %s", relPath)
		return
	}
	if err != nil {
		e.t.Fatalf("AssertFileNonEmpty: stat error: %v", err)
	}
	if info.Size() == 0 {
		e.t.Errorf("AssertFileNonEmpty: file is empty: %s", relPath)
	}
}
