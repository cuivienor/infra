package transcode

import (
	"testing"
)

func TestParseProgress(t *testing.T) {
	tests := []struct {
		name     string
		line     string
		duration float64
		want     int
	}{
		{
			name:     "beginning",
			line:     "frame=  120 fps=24 q=28.0 size=    1024kB time=00:00:05.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 100.0,
			want:     5,
		},
		{
			name:     "middle",
			line:     "frame= 1200 fps=24 q=28.0 size=   10240kB time=00:00:50.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 100.0,
			want:     50,
		},
		{
			name:     "near end",
			line:     "frame= 2400 fps=24 q=28.0 size=   20480kB time=00:01:35.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 100.0,
			want:     95,
		},
		{
			name:     "long video",
			line:     "frame=86400 fps=24 q=28.0 size=  204800kB time=01:00:00.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 7200.0, // 2 hours
			want:     50,
		},
		{
			name:     "no time field",
			line:     "frame=  120 fps=24 q=28.0 size=    1024kB",
			duration: 100.0,
			want:     0,
		},
		{
			name:     "zero duration",
			line:     "frame=  120 fps=24 q=28.0 size=    1024kB time=00:00:05.00 bitrate=1677.7kbits/s speed=1.0x",
			duration: 0,
			want:     0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseProgress(tt.line, tt.duration)
			if got != tt.want {
				t.Errorf("parseProgress() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestBuildFFmpegArgs_Software(t *testing.T) {
	opts := TranscodeOptions{
		CRF:    20,
		Mode:   "software",
		Preset: "slow",
	}

	args := buildFFmpegArgs("/input/movie.mkv", "/output/movie.mkv", opts)

	// Check key args are present
	contains := func(args []string, want string) bool {
		for _, a := range args {
			if a == want {
				return true
			}
		}
		return false
	}

	if !contains(args, "libx265") {
		t.Error("expected libx265 codec")
	}
	if !contains(args, "-crf") {
		t.Error("expected -crf flag")
	}
	if !contains(args, "slow") {
		t.Error("expected slow preset")
	}
}

func TestBuildFFmpegArgs_Hardware(t *testing.T) {
	opts := TranscodeOptions{
		CRF:      20,
		Mode:     "hardware",
		HWPreset: "medium",
	}

	args := buildFFmpegArgs("/input/movie.mkv", "/output/movie.mkv", opts)

	contains := func(args []string, want string) bool {
		for _, a := range args {
			if a == want {
				return true
			}
		}
		return false
	}

	if !contains(args, "hevc_qsv") {
		t.Error("expected hevc_qsv codec")
	}
	if !contains(args, "-global_quality") {
		t.Error("expected -global_quality flag")
	}
	if !contains(args, "qsv") {
		t.Error("expected qsv hwaccel")
	}
}
