package remux

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Remuxer handles MKV file remuxing with track filtering
type Remuxer struct {
	languages []string
}

// NewRemuxer creates a new Remuxer with the specified language filters
func NewRemuxer(languages []string) *Remuxer {
	return &Remuxer{languages: languages}
}

// RemuxResult contains statistics about a remux operation
type RemuxResult struct {
	InputPath     string
	OutputPath    string
	InputTracks   TrackCounts
	OutputTracks  TrackCounts
	TracksRemoved int
}

// TrackCounts holds counts by track type
type TrackCounts struct {
	Video     int
	Audio     int
	Subtitles int
}

// RemuxFile remuxes a single MKV file, filtering tracks by language
func (r *Remuxer) RemuxFile(ctx context.Context, inputPath, outputPath string) (*RemuxResult, error) {
	// Get track info from input
	inputInfo, err := GetTrackInfo(inputPath)
	if err != nil {
		return nil, fmt.Errorf("failed to analyze %s: %w", inputPath, err)
	}

	// Filter tracks
	filteredInfo := FilterTracks(inputInfo, r.languages)

	// Ensure output directory exists
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create output directory: %w", err)
	}

	// Build and run mkvmerge
	args := BuildMkvmergeArgs(inputPath, outputPath, filteredInfo)
	if err := RunMkvmerge(args); err != nil {
		return nil, err
	}

	inputCounts := TrackCounts{
		Video:     len(inputInfo.Video),
		Audio:     len(inputInfo.Audio),
		Subtitles: len(inputInfo.Subtitles),
	}
	outputCounts := TrackCounts{
		Video:     len(filteredInfo.Video),
		Audio:     len(filteredInfo.Audio),
		Subtitles: len(filteredInfo.Subtitles),
	}

	return &RemuxResult{
		InputPath:    inputPath,
		OutputPath:   outputPath,
		InputTracks:  inputCounts,
		OutputTracks: outputCounts,
		TracksRemoved: (inputCounts.Audio - outputCounts.Audio) +
			(inputCounts.Subtitles - outputCounts.Subtitles),
	}, nil
}

// RemuxDirectory remuxes all MKV files in a directory
// For movies: remuxes _main/*.mkv files
// For TV: remuxes _episodes/*.mkv files, preserving episode names
func (r *Remuxer) RemuxDirectory(ctx context.Context, inputDir, outputDir string, isTV bool) ([]RemuxResult, error) {
	var results []RemuxResult

	// Determine input subdirectory
	var srcDir string
	if isTV {
		srcDir = filepath.Join(inputDir, "_episodes")
	} else {
		srcDir = filepath.Join(inputDir, "_main")
	}

	// Find MKV files
	entries, err := os.ReadDir(srcDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory %s: %w", srcDir, err)
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if !strings.HasSuffix(strings.ToLower(entry.Name()), ".mkv") {
			continue
		}

		inputPath := filepath.Join(srcDir, entry.Name())

		// Determine output path
		var outputPath string
		if isTV {
			// TV: preserve episode naming in _episodes
			outputPath = filepath.Join(outputDir, "_episodes", entry.Name())
		} else {
			// Movie: single file in _main
			outputPath = filepath.Join(outputDir, "_main", entry.Name())
		}

		result, err := r.RemuxFile(ctx, inputPath, outputPath)
		if err != nil {
			return results, fmt.Errorf("failed to remux %s: %w", entry.Name(), err)
		}
		results = append(results, *result)
	}

	// Also copy extras if present
	extrasDir := filepath.Join(inputDir, "_extras")
	if _, err := os.Stat(extrasDir); err == nil {
		outputExtras := filepath.Join(outputDir, "_extras")
		if err := copyDirectory(extrasDir, outputExtras); err != nil {
			return results, fmt.Errorf("failed to copy extras: %w", err)
		}
	}

	return results, nil
}

// copyDirectory copies a directory recursively
func copyDirectory(src, dst string) error {
	if err := os.MkdirAll(dst, 0755); err != nil {
		return err
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())

		if entry.IsDir() {
			if err := copyDirectory(srcPath, dstPath); err != nil {
				return err
			}
		} else {
			if err := copyFile(srcPath, dstPath); err != nil {
				return err
			}
		}
	}

	return nil
}

// copyFile copies a single file
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}
