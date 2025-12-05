package main

import (
	"testing"

	"github.com/cuivienor/media-pipeline/internal/ripper"
)

func TestParseArgs_MovieShort(t *testing.T) {
	args := []string{"-t", "movie", "-n", "The Matrix"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.Type != ripper.MediaTypeMovie {
		t.Errorf("Type = %v, want movie", opts.Type)
	}
	if opts.Name != "The Matrix" {
		t.Errorf("Name = %q, want 'The Matrix'", opts.Name)
	}
}

func TestParseArgs_MovieLong(t *testing.T) {
	args := []string{"--type", "movie", "--name", "The Matrix"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.Type != ripper.MediaTypeMovie {
		t.Errorf("Type = %v, want movie", opts.Type)
	}
}

func TestParseArgs_TVShow(t *testing.T) {
	args := []string{"-t", "tv", "-n", "Breaking Bad", "-s", "1", "-d", "2"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.Type != ripper.MediaTypeTV {
		t.Errorf("Type = %v, want tv", opts.Type)
	}
	if opts.Name != "Breaking Bad" {
		t.Errorf("Name = %q, want 'Breaking Bad'", opts.Name)
	}
	if opts.Season != 1 {
		t.Errorf("Season = %d, want 1", opts.Season)
	}
	if opts.Disc != 2 {
		t.Errorf("Disc = %d, want 2", opts.Disc)
	}
}

func TestParseArgs_TVShowLong(t *testing.T) {
	args := []string{"--type", "tv", "--name", "Avatar", "--season", "2", "--disc", "3"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.Season != 2 {
		t.Errorf("Season = %d, want 2", opts.Season)
	}
	if opts.Disc != 3 {
		t.Errorf("Disc = %d, want 3", opts.Disc)
	}
}

func TestParseArgs_MissingType(t *testing.T) {
	args := []string{"-n", "The Matrix"}

	_, err := ParseArgs(args)
	if err == nil {
		t.Error("Expected error for missing type")
	}
}

func TestParseArgs_MissingName(t *testing.T) {
	args := []string{"-t", "movie"}

	_, err := ParseArgs(args)
	if err == nil {
		t.Error("Expected error for missing name")
	}
}

func TestParseArgs_TVMissingSeason(t *testing.T) {
	args := []string{"-t", "tv", "-n", "Breaking Bad", "-d", "1"}

	_, err := ParseArgs(args)
	if err == nil {
		t.Error("Expected error for TV show missing season")
	}
}

func TestParseArgs_TVMissingDisc(t *testing.T) {
	args := []string{"-t", "tv", "-n", "Breaking Bad", "-s", "1"}

	_, err := ParseArgs(args)
	if err == nil {
		t.Error("Expected error for TV show missing disc")
	}
}

func TestParseArgs_DiscPath(t *testing.T) {
	args := []string{"-t", "movie", "-n", "The Matrix", "--disc-path", "/dev/sr0"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.DiscPath != "/dev/sr0" {
		t.Errorf("DiscPath = %q, want '/dev/sr0'", opts.DiscPath)
	}
}

func TestParseArgs_DefaultDiscPath(t *testing.T) {
	args := []string{"-t", "movie", "-n", "The Matrix"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.DiscPath != "disc:0" {
		t.Errorf("DiscPath = %q, want 'disc:0'", opts.DiscPath)
	}
}

func TestParseArgs_InvalidType(t *testing.T) {
	args := []string{"-t", "invalid", "-n", "The Matrix"}

	_, err := ParseArgs(args)
	if err == nil {
		t.Error("Expected error for invalid type")
	}
}

func TestParseArgs_TypeAliases(t *testing.T) {
	// "show" should be accepted as alias for "tv"
	args := []string{"-t", "show", "-n", "Breaking Bad", "-s", "1", "-d", "1"}

	opts, err := ParseArgs(args)
	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}

	if opts.Type != ripper.MediaTypeTV {
		t.Errorf("Type = %v, want tv", opts.Type)
	}
}

func TestBuildConfig_DefaultMediaBase(t *testing.T) {
	opts := &Options{
		Type: ripper.MediaTypeMovie,
		Name: "Test",
	}

	config := BuildConfig(opts, nil)

	if config.MediaBase == "" {
		t.Error("MediaBase should have a default value")
	}
}

func TestBuildConfig_EnvOverride(t *testing.T) {
	opts := &Options{
		Type: ripper.MediaTypeMovie,
		Name: "Test",
	}

	env := map[string]string{
		"MEDIA_BASE": "/custom/path",
	}

	config := BuildConfig(opts, env)

	if config.MediaBase != "/custom/path" {
		t.Errorf("MediaBase = %q, want '/custom/path'", config.MediaBase)
	}
}

func TestBuildConfig_MakeMKVConPath(t *testing.T) {
	opts := &Options{
		Type: ripper.MediaTypeMovie,
		Name: "Test",
	}

	env := map[string]string{
		"MAKEMKVCON_PATH": "/usr/local/bin/mock-makemkv",
	}

	config := BuildConfig(opts, env)

	if config.MakeMKVConPath != "/usr/local/bin/mock-makemkv" {
		t.Errorf("MakeMKVConPath = %q, want '/usr/local/bin/mock-makemkv'", config.MakeMKVConPath)
	}
}

func TestBuildRipRequest(t *testing.T) {
	opts := &Options{
		Type:     ripper.MediaTypeTV,
		Name:     "Breaking Bad",
		Season:   2,
		Disc:     3,
		DiscPath: "disc:0",
	}

	req := BuildRipRequest(opts)

	if req.Type != ripper.MediaTypeTV {
		t.Errorf("Type = %v, want tv", req.Type)
	}
	if req.Name != "Breaking Bad" {
		t.Errorf("Name = %q, want 'Breaking Bad'", req.Name)
	}
	if req.Season != 2 {
		t.Errorf("Season = %d, want 2", req.Season)
	}
	if req.Disc != 3 {
		t.Errorf("Disc = %d, want 3", req.Disc)
	}
}
