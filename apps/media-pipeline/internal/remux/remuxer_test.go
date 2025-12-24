package remux

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestNewRemuxer(t *testing.T) {
	languages := []string{"eng", "bul"}
	remuxer := NewRemuxer(languages)

	if remuxer == nil {
		t.Fatal("NewRemuxer returned nil")
	}

	// Note: languages field is private, so we can't check it directly
	// This test mainly verifies the constructor doesn't panic
}

func TestRemuxer_RemuxFile(t *testing.T) {
	// Skip if mkvmerge not available
	if _, err := exec.LookPath("mkvmerge"); err != nil {
		t.Skip("mkvmerge not installed, skipping integration test")
	}

	// Skip if ffmpeg not available (needed to generate test files)
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed, skipping integration test")
	}

	tmpDir := t.TempDir()
	inputPath := filepath.Join(tmpDir, "input.mkv")
	outputPath := filepath.Join(tmpDir, "output.mkv")

	// Generate a simple test MKV file with multiple audio tracks
	if err := generateSimpleTestMKV(inputPath); err != nil {
		t.Skipf("Could not generate test MKV: %v", err)
	}

	remuxer := NewRemuxer([]string{"eng", "bul"})

	result, err := remuxer.RemuxFile(context.Background(), inputPath, outputPath)
	if err != nil {
		t.Fatalf("RemuxFile() error = %v", err)
	}

	// Verify result fields
	if result.InputPath != inputPath {
		t.Errorf("InputPath = %q, want %q", result.InputPath, inputPath)
	}
	if result.OutputPath != outputPath {
		t.Errorf("OutputPath = %q, want %q", result.OutputPath, outputPath)
	}

	// Verify output file exists
	if _, err := os.Stat(outputPath); err != nil {
		t.Errorf("Output file not created: %v", err)
	}

	// Verify track counts are populated
	if result.InputTracks.Video == 0 {
		t.Error("Expected video tracks in input")
	}
	if result.InputTracks.Audio == 0 {
		t.Error("Expected audio tracks in input")
	}

	// Verify output has tracks
	if result.OutputTracks.Video == 0 {
		t.Error("Expected video tracks in output")
	}
	if result.OutputTracks.Audio == 0 {
		t.Error("Expected audio tracks in output")
	}
}

func TestRemuxer_RemuxDirectory_Movies(t *testing.T) {
	// Skip if mkvmerge not available
	if _, err := exec.LookPath("mkvmerge"); err != nil {
		t.Skip("mkvmerge not installed, skipping integration test")
	}

	// Skip if ffmpeg not available
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed, skipping integration test")
	}

	tmpDir := t.TempDir()
	inputDir := filepath.Join(tmpDir, "input")
	outputDir := filepath.Join(tmpDir, "output")

	// Create _main directory with MKV file
	mainDir := filepath.Join(inputDir, "_main")
	if err := os.MkdirAll(mainDir, 0755); err != nil {
		t.Fatalf("Failed to create _main dir: %v", err)
	}

	inputMKV := filepath.Join(mainDir, "movie.mkv")
	if err := generateSimpleTestMKV(inputMKV); err != nil {
		t.Skipf("Could not generate test MKV: %v", err)
	}

	// Create _extras directory with a dummy file
	extrasDir := filepath.Join(inputDir, "_extras")
	if err := os.MkdirAll(extrasDir, 0755); err != nil {
		t.Fatalf("Failed to create _extras dir: %v", err)
	}
	extraFile := filepath.Join(extrasDir, "extra.txt")
	if err := os.WriteFile(extraFile, []byte("test extra"), 0644); err != nil {
		t.Fatalf("Failed to write extra file: %v", err)
	}

	remuxer := NewRemuxer([]string{"eng"})

	results, err := remuxer.RemuxDirectory(context.Background(), inputDir, outputDir, false)
	if err != nil {
		t.Fatalf("RemuxDirectory() error = %v", err)
	}

	// Should have processed 1 file
	if len(results) != 1 {
		t.Fatalf("Expected 1 result, got %d", len(results))
	}

	// Verify output MKV exists
	outputMKV := filepath.Join(outputDir, "_main", "movie.mkv")
	if _, err := os.Stat(outputMKV); err != nil {
		t.Errorf("Output MKV not created: %v", err)
	}

	// Verify extras were copied
	copiedExtra := filepath.Join(outputDir, "_extras", "extra.txt")
	if _, err := os.Stat(copiedExtra); err != nil {
		t.Errorf("Extra file not copied: %v", err)
	}
}

