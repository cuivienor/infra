package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cuivienor/media-pipeline/internal/ripper"
)

const defaultMediaBase = "/mnt/media"

// Options holds parsed command-line options
type Options struct {
	Type     ripper.MediaType
	Name     string
	Season   int
	Disc     int
	DiscPath string
}

// Config holds runtime configuration
type Config struct {
	MediaBase      string
	MakeMKVConPath string
}

func main() {
	opts, err := ParseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		fmt.Fprintf(os.Stderr, "Usage: ripper -t <movie|tv> -n <name> [-s <season>] [-d <disc>] [--disc-path <path>]\n")
		os.Exit(1)
	}

	// Build configuration from environment
	env := getEnvMap()
	config := BuildConfig(opts, env)

	// Create ripper
	stagingBase := filepath.Join(config.MediaBase, "staging")
	runner := ripper.NewMakeMKVRunner(config.MakeMKVConPath)
	r := ripper.NewRipper(stagingBase, runner, nil)

	// Build request
	req := BuildRipRequest(opts)

	// Run the rip
	result, err := r.Rip(context.Background(), req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Rip completed successfully!\n")
	fmt.Printf("Output: %s\n", result.OutputDir)
	fmt.Printf("Duration: %s\n", result.Duration())
}

// ParseArgs parses command-line arguments
func ParseArgs(args []string) (*Options, error) {
	fs := flag.NewFlagSet("ripper", flag.ContinueOnError)

	var typeStr string
	var name string
	var season, disc int
	var discPath string

	fs.StringVar(&typeStr, "t", "", "Media type: movie or tv/show")
	fs.StringVar(&typeStr, "type", "", "Media type: movie or tv/show")
	fs.StringVar(&name, "n", "", "Media name")
	fs.StringVar(&name, "name", "", "Media name")
	fs.IntVar(&season, "s", 0, "Season number (TV only)")
	fs.IntVar(&season, "season", 0, "Season number (TV only)")
	fs.IntVar(&disc, "d", 0, "Disc number (TV only)")
	fs.IntVar(&disc, "disc", 0, "Disc number (TV only)")
	fs.StringVar(&discPath, "disc-path", "disc:0", "Path to disc device")

	if err := fs.Parse(args); err != nil {
		return nil, err
	}

	// Validate required fields
	if typeStr == "" {
		return nil, errors.New("type (-t) is required")
	}
	if name == "" {
		return nil, errors.New("name (-n) is required")
	}

	// Parse type
	var mediaType ripper.MediaType
	switch strings.ToLower(typeStr) {
	case "movie":
		mediaType = ripper.MediaTypeMovie
	case "tv", "show":
		mediaType = ripper.MediaTypeTV
	default:
		return nil, fmt.Errorf("invalid type %q: must be movie, tv, or show", typeStr)
	}

	// Validate TV-specific requirements
	if mediaType == ripper.MediaTypeTV {
		if season <= 0 {
			return nil, errors.New("season (-s) is required for TV shows")
		}
		if disc <= 0 {
			return nil, errors.New("disc (-d) is required for TV shows")
		}
	}

	return &Options{
		Type:     mediaType,
		Name:     name,
		Season:   season,
		Disc:     disc,
		DiscPath: discPath,
	}, nil
}

// BuildConfig creates runtime configuration from options and environment
func BuildConfig(opts *Options, env map[string]string) *Config {
	config := &Config{
		MediaBase: defaultMediaBase,
	}

	if env != nil {
		if val, ok := env["MEDIA_BASE"]; ok && val != "" {
			config.MediaBase = val
		}
		if val, ok := env["MAKEMKVCON_PATH"]; ok && val != "" {
			config.MakeMKVConPath = val
		}
	}

	return config
}

// BuildRipRequest creates a RipRequest from options
func BuildRipRequest(opts *Options) *ripper.RipRequest {
	return &ripper.RipRequest{
		Type:     opts.Type,
		Name:     opts.Name,
		Season:   opts.Season,
		Disc:     opts.Disc,
		DiscPath: opts.DiscPath,
	}
}

// getEnvMap returns environment variables as a map
func getEnvMap() map[string]string {
	return map[string]string{
		"MEDIA_BASE":      os.Getenv("MEDIA_BASE"),
		"MAKEMKVCON_PATH": os.Getenv("MAKEMKVCON_PATH"),
	}
}
