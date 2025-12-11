package publish

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cuivienor/media-pipeline/internal/db"
	"github.com/cuivienor/media-pipeline/internal/logging"
)

// Jellyfin-supported extras types
var extrasTypes = []string{
	"behind the scenes",
	"deleted scenes",
	"featurettes",
	"interviews",
	"scenes",
	"shorts",
	"trailers",
	"other",
}

// PublishOptions configures the publisher
type PublishOptions struct {
	LibraryMovies string // Destination for movies
	LibraryTV     string // Destination for TV shows
}

// ExtraDir represents an extras directory found in the input
type ExtraDir struct {
	Type  string   // e.g., "featurettes"
	Path  string   // Full path to extras directory
	Files []string // MKV files in the directory
}

// Publisher handles copying media to the library using FileBot
type Publisher struct {
	repo   db.Repository
	logger *logging.Logger
	opts   PublishOptions
}

// NewPublisher creates a new Publisher
func NewPublisher(repo db.Repository, logger *logging.Logger, opts PublishOptions) *Publisher {
	return &Publisher{
		repo:   repo,
		logger: logger,
		opts:   opts,
	}
}

// buildFilebotArgs constructs FileBot CLI arguments
func (p *Publisher) buildFilebotArgs(inputDir string, mediaType string, dbID int) []string {
	var db, output, format string

	if mediaType == "movie" {
		db = "TheMovieDB"
		output = p.opts.LibraryMovies
		format = "{n} ({y})/{n} ({y})"
	} else {
		db = "TheTVDB"
		output = p.opts.LibraryTV
		format = "{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}"
	}

	return []string{
		"-rename", inputDir,
		"--db", db,
		"--output", output,
		"--format", format,
		"-non-strict",
		"--filter", fmt.Sprintf("id == %d", dbID),
		"--action", "copy",
	}
}

// findExtras scans for Jellyfin-compatible extras directories
func (p *Publisher) findExtras(inputDir string) []ExtraDir {
	var extras []ExtraDir

	for _, extType := range extrasTypes {
		extPath := filepath.Join(inputDir, extType)
		if info, err := os.Stat(extPath); err == nil && info.IsDir() {
			files, _ := filepath.Glob(filepath.Join(extPath, "*.mkv"))
			if len(files) > 0 {
				extras = append(extras, ExtraDir{
					Type:  extType,
					Path:  extPath,
					Files: files,
				})
			}
		}
	}

	return extras
}
