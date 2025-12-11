package transcode

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// Logger interface for transcoder logging
type Logger interface {
	Info(format string, args ...interface{})
	Error(format string, args ...interface{})
}

// Transcoder handles video transcoding operations
type Transcoder struct {
	repo   db.Repository
	logger Logger
	opts   TranscodeOptions
}

// NewTranscoder creates a new Transcoder
func NewTranscoder(repo db.Repository, logger Logger, opts TranscodeOptions) *Transcoder {
	return &Transcoder{
		repo:   repo,
		logger: logger,
		opts:   opts,
	}
}

// TranscodeJob processes all files for a transcode job
func (t *Transcoder) TranscodeJob(ctx context.Context, job *model.Job, inputDir, outputDir string, isTV bool) error {
	// Build queue of files to process
	files, err := t.buildQueue(ctx, job.ID, inputDir, isTV)
	if err != nil {
		return fmt.Errorf("failed to build queue: %w", err)
	}

	if len(files) == 0 {
		t.logger.Info("No files to transcode")
		return nil
	}

	t.logger.Info("Found %d file(s) to transcode", len(files))

	// Count pending/completed for resume
	pending := 0
	completed := 0
	for _, f := range files {
		switch f.Status {
		case model.TranscodeFileStatusPending:
			pending++
		case model.TranscodeFileStatusCompleted:
			completed++
		}
	}

	if completed > 0 {
		t.logger.Info("Resuming: %d completed, %d remaining", completed, pending)
	}

	// Process each file
	var lastErr error
	for i, file := range files {
		if file.Status == model.TranscodeFileStatusCompleted {
			continue
		}
		if file.Status == model.TranscodeFileStatusSkipped {
			continue
		}

		inputPath := filepath.Join(inputDir, file.RelativePath)
		outputPath := filepath.Join(outputDir, file.RelativePath)

		t.logger.Info("[%d/%d] Transcoding: %s", i+1, len(files), file.RelativePath)

		if err := t.transcodeFile(ctx, &file, inputPath, outputPath); err != nil {
			t.logger.Error("Failed: %s - %v", file.RelativePath, err)
			lastErr = err
			// Continue with other files
		} else {
			ratio := file.CompressionRatio()
			savedMB := file.SizeSaved() / (1024 * 1024)
			t.logger.Info("Completed: %s (%.1f%% of original, saved %dMB)",
				file.RelativePath, ratio*100, savedMB)
		}
	}

	// Log summary
	t.logSummary(ctx, job.ID)

	return lastErr
}

// buildQueue discovers files and creates/updates database records
func (t *Transcoder) buildQueue(ctx context.Context, jobID int64, inputDir string, isTV bool) ([]model.TranscodeFile, error) {
	// Check for existing files in database (resume case)
	existing, err := t.repo.ListTranscodeFiles(ctx, jobID)
	if err != nil {
		return nil, err
	}

	existingMap := make(map[string]*model.TranscodeFile)
	for i := range existing {
		existingMap[existing[i].RelativePath] = &existing[i]
	}

	// Find all MKV files in input directory (main content and extras)
	var files []model.TranscodeFile

	err = filepath.Walk(inputDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(strings.ToLower(info.Name()), ".mkv") {
			return nil
		}

		relPath, _ := filepath.Rel(inputDir, path)

		// Check if already in database
		if existing, ok := existingMap[relPath]; ok {
			files = append(files, *existing)
			return nil
		}

		// Get duration
		duration, err := GetDuration(path)
		if err != nil {
			t.logger.Error("Could not get duration for %s: %v", relPath, err)
			duration = 0
		}

		// Create new record
		file := &model.TranscodeFile{
			JobID:        jobID,
			RelativePath: relPath,
			Status:       model.TranscodeFileStatusPending,
			InputSize:    info.Size(),
			DurationSecs: duration,
		}

		if err := t.repo.CreateTranscodeFile(ctx, file); err != nil {
			return fmt.Errorf("failed to create transcode file record: %w", err)
		}

		files = append(files, *file)
		return nil
	})

	if err != nil {
		return nil, err
	}

	return files, nil
}

// transcodeFile processes a single file
func (t *Transcoder) transcodeFile(ctx context.Context, file *model.TranscodeFile, inputPath, outputPath string) error {
	// Delete any partial output from previous attempt
	os.Remove(outputPath)

	// Ensure output directory exists
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Mark as in progress
	if err := t.repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusInProgress, ""); err != nil {
		return err
	}

	// Set duration for progress calculation
	opts := t.opts
	opts.DurationSec = file.DurationSecs

	// Track last progress to avoid too many updates
	lastProgress := 0

	// Run ffmpeg with progress callback
	err := TranscodeFile(ctx, inputPath, outputPath, opts, func(percent int) {
		// Only update on 1% increments
		if percent > lastProgress {
			lastProgress = percent
			t.repo.UpdateTranscodeFileProgress(ctx, file.ID, percent)
		}
	})

	if err != nil {
		t.repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusFailed, err.Error())
		return err
	}

	// Get output size
	info, err := os.Stat(outputPath)
	if err != nil {
		t.repo.UpdateTranscodeFileStatus(ctx, file.ID, model.TranscodeFileStatusFailed, "output file not found")
		return fmt.Errorf("output file not found: %w", err)
	}

	// Update file record with results
	file.Status = model.TranscodeFileStatusCompleted
	file.OutputSize = info.Size()
	file.Progress = 100
	if err := t.repo.UpdateTranscodeFile(ctx, file); err != nil {
		return err
	}

	return nil
}

// logSummary logs the final summary
func (t *Transcoder) logSummary(ctx context.Context, jobID int64) {
	files, err := t.repo.ListTranscodeFiles(ctx, jobID)
	if err != nil {
		t.logger.Error("Failed to get summary: %v", err)
		return
	}

	var completed, failed, skipped int
	var totalInput, totalOutput int64

	for _, f := range files {
		switch f.Status {
		case model.TranscodeFileStatusCompleted:
			completed++
			totalInput += f.InputSize
			totalOutput += f.OutputSize
		case model.TranscodeFileStatusFailed:
			failed++
		case model.TranscodeFileStatusSkipped:
			skipped++
		}
	}

	t.logger.Info("Summary: %d completed, %d failed, %d skipped", completed, failed, skipped)

	if totalInput > 0 {
		savedGB := float64(totalInput-totalOutput) / (1024 * 1024 * 1024)
		ratio := float64(totalOutput) / float64(totalInput) * 100
		t.logger.Info("Total: %.2fGB -> %.2fGB (%.1f%%, saved %.2fGB)",
			float64(totalInput)/(1024*1024*1024),
			float64(totalOutput)/(1024*1024*1024),
			ratio, savedGB)
	}
}