func TestRemuxer_RemuxDirectory_TV(t *testing.T) {
	// Skip if mkvmerge not available
	if _, err := exec.LookPath("mkvmerge"); err != nil {
		t.Skip("mkvmerge not installed, skipping integration test")
	}

	// Skip if ffmpeg not available
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not installed, skipping integration test")
	}

	tmpDir := t.TempDir()
	inputDir := filepath.Join(tmpDir, "input")
	outputDir := filepath.Join(tmpDir, "output")

	// Create _episodes directory with multiple MKV files
	episodesDir := filepath.Join(inputDir, "_episodes")
	if err := os.MkdirAll(episodesDir, 0755); err != nil {
		t.Fatalf("Failed to create _episodes dir: %v", err)
	}

	// Create two episode files
	ep1 := filepath.Join(episodesDir, "episode_01.mkv")
	ep2 := filepath.Join(episodesDir, "episode_02.mkv")

	if err := generateSimpleTestMKV(ep1); err != nil {
		t.Skipf("Could not generate test MKV: %v", err)
	}
	if err := generateSimpleTestMKV(ep2); err != nil {
		t.Skipf("Could not generate test MKV: %v", err)
	}

	remuxer := NewRemuxer([]string{"eng"})

	results, err := remuxer.RemuxDirectory(context.Background(), inputDir, outputDir, true)
	if err != nil {
		t.Fatalf("RemuxDirectory() error = %v", err)
	}

	// Should have processed 2 files
	if len(results) != 2 {
		t.Fatalf("Expected 2 results, got %d", len(results))
	}

	// Verify output episodes exist
	outputEp1 := filepath.Join(outputDir, "_episodes", "episode_01.mkv")
	outputEp2 := filepath.Join(outputDir, "_episodes", "episode_02.mkv")

	if _, err := os.Stat(outputEp1); err != nil {
		t.Errorf("Output episode 1 not created: %v", err)
	}
	if _, err := os.Stat(outputEp2); err != nil {
		t.Errorf("Output episode 2 not created: %v", err)
	}
}

func TestCopyDirectory(t *testing.T) {
	tmpDir := t.TempDir()
	srcDir := filepath.Join(tmpDir, "src")
	dstDir := filepath.Join(tmpDir, "dst")

	// Create source directory structure
	if err := os.MkdirAll(filepath.Join(srcDir, "subdir"), 0755); err != nil {
		t.Fatalf("Failed to create src dir: %v", err)
	}

	// Create test files
	file1 := filepath.Join(srcDir, "file1.txt")
	file2 := filepath.Join(srcDir, "subdir", "file2.txt")

	if err := os.WriteFile(file1, []byte("content1"), 0644); err != nil {
		t.Fatalf("Failed to write file1: %v", err)
	}
	if err := os.WriteFile(file2, []byte("content2"), 0644); err != nil {
		t.Fatalf("Failed to write file2: %v", err)
	}

	// Copy directory
	if err := copyDirectory(srcDir, dstDir); err != nil {
		t.Fatalf("copyDirectory() error = %v", err)
	}

	// Verify files were copied
	dstFile1 := filepath.Join(dstDir, "file1.txt")
	dstFile2 := filepath.Join(dstDir, "subdir", "file2.txt")

	content1, err := os.ReadFile(dstFile1)
	if err != nil {
		t.Errorf("Failed to read copied file1: %v", err)
	} else if string(content1) != "content1" {
		t.Errorf("file1 content = %q, want %q", string(content1), "content1")
	}

	content2, err := os.ReadFile(dstFile2)
	if err != nil {
		t.Errorf("Failed to read copied file2: %v", err)
	} else if string(content2) != "content2" {
		t.Errorf("file2 content = %q, want %q", string(content2), "content2")
	}
}

func TestCopyFile(t *testing.T) {
	tmpDir := t.TempDir()
	srcFile := filepath.Join(tmpDir, "src.txt")
	dstFile := filepath.Join(tmpDir, "dst.txt")

	content := []byte("test content")
	if err := os.WriteFile(srcFile, content, 0644); err != nil {
		t.Fatalf("Failed to write src file: %v", err)
	}

	if err := copyFile(srcFile, dstFile); err != nil {
		t.Fatalf("copyFile() error = %v", err)
	}

	readContent, err := os.ReadFile(dstFile)
	if err != nil {
		t.Errorf("Failed to read dst file: %v", err)
	} else if string(readContent) != string(content) {
		t.Errorf("dst content = %q, want %q", string(readContent), string(content))
	}
}

// generateSimpleTestMKV creates a minimal test MKV file with video and audio tracks
func generateSimpleTestMKV(outputPath string) error {
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	// Create a very short (1 second) test video with eng and fra audio tracks
	args := []string{
		"-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=24",
		"-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo:d=1",
		"-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo:d=1",
		"-map", "0:v",
		"-map", "1:a",
		"-map", "2:a",
		"-c:v", "libx264", "-preset", "ultrafast",
		"-c:a", "aac",
		"-metadata:s:a:0", "language=eng",
		"-metadata:s:a:0", "title=English",
		"-metadata:s:a:1", "language=fra",
		"-metadata:s:a:1", "title=French",
		"-shortest", "-y", outputPath,
	}

	cmd := exec.Command("ffmpeg", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return err
	}
	_ = output // Ignore output for now
	return nil
}
