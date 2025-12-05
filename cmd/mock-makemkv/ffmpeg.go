package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// GenerateSyntheticMKV creates a minimal MKV file using ffmpeg
// with the specified duration. The file contains:
// - Video: test pattern (testsrc)
// - Audio: silent audio (anullsrc)
func GenerateSyntheticMKV(outputPath string, duration time.Duration) error {
	// Create parent directory if needed
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	durationSec := int(duration.Seconds())
	if durationSec < 1 {
		durationSec = 1
	}

	// Build ffmpeg command
	// Uses:
	// - testsrc: generates a test video pattern
	// - anullsrc: generates silent audio
	// - libx264 with ultrafast preset for speed
	// - aac for audio codec
	args := []string{
		"-f", "lavfi",
		"-i", fmt.Sprintf("testsrc=duration=%d:size=1280x720:rate=24", durationSec),
		"-f", "lavfi",
		"-i", fmt.Sprintf("anullsrc=r=48000:cl=stereo:d=%d", durationSec),
		"-c:v", "libx264",
		"-preset", "ultrafast",
		"-c:a", "aac",
		"-shortest",
		"-y", // Overwrite output file if it exists
		outputPath,
	}

	cmd := exec.Command("ffmpeg", args...)

	// Capture stderr for error messages (ffmpeg writes to stderr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg failed: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// GenerateMultipleMKVs creates multiple MKV files for a disc profile
func GenerateMultipleMKVs(outputDir string, profile *DiscProfile, duration time.Duration) error {
	for _, title := range profile.Titles {
		outputPath := filepath.Join(outputDir, title.Filename)
		if err := GenerateSyntheticMKV(outputPath, duration); err != nil {
			return fmt.Errorf("failed to generate %s: %w", title.Filename, err)
		}
	}
	return nil
}
