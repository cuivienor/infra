package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseArgs_InfoCommand(t *testing.T) {
	args := []string{"mock-makemkv", "info", "disc:0"}
	cmd, opts, err := ParseArgs(args)

	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}
	if cmd != "info" {
		t.Errorf("cmd = %q, want info", cmd)
	}
	if opts.DiscPath != "disc:0" {
		t.Errorf("DiscPath = %q, want disc:0", opts.DiscPath)
	}
}

func TestParseArgs_MkvCommand(t *testing.T) {
	args := []string{"mock-makemkv", "mkv", "disc:0", "all", "/output/dir"}
	cmd, opts, err := ParseArgs(args)

	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}
	if cmd != "mkv" {
		t.Errorf("cmd = %q, want mkv", cmd)
	}
	if opts.DiscPath != "disc:0" {
		t.Errorf("DiscPath = %q, want disc:0", opts.DiscPath)
	}
	if opts.Titles != "all" {
		t.Errorf("Titles = %q, want all", opts.Titles)
	}
	if opts.OutputDir != "/output/dir" {
		t.Errorf("OutputDir = %q, want /output/dir", opts.OutputDir)
	}
}

func TestParseArgs_MissingCommand(t *testing.T) {
	args := []string{"mock-makemkv"}
	_, _, err := ParseArgs(args)

	if err == nil {
		t.Error("Expected error for missing command")
	}
}

func TestParseArgs_UnknownCommand(t *testing.T) {
	args := []string{"mock-makemkv", "unknown"}
	_, _, err := ParseArgs(args)

	if err == nil {
		t.Error("Expected error for unknown command")
	}
}

func TestParseArgs_WithProfile(t *testing.T) {
	args := []string{"mock-makemkv", "--profile", "simpsons_s01d01", "info", "disc:0"}
	cmd, opts, err := ParseArgs(args)

	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}
	if cmd != "info" {
		t.Errorf("cmd = %q, want info", cmd)
	}
	if opts.ProfileName != "simpsons_s01d01" {
		t.Errorf("ProfileName = %q, want simpsons_s01d01", opts.ProfileName)
	}
}

func TestParseArgs_WithDelay(t *testing.T) {
	args := []string{"mock-makemkv", "--delay", "100ms", "mkv", "disc:0", "all", "/out"}
	_, opts, err := ParseArgs(args)

	if err != nil {
		t.Fatalf("ParseArgs failed: %v", err)
	}
	if opts.Delay.Milliseconds() != 100 {
		t.Errorf("Delay = %v, want 100ms", opts.Delay)
	}
}

func TestRunInfo_OutputsDiscInfo(t *testing.T) {
	var buf bytes.Buffer
	opts := &Options{
		ProfileName: "big_buck_bunny",
		DiscPath:    "disc:0",
	}

	err := RunInfo(&buf, opts)
	if err != nil {
		t.Fatalf("RunInfo failed: %v", err)
	}

	output := buf.String()

	// Should contain disc info
	if !strings.Contains(output, "CINFO:") {
		t.Error("Expected CINFO in output")
	}
	if !strings.Contains(output, "TCOUT:") {
		t.Error("Expected TCOUT in output")
	}
	if !strings.Contains(output, "TINFO:") {
		t.Error("Expected TINFO in output")
	}
	if !strings.Contains(output, "Big Buck Bunny") {
		t.Error("Expected disc name in output")
	}
}

func TestRunInfo_TVProfile(t *testing.T) {
	var buf bytes.Buffer
	opts := &Options{
		ProfileName: "simpsons_s01d01",
		DiscPath:    "disc:0",
	}

	err := RunInfo(&buf, opts)
	if err != nil {
		t.Fatalf("RunInfo failed: %v", err)
	}

	output := buf.String()

	// Should have 5 titles for Simpsons disc
	if !strings.Contains(output, "TCOUT:5") {
		t.Errorf("Expected TCOUT:5 for TV disc, got:\n%s", output)
	}
}

func TestRunMkv_CreatesOutputDir(t *testing.T) {
	tmpDir := t.TempDir()
	outputDir := filepath.Join(tmpDir, "newdir", "output")

	var buf bytes.Buffer
	opts := &Options{
		ProfileName: "big_buck_bunny",
		DiscPath:    "disc:0",
		Titles:      "all",
		OutputDir:   outputDir,
		SkipFFmpeg:  true, // Skip actual ffmpeg for this test
	}

	err := RunMkv(&buf, opts)
	if err != nil {
		t.Fatalf("RunMkv failed: %v", err)
	}

	if _, err := os.Stat(outputDir); os.IsNotExist(err) {
		t.Error("Output directory was not created")
	}
}

func TestRunMkv_OutputsProgress(t *testing.T) {
	tmpDir := t.TempDir()

	var buf bytes.Buffer
	opts := &Options{
		ProfileName: "big_buck_bunny",
		DiscPath:    "disc:0",
		Titles:      "all",
		OutputDir:   tmpDir,
		SkipFFmpeg:  true,
	}

	err := RunMkv(&buf, opts)
	if err != nil {
		t.Fatalf("RunMkv failed: %v", err)
	}

	output := buf.String()

	// Should contain progress output
	if !strings.Contains(output, "PRGV:") {
		t.Error("Expected PRGV progress in output")
	}
}

// Integration test - only runs if ffmpeg available
func TestIntegration_MkvCreatesRealFiles(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not found in PATH, skipping integration test")
	}

	tmpDir := t.TempDir()

	var buf bytes.Buffer
	opts := &Options{
		ProfileName: "big_buck_bunny",
		DiscPath:    "disc:0",
		Titles:      "all",
		OutputDir:   tmpDir,
		SkipFFmpeg:  false,
	}

	err := RunMkv(&buf, opts)
	if err != nil {
		t.Fatalf("RunMkv failed: %v", err)
	}

	// Check that MKV files were created
	files, _ := filepath.Glob(filepath.Join(tmpDir, "*.mkv"))
	if len(files) == 0 {
		t.Error("No MKV files were created")
	}
}
