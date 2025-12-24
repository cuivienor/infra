package model

import "time"

// TranscodeFileStatus represents the status of a file being transcoded
type TranscodeFileStatus string

const (
	TranscodeFileStatusPending    TranscodeFileStatus = "pending"
	TranscodeFileStatusInProgress TranscodeFileStatus = "in_progress"
	TranscodeFileStatusCompleted  TranscodeFileStatus = "completed"
	TranscodeFileStatusFailed     TranscodeFileStatus = "failed"
	TranscodeFileStatusSkipped    TranscodeFileStatus = "skipped"
)

// TranscodeFile tracks the status of a single file within a transcode job
type TranscodeFile struct {
	ID           int64
	JobID        int64
	RelativePath string
	Status       TranscodeFileStatus
	InputSize    int64
	OutputSize   int64
	Progress     int // 0-100 percentage
	DurationSecs float64
	StartedAt    *time.Time
	CompletedAt  *time.Time
	ErrorMessage string
}

// SizeSaved returns bytes saved (input - output)
func (f *TranscodeFile) SizeSaved() int64 {
	return f.InputSize - f.OutputSize
}

// CompressionRatio returns the output/input ratio (lower is better compression)
func (f *TranscodeFile) CompressionRatio() float64 {
	if f.InputSize == 0 {
		return 0
	}
	return float64(f.OutputSize) / float64(f.InputSize)
}
