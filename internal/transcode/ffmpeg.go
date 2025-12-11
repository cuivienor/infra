package transcode

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// TranscodeOptions configures the transcoding operation
type TranscodeOptions struct {
	CRF         int
	Mode        string // "software" or "hardware"
	Preset      string // libx265 preset
	HWPreset    string // QSV preset
	DurationSec float64
}

// ProgressCallback is called with progress updates (0-100)
type ProgressCallback func(percent int)

// timeRegex matches ffmpeg's time= output
var timeRegex = regexp.MustCompile(`time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})`)

// TranscodeFile transcodes a single file using ffmpeg
func TranscodeFile(ctx context.Context, inputPath, outputPath string, opts TranscodeOptions, onProgress ProgressCallback) error {
	// Ensure output directory exists
	if err := os.MkdirAll(outputPath[:len(outputPath)-len("/"+inputPath[strings.LastIndex(inputPath, "/")+1:])], 0755); err != nil {
		// Ignore - will fail on ffmpeg if dir doesn't exist
	}

	args := buildFFmpegArgs(inputPath, outputPath, opts)

	cmd := exec.CommandContext(ctx, "ffmpeg", args...)

	// ffmpeg writes progress to stderr
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to get stderr pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start ffmpeg: %w", err)
	}

	// Parse progress from stderr
	lastPercent := 0
	scanner := bufio.NewScanner(stderr)
	scanner.Split(scanFFmpegLines)

	for scanner.Scan() {
		line := scanner.Text()
		if percent := parseProgress(line, opts.DurationSec); percent > lastPercent {
			lastPercent = percent
			if onProgress != nil {
				onProgress(percent)
			}
		}
	}

	if err := cmd.Wait(); err != nil {
		// Clean up partial output
		os.Remove(outputPath)
		if exitErr, ok := err.(*exec.ExitError); ok {
			return fmt.Errorf("ffmpeg failed with exit code %d", exitErr.ExitCode())
		}
		return fmt.Errorf("ffmpeg failed: %w", err)
	}

	// Final progress update
	if onProgress != nil && lastPercent < 100 {
		onProgress(100)
	}

	return nil
}

// buildFFmpegArgs constructs the ffmpeg command arguments
func buildFFmpegArgs(inputPath, outputPath string, opts TranscodeOptions) []string {
	var args []string

	// Common input args
	args = append(args, "-nostdin", "-y")

	if opts.Mode == "hardware" {
		// Intel QSV hardware encoding
		args = append(args,
			"-hwaccel", "qsv",
			"-hwaccel_output_format", "qsv",
			"-i", inputPath,
			"-c:v", "hevc_qsv",
			"-preset", opts.HWPreset,
			"-global_quality", strconv.Itoa(opts.CRF),
		)
	} else {
		// Software encoding (libx265)
		args = append(args,
			"-i", inputPath,
			"-map", "0:v:0",
			"-map", "0:a",
			"-map", "0:s?",
			"-c:v", "libx265",
			"-preset", opts.Preset,
			"-crf", strconv.Itoa(opts.CRF),
		)
	}

	// Common output args: copy audio and subtitles
	args = append(args,
		"-c:a", "copy",
		"-c:s", "copy",
		outputPath,
	)

	return args
}

// parseProgress extracts progress percentage from ffmpeg output
func parseProgress(line string, totalDuration float64) int {
	if totalDuration <= 0 {
		return 0
	}

	matches := timeRegex.FindStringSubmatch(line)
	if matches == nil {
		return 0
	}

	hours, _ := strconv.Atoi(matches[1])
	minutes, _ := strconv.Atoi(matches[2])
	seconds, _ := strconv.Atoi(matches[3])
	centisecs, _ := strconv.Atoi(matches[4])

	currentSecs := float64(hours*3600+minutes*60+seconds) + float64(centisecs)/100.0
	percent := int((currentSecs / totalDuration) * 100)

	if percent > 100 {
		percent = 100
	}

	return percent
}

// scanFFmpegLines is a split function for bufio.Scanner that handles ffmpeg's CR-delimited progress output
func scanFFmpegLines(data []byte, atEOF bool) (advance int, token []byte, err error) {
	if atEOF && len(data) == 0 {
		return 0, nil, nil
	}

	// Look for CR (carriage return) which ffmpeg uses for progress updates
	if i := strings.IndexAny(string(data), "\r\n"); i >= 0 {
		return i + 1, data[0:i], nil
	}

	if atEOF {
		return len(data), data, nil
	}

	return 0, nil, nil
}
