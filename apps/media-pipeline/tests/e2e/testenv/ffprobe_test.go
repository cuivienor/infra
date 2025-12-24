package testenv

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func skipIfNoFFprobe(t *testing.T) {
	t.Helper()
	if _, err := exec.LookPath("ffprobe"); err != nil {
		t.Skip("ffprobe not found in PATH, skipping test")
	}
}

func createTestMKV(t *testing.T, path string) {
	t.Helper()
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not found in PATH, skipping test")
	}

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatalf("failed to create dir: %v", err)
	}

	// Create a minimal MKV with video and audio
	cmd := exec.Command("ffmpeg", "-y",
		"-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=24",
		"-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo:d=1",
		"-c:v", "libx264", "-preset", "ultrafast",
		"-c:a", "aac",
		"-shortest",
		path)

	if err := cmd.Run(); err != nil {
		t.Fatalf("failed to create test MKV: %v", err)
	}
}

func TestProbeFile_ParsesValidMKV(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	result, err := ProbeFile(testFile)
	if err != nil {
		t.Fatalf("ProbeFile failed: %v", err)
	}

	if len(result.Streams) == 0 {
		t.Error("Expected at least one stream")
	}
	if result.Format.Filename == "" {
		t.Error("Expected filename in format")
	}
}

func TestProbeFile_ReturnsErrorForNonexistent(t *testing.T) {
	_, err := ProbeFile("/nonexistent/file.mkv")
	if err == nil {
		t.Error("Expected error for nonexistent file")
	}
}

func TestHasVideoStream_TrueForVideoFile(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	result, _ := ProbeFile(testFile)
	if !result.HasVideoStream() {
		t.Error("Expected HasVideoStream to return true")
	}
}

func TestHasAudioStream_TrueForAudioFile(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	result, _ := ProbeFile(testFile)
	if !result.HasAudioStream() {
		t.Error("Expected HasAudioStream to return true")
	}
}

func TestStreamCount_ReturnsCorrectCount(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	result, _ := ProbeFile(testFile)

	// Our test file has 1 video + 1 audio = 2 streams
	if result.StreamCount() < 2 {
		t.Errorf("StreamCount = %d, expected at least 2", result.StreamCount())
	}
}

func TestVideoStreamCount_ReturnsCorrectCount(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	result, _ := ProbeFile(testFile)

	if result.VideoStreamCount() != 1 {
		t.Errorf("VideoStreamCount = %d, want 1", result.VideoStreamCount())
	}
}

func TestAudioStreamCount_ReturnsCorrectCount(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	result, _ := ProbeFile(testFile)

	if result.AudioStreamCount() != 1 {
		t.Errorf("AudioStreamCount = %d, want 1", result.AudioStreamCount())
	}
}

func TestAssertValidMKV_PassesForValidFile(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	// This should not panic or fail
	AssertValidMKV(t, testFile)
}

func TestAssertHasVideoStream_PassesForVideoFile(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	// This should not panic or fail
	AssertHasVideoStream(t, testFile)
}

func TestAssertHasAudioStream_PassesForAudioFile(t *testing.T) {
	skipIfNoFFprobe(t)

	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.mkv")
	createTestMKV(t, testFile)

	// This should not panic or fail
	AssertHasAudioStream(t, testFile)
}
