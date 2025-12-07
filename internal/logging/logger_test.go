package logging

import (
	"bytes"
	"strings"
	"testing"
)

func TestLogger_WritesToMultipleDestinations(t *testing.T) {
	var stdout, file bytes.Buffer

	logger := New(Options{
		Stdout:   &stdout,
		File:     &file,
		MinLevel: LevelInfo,
	})

	logger.Info("test message")

	if !strings.Contains(stdout.String(), "test message") {
		t.Error("stdout missing message")
	}
	if !strings.Contains(file.String(), "test message") {
		t.Error("file missing message")
	}
}

func TestLogger_RespectsMinLevel(t *testing.T) {
	var buf bytes.Buffer

	logger := New(Options{
		Stdout:   &buf,
		MinLevel: LevelWarn,
	})

	logger.Debug("debug msg")
	logger.Info("info msg")
	logger.Warn("warn msg")

	output := buf.String()
	if strings.Contains(output, "debug msg") {
		t.Error("debug should be filtered")
	}
	if strings.Contains(output, "info msg") {
		t.Error("info should be filtered")
	}
	if !strings.Contains(output, "warn msg") {
		t.Error("warn should be included")
	}
}

func TestLogger_ProgressLevel(t *testing.T) {
	var buf bytes.Buffer

	logger := New(Options{
		Stdout:   &buf,
		MinLevel: LevelProgress,
	})

	logger.Progress("50%% complete")

	if !strings.Contains(buf.String(), "[PROGRESS]") {
		t.Error("progress level not formatted correctly")
	}
}

func TestLogger_Format(t *testing.T) {
	var buf bytes.Buffer

	logger := New(Options{
		Stdout:   &buf,
		MinLevel: LevelInfo,
	})

	logger.Info("test message with arg: %s", "value")

	output := buf.String()
	if !strings.Contains(output, "[INFO]") {
		t.Error("missing INFO level tag")
	}
	if !strings.Contains(output, "test message with arg: value") {
		t.Error("missing formatted message")
	}
	// Check timestamp format (YYYY-MM-DD HH:MM:SS)
	if !strings.Contains(output, "-") || !strings.Contains(output, ":") {
		t.Error("missing timestamp")
	}
}

func TestLogger_AllLevels(t *testing.T) {
	tests := []struct {
		name     string
		logFn    func(*Logger)
		wantTag  string
		minLevel Level
		want     bool
	}{
		{
			name:     "debug at debug level",
			logFn:    func(l *Logger) { l.Debug("test") },
			wantTag:  "[DEBUG]",
			minLevel: LevelDebug,
			want:     true,
		},
		{
			name:     "debug filtered at info level",
			logFn:    func(l *Logger) { l.Debug("test") },
			wantTag:  "[DEBUG]",
			minLevel: LevelInfo,
			want:     false,
		},
		{
			name:     "info at info level",
			logFn:    func(l *Logger) { l.Info("test") },
			wantTag:  "[INFO]",
			minLevel: LevelInfo,
			want:     true,
		},
		{
			name:     "progress at progress level",
			logFn:    func(l *Logger) { l.Progress("test") },
			wantTag:  "[PROGRESS]",
			minLevel: LevelProgress,
			want:     true,
		},
		{
			name:     "warn at warn level",
			logFn:    func(l *Logger) { l.Warn("test") },
			wantTag:  "[WARN]",
			minLevel: LevelWarn,
			want:     true,
		},
		{
			name:     "error at error level",
			logFn:    func(l *Logger) { l.Error("test") },
			wantTag:  "[ERROR]",
			minLevel: LevelError,
			want:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var buf bytes.Buffer
			logger := New(Options{
				Stdout:   &buf,
				MinLevel: tt.minLevel,
			})

			tt.logFn(logger)

			output := buf.String()
			hasTag := strings.Contains(output, tt.wantTag)
			if hasTag != tt.want {
				t.Errorf("got tag=%v, want %v; output: %q", hasTag, tt.want, output)
			}
		})
	}
}

func TestLogger_EventCallsCallback(t *testing.T) {
	var buf bytes.Buffer
	var eventCalls []string

	logger := New(Options{
		Stdout:   &buf,
		MinLevel: LevelInfo,
		EventFn: func(level, msg string) {
			eventCalls = append(eventCalls, level+":"+msg)
		},
	})

	logger.Event(LevelInfo, "important event")

	// Should appear in normal log
	if !strings.Contains(buf.String(), "important event") {
		t.Error("event not logged to file")
	}
	if !strings.Contains(buf.String(), "[INFO]") {
		t.Error("event missing INFO tag")
	}

	// Should call eventFn
	if len(eventCalls) != 1 {
		t.Fatalf("expected 1 event call, got %d", len(eventCalls))
	}
	if eventCalls[0] != "INFO:important event" {
		t.Errorf("eventFn got %q, want %q", eventCalls[0], "INFO:important event")
	}
}

func TestLogger_EventWithoutCallback(t *testing.T) {
	var buf bytes.Buffer

	logger := New(Options{
		Stdout:   &buf,
		MinLevel: LevelInfo,
		// No EventFn
	})

	// Should not panic when EventFn is nil
	logger.Event(LevelInfo, "event without callback")

	if !strings.Contains(buf.String(), "event without callback") {
		t.Error("event not logged")
	}
}

func TestLogger_NilWriters(t *testing.T) {
	// Should not panic with nil writers
	logger := New(Options{
		Stdout:   nil,
		File:     nil,
		MinLevel: LevelInfo,
	})

	logger.Info("test message")
	// If we get here without panic, test passes
}

func TestLogger_FileOnly(t *testing.T) {
	var file bytes.Buffer

	logger := New(Options{
		File:     &file,
		MinLevel: LevelInfo,
	})

	logger.Info("test message")

	if !strings.Contains(file.String(), "test message") {
		t.Error("file missing message")
	}
}
