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
	"github.com/cuivienor/media-pipeline/internal/model"
	"github.com/cuivienor/media-pipeline/internal/remux"
)

func main() {
	var jobID int64
	var dbPath string

	flag.Int64Var(&jobID, "job-id", 0, "Job ID to execute")
	flag.StringVar(&dbPath, "db", "", "Path to database")
	flag.Parse()

	if jobID == 0 || dbPath == "" {
		fmt.Fprintln(os.Stderr, "Usage: remux -job-id <id> -db <path>")
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

	// Load config for languages
	cfg, err := config.LoadFromMediaBase()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Find input directory from organize job
	inputDir, err := findOrganizeOutput(ctx, repo, job)
	if err != nil {
		return fmt.Errorf("failed to find input: %w", err)
	}

	// Determine output directory
	outputDir := buildOutputPath(cfg, item, job)

	// Update job to in_progress with input/output paths
	job.Status = model.JobStatusInProgress
	job.InputDir = inputDir
	job.OutputDir = outputDir
	now := time.Now()
	job.StartedAt = &now
	if err := repo.UpdateJob(ctx, job); err != nil {
		return fmt.Errorf("failed to update job status: %w", err)
	}

	fmt.Printf("Remux: %s\n", item.Name)
	fmt.Printf("  Input:  %s\n", inputDir)
	fmt.Printf("  Output: %s\n", outputDir)
	fmt.Printf("  Languages: %v\n", cfg.RemuxLanguages())

	// Create remuxer and process
	remuxer := remux.NewRemuxer(cfg.RemuxLanguages())
	isTV := item.Type == model.MediaTypeTV

	results, err := remuxer.RemuxDirectory(ctx, inputDir, outputDir, isTV)
	if err != nil {
		// Mark job as failed
		repo.UpdateJobStatus(ctx, jobID, model.JobStatusFailed, err.Error())
		return err
	}

	// Log results
	totalRemoved := 0
	for _, r := range results {
		fmt.Printf("  Processed: %s (%d tracks removed)\n",
			filepath.Base(r.InputPath), r.TracksRemoved)
		totalRemoved += r.TracksRemoved
	}
	fmt.Printf("  Total: %d files, %d tracks removed\n", len(results), totalRemoved)

	// Mark job as complete
	if err := repo.UpdateJobStatus(ctx, jobID, model.JobStatusCompleted, ""); err != nil {
		return fmt.Errorf("failed to update job status: %w", err)
	}

	// Update media item stage
	if err := repo.UpdateMediaItemStage(ctx, item.ID, model.StageRemux, model.StatusCompleted); err != nil {
		return fmt.Errorf("failed to update item stage: %w", err)
	}

	fmt.Println("Remux complete!")
	return nil
}

// findOrganizeOutput finds the output directory from the organize stage
func findOrganizeOutput(ctx context.Context, repo db.Repository, job *model.Job) (string, error) {
	// Look for completed organize job for this media item
	jobs, err := repo.ListJobsForMedia(ctx, job.MediaItemID)
	if err != nil {
		return "", err
	}

	// Find the most recent completed organize job
	for i := len(jobs) - 1; i >= 0; i-- {
		j := jobs[i]
		if j.Stage == model.StageOrganize && j.Status == model.JobStatusCompleted {
			if j.OutputDir != "" {
				return j.OutputDir, nil
			}
		}
	}

	return "", fmt.Errorf("no completed organize job found for media item %d", job.MediaItemID)
}

// buildOutputPath constructs the output directory for remuxed files
func buildOutputPath(cfg *config.Config, item *model.MediaItem, job *model.Job) string {
	// Output goes to staging/2-remuxed/{movies,tv}/{safe_name}
	mediaTypeDir := "movies"
	if item.Type == model.MediaTypeTV {
		mediaTypeDir = "tv"
	}

	baseName := item.SafeName
	if item.Type == model.MediaTypeTV && job.SeasonID != nil {
		// Include season in path for TV
		// TODO: Look up season number from SeasonID
		baseName = fmt.Sprintf("%s/Season_XX", item.SafeName)
	}

	return filepath.Join(cfg.StagingBase, "2-remuxed", mediaTypeDir, baseName)
}
