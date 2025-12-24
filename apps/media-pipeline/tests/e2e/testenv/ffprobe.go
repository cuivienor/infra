package testenv

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"testing"
)

// FFProbeResult holds parsed ffprobe output
type FFProbeResult struct {
	Streams []FFProbeStream `json:"streams"`
	Format  FFProbeFormat   `json:"format"`
}

// FFProbeStream represents a single stream in the media file
type FFProbeStream struct {
	Index          int    `json:"index"`
	CodecType      string `json:"codec_type"` // "video", "audio", "subtitle"
	CodecName      string `json:"codec_name"`
	CodecLongName  string `json:"codec_long_name"`
	Width          int    `json:"width,omitempty"`
	Height         int    `json:"height,omitempty"`
	Duration       string `json:"duration,omitempty"`
	BitRate        string `json:"bit_rate,omitempty"`
	SampleRate     string `json:"sample_rate,omitempty"`
	Channels       int    `json:"channels,omitempty"`
	ChannelLayout  string `json:"channel_layout,omitempty"`
}

// FFProbeFormat holds container format information
type FFProbeFormat struct {
	Filename       string `json:"filename"`
	FormatName     string `json:"format_name"`
	FormatLongName string `json:"format_long_name"`
	Duration       string `json:"duration"`
	Size           string `json:"size"`
	BitRate        string `json:"bit_rate"`
}

// ProbeFile runs ffprobe on a file and returns parsed results
func ProbeFile(path string) (*FFProbeResult, error) {
	cmd := exec.Command("ffprobe",
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		path)

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("ffprobe failed for %s: %w", path, err)
	}

	var result FFProbeResult
	if err := json.Unmarshal(output, &result); err != nil {
		return nil, fmt.Errorf("failed to parse ffprobe output: %w", err)
	}

	return &result, nil
}

// HasVideoStream returns true if the file has at least one video stream
func (r *FFProbeResult) HasVideoStream() bool {
	for _, s := range r.Streams {
		if s.CodecType == "video" {
			return true
		}
	}
	return false
}

// HasAudioStream returns true if the file has at least one audio stream
func (r *FFProbeResult) HasAudioStream() bool {
	for _, s := range r.Streams {
		if s.CodecType == "audio" {
			return true
		}
	}
	return false
}

// HasSubtitleStream returns true if the file has at least one subtitle stream
func (r *FFProbeResult) HasSubtitleStream() bool {
	for _, s := range r.Streams {
		if s.CodecType == "subtitle" {
			return true
		}
	}
	return false
}

// StreamCount returns the total number of streams
func (r *FFProbeResult) StreamCount() int {
	return len(r.Streams)
}

// VideoStreamCount returns the number of video streams
func (r *FFProbeResult) VideoStreamCount() int {
	count := 0
	for _, s := range r.Streams {
		if s.CodecType == "video" {
			count++
		}
	}
	return count
}

// AudioStreamCount returns the number of audio streams
func (r *FFProbeResult) AudioStreamCount() int {
	count := 0
	for _, s := range r.Streams {
		if s.CodecType == "audio" {
			count++
		}
	}
	return count
}

// SubtitleStreamCount returns the number of subtitle streams
func (r *FFProbeResult) SubtitleStreamCount() int {
	count := 0
	for _, s := range r.Streams {
		if s.CodecType == "subtitle" {
			count++
		}
	}
	return count
}

// GetVideoStreams returns all video streams
func (r *FFProbeResult) GetVideoStreams() []FFProbeStream {
	var streams []FFProbeStream
	for _, s := range r.Streams {
		if s.CodecType == "video" {
			streams = append(streams, s)
		}
	}
	return streams
}

// GetAudioStreams returns all audio streams
func (r *FFProbeResult) GetAudioStreams() []FFProbeStream {
	var streams []FFProbeStream
	for _, s := range r.Streams {
		if s.CodecType == "audio" {
			streams = append(streams, s)
		}
	}
	return streams
}

// --- Test assertion helpers ---

// AssertValidMKV verifies the file is a valid MKV container
func AssertValidMKV(t *testing.T, path string) {
	t.Helper()
	result, err := ProbeFile(path)
	if err != nil {
		t.Fatalf("file %s is not a valid media file: %v", path, err)
	}
	if result.Format.Filename == "" {
		t.Errorf("file %s has no format info", path)
	}
}

// AssertHasVideoStream verifies the file has at least one video stream
func AssertHasVideoStream(t *testing.T, path string) {
	t.Helper()
	result, err := ProbeFile(path)
	if err != nil {
		t.Fatalf("failed to probe %s: %v", path, err)
	}
	if !result.HasVideoStream() {
		t.Errorf("file %s has no video stream", path)
	}
}

// AssertHasAudioStream verifies the file has at least one audio stream
func AssertHasAudioStream(t *testing.T, path string) {
	t.Helper()
	result, err := ProbeFile(path)
	if err != nil {
		t.Fatalf("failed to probe %s: %v", path, err)
	}
	if !result.HasAudioStream() {
		t.Errorf("file %s has no audio stream", path)
	}
}

// AssertStreamCounts verifies the file has expected stream counts
func AssertStreamCounts(t *testing.T, path string, video, audio, subtitle int) {
	t.Helper()
	result, err := ProbeFile(path)
	if err != nil {
		t.Fatalf("failed to probe %s: %v", path, err)
	}

	if got := result.VideoStreamCount(); got != video {
		t.Errorf("file %s has %d video streams, want %d", path, got, video)
	}
	if got := result.AudioStreamCount(); got != audio {
		t.Errorf("file %s has %d audio streams, want %d", path, got, audio)
	}
	if got := result.SubtitleStreamCount(); got != subtitle {
		t.Errorf("file %s has %d subtitle streams, want %d", path, got, subtitle)
	}
}
