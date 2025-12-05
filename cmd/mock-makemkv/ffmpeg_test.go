package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// ffprobeResult is used to parse ffprobe JSON output
type ffprobeResult struct {
	Streams []struct {
		Index     int    `json:"index"`
		CodecType string `json:"codec_type"`
		CodecName string `json:"codec_name"`
		Width     int    `json:"width,omitempty"`
		Height    int    `json:"height,omitempty"`
	} `json:"streams"`
	Format struct {
		Duration string `json:"duration"`
	} `json:"format"`
}

func skipIfNoFFmpeg(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not found in PATH, skipping test")
	}
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not found in PATH, skipping test")
	}
}

func TestGenerateSyntheticMKV_CreatesFile(t *testing.T) {
	skipIfNoFFmpeg(t)

	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "test.mkv")

	err := GenerateSyntheticMKV(outputPath, 5*time.Second)
	if err != nil {
		t.Fatalf("GenerateSyntheticMKV failed: %v", err)
	}

	if _, err := os.Stat(outputPath); os.IsNotExist(err) {
		t.Error("Output file was not created")
	}
}

func TestGenerateSyntheticMKV_HasVideoStream(t *testing.T) {
	skipIfNoFFmpeg(t)

	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "test.mkv")

	if err := GenerateSyntheticMKV(outputPath, 5*time.Second); err != nil {
		t.Fatalf("GenerateSyntheticMKV failed: %v", err)
	}

	result := probeFile(t, outputPath)

	hasVideo := false
	for _, stream := range result.Streams {
		if stream.CodecType == "video" {
			hasVideo = true
			break
		}
	}
	if !hasVideo {
		t.Error("Generated MKV has no video stream")
	}
}

func TestGenerateSyntheticMKV_HasAudioStream(t *testing.T) {
	skipIfNoFFmpeg(t)

	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "test.mkv")

	if err := GenerateSyntheticMKV(outputPath, 5*time.Second); err != nil {
		t.Fatalf("GenerateSyntheticMKV failed: %v", err)
	}

	result := probeFile(t, outputPath)

	hasAudio := false
	for _, stream := range result.Streams {
		if stream.CodecType == "audio" {
			hasAudio = true
			break
		}
	}
	if !hasAudio {
		t.Error("Generated MKV has no audio stream")
	}
}

func TestGenerateSyntheticMKV_CorrectDuration(t *testing.T) {
	skipIfNoFFmpeg(t)

	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "test.mkv")
	expectedDuration := 5 * time.Second

	if err := GenerateSyntheticMKV(outputPath, expectedDuration); err != nil {
		t.Fatalf("GenerateSyntheticMKV failed: %v", err)
	}

	result := probeFile(t, outputPath)

	// Parse duration (ffprobe returns it as a string like "5.000000")
	var duration float64
	if _, err := parseFloat(result.Format.Duration, &duration); err != nil {
		t.Fatalf("Failed to parse duration: %v", err)
	}

	// Allow 0.5 second tolerance
	if duration < 4.5 || duration > 5.5 {
		t.Errorf("Duration = %v seconds, want approximately 5 seconds", duration)
	}
}

func TestGenerateSyntheticMKV_CreatesParentDir(t *testing.T) {
	skipIfNoFFmpeg(t)

	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "subdir", "nested", "test.mkv")

	err := GenerateSyntheticMKV(outputPath, 5*time.Second)
	if err != nil {
		t.Fatalf("GenerateSyntheticMKV failed: %v", err)
	}

	if _, err := os.Stat(outputPath); os.IsNotExist(err) {
		t.Error("Output file was not created in nested directory")
	}
}

// probeFile uses ffprobe to get info about a media file
func probeFile(t *testing.T, path string) *ffprobeResult {
	t.Helper()

	cmd := exec.Command("ffprobe", "-v", "quiet", "-print_format", "json",
		"-show_format", "-show_streams", path)
	output, err := cmd.Output()
	if err != nil {
		t.Fatalf("ffprobe failed for %s: %v", path, err)
	}

	var result ffprobeResult
	if err := json.Unmarshal(output, &result); err != nil {
		t.Fatalf("Failed to parse ffprobe output: %v", err)
	}

	return &result
}

// parseFloat is a simple wrapper for parsing floats from strings
func parseFloat(s string, result *float64) (int, error) {
	var n int
	_, err := parseFloatHelper(s, result)
	return n, err
}

func parseFloatHelper(s string, result *float64) (int, error) {
	var f float64
	n, err := jsonParseFloat(s, &f)
	if err == nil {
		*result = f
	}
	return n, err
}

func jsonParseFloat(s string, result *float64) (int, error) {
	return 0, json.Unmarshal([]byte(s), result)
}
