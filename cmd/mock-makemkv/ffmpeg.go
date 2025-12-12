package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// TrackConfig defines the audio and subtitle tracks to generate
type TrackConfig struct {
	AudioTracks    []AudioTrack
	SubtitleTracks []SubtitleTrack
}

// AudioTrack defines an audio track with language metadata
type AudioTrack struct {
	Language string // ISO 639-2 code (eng, bul, fra, spa)
	Title    string // Track title (e.g., "English", "Bulgarian")
	Channels string // Channel layout (stereo, 5.1)
}

// SubtitleTrack defines a subtitle track with language metadata
type SubtitleTrack struct {
	Language string // ISO 639-2 code
	Title    string // Track title
	Forced   bool   // Whether this is a forced subtitle track
}

// DefaultTrackConfig returns a track configuration suitable for testing remux
// Includes multiple languages so we can verify filtering works
func DefaultTrackConfig() TrackConfig {
	return TrackConfig{
		AudioTracks: []AudioTrack{
			{Language: "eng", Title: "English", Channels: "stereo"},
			{Language: "bul", Title: "Bulgarian", Channels: "stereo"},
			{Language: "fra", Title: "French", Channels: "stereo"},
			{Language: "spa", Title: "Spanish", Channels: "stereo"},
		},
		SubtitleTracks: []SubtitleTrack{
			{Language: "eng", Title: "English", Forced: false},
			{Language: "eng", Title: "English (Forced)", Forced: true},
			{Language: "bul", Title: "Bulgarian", Forced: false},
			{Language: "spa", Title: "Spanish", Forced: false},
		},
	}
}

// GenerateSyntheticMKV creates an MKV file using ffmpeg with the specified duration.
// The file contains multiple audio and subtitle tracks for testing remux filtering.
// - Video: test pattern (testsrc)
// - Audio: English, Bulgarian, French, Spanish (silent tracks with language metadata)
// - Subtitles: English, English (Forced), Bulgarian, Spanish
func GenerateSyntheticMKV(outputPath string, duration time.Duration) error {
	return GenerateSyntheticMKVWithTracks(outputPath, duration, DefaultTrackConfig())
}

// GenerateSyntheticMKVWithTracks creates an MKV file with configurable tracks
func GenerateSyntheticMKVWithTracks(outputPath string, duration time.Duration, tracks TrackConfig) error {
	// Create parent directory if needed
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	durationSec := int(duration.Seconds())
	if durationSec < 1 {
		durationSec = 1
	}

	// Build ffmpeg command with multiple tracks
	args := []string{
		// Video input
		"-f", "lavfi",
		"-i", fmt.Sprintf("testsrc=duration=%d:size=1280x720:rate=24", durationSec),
	}

	// Add audio inputs (one per track)
	for range tracks.AudioTracks {
		args = append(args,
			"-f", "lavfi",
			"-i", fmt.Sprintf("anullsrc=r=48000:cl=stereo:d=%d", durationSec),
		)
	}

	// Add subtitle inputs (generate simple SRT content for each)
	// We use the sine filter to create a dummy input, then generate subtitles
	subtitleFiles := []string{}
	for i, sub := range tracks.SubtitleTracks {
		srtPath := filepath.Join(dir, fmt.Sprintf(".temp_sub_%d.srt", i))
		subtitleFiles = append(subtitleFiles, srtPath)
		if err := generateSRT(srtPath, durationSec, sub.Title, sub.Forced); err != nil {
			return fmt.Errorf("failed to generate subtitle file: %w", err)
		}
		args = append(args, "-i", srtPath)
	}

	// Map all inputs
	args = append(args, "-map", "0:v") // Video from first input

	// Map audio tracks
	for i := range tracks.AudioTracks {
		args = append(args, "-map", fmt.Sprintf("%d:a", i+1))
	}

	// Map subtitle tracks (each subtitle file is its own input, starting after audio inputs)
	for i := range tracks.SubtitleTracks {
		args = append(args, "-map", fmt.Sprintf("%d", i+1+len(tracks.AudioTracks)))
	}

	// Video codec - use yuv420p like real Blu-rays (required for QSV hardware decode)
	args = append(args, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p")

	// Audio codec and metadata
	args = append(args, "-c:a", "aac")
	for i, audio := range tracks.AudioTracks {
		args = append(args,
			fmt.Sprintf("-metadata:s:a:%d", i), fmt.Sprintf("language=%s", audio.Language),
			fmt.Sprintf("-metadata:s:a:%d", i), fmt.Sprintf("title=%s", audio.Title),
		)
	}

	// Subtitle codec and metadata
	args = append(args, "-c:s", "srt")
	for i, sub := range tracks.SubtitleTracks {
		args = append(args,
			fmt.Sprintf("-metadata:s:s:%d", i), fmt.Sprintf("language=%s", sub.Language),
			fmt.Sprintf("-metadata:s:s:%d", i), fmt.Sprintf("title=%s", sub.Title),
		)
		if sub.Forced {
			args = append(args,
				fmt.Sprintf("-disposition:s:%d", i), "forced",
			)
		}
	}

	args = append(args,
		"-shortest",
		"-y", // Overwrite output file if it exists
		outputPath,
	)

	cmd := exec.Command("ffmpeg", args...)


	// Capture stderr for error messages (ffmpeg writes to stderr)
	output, err := cmd.CombinedOutput()

	// Clean up temp subtitle files
	for _, srtPath := range subtitleFiles {
		os.Remove(srtPath)
	}

	if err != nil {
		return fmt.Errorf("ffmpeg failed: %w\nOutput: %s", err, string(output))
	}

	return nil
}

// generateSRT creates a simple SRT subtitle file
func generateSRT(path string, durationSec int, title string, forced bool) error {
	var content string

	if forced {
		// For forced subtitles, show at beginning and end spanning full duration
		content = fmt.Sprintf(`1
00:00:00,000 --> 00:00:02,000
[Forced] %s

2
00:00:%02d,000 --> 00:00:%02d,000
[Forced] End of %s
`, title, durationSec-2, durationSec, title)
	} else {
		// For regular subtitles, show at beginning and end spanning full duration
		content = fmt.Sprintf(`1
00:00:00,000 --> 00:00:02,000
%s

2
00:00:%02d,000 --> 00:00:%02d,000
End of %s
`, title, durationSec-2, durationSec, title)
	}

	return os.WriteFile(path, []byte(content), 0644)
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
