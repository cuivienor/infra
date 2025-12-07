package logging

import (
	"fmt"
	"io"
	"os"
	"sync"
	"time"
)

// Level represents the severity of a log message
type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelProgress
	LevelWarn
	LevelError
)

func (l Level) String() string {
	switch l {
	case LevelDebug:
		return "DEBUG"
	case LevelInfo:
		return "INFO"
	case LevelProgress:
		return "PROGRESS"
	case LevelWarn:
		return "WARN"
	case LevelError:
		return "ERROR"
	default:
		return "UNKNOWN"
	}
}

// Logger provides multi-destination logging with level filtering
type Logger struct {
	mu       sync.Mutex
	stdout   io.Writer
	file     io.Writer
	minLevel Level

	// For DB event logging
	eventFn func(level, msg string)
}

// Options configures a Logger instance
type Options struct {
	Stdout   io.Writer                  // nil = no stdout
	File     io.Writer                  // nil = no file
	MinLevel Level                      // Minimum level to log
	EventFn  func(level, msg string)   // Called for significant events
}

// New creates a new Logger with the given options
func New(opts Options) *Logger {
	return &Logger{
		stdout:   opts.Stdout,
		file:     opts.File,
		minLevel: opts.MinLevel,
		eventFn:  opts.EventFn,
	}
}

// NewForJob creates a logger configured for a job execution
func NewForJob(logPath string, stdout bool, eventFn func(level, msg string)) (*Logger, error) {
	var stdoutWriter io.Writer
	if stdout {
		stdoutWriter = os.Stdout
	}

	var fileWriter io.Writer
	if logPath != "" {
		f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return nil, fmt.Errorf("failed to open log file: %w", err)
		}
		fileWriter = f
	}

	return New(Options{
		Stdout:   stdoutWriter,
		File:     fileWriter,
		MinLevel: LevelInfo,
		EventFn:  eventFn,
	}), nil
}

// log is the internal logging method
func (l *Logger) log(level Level, msg string, args ...any) {
	if level < l.minLevel {
		return
	}

	formatted := fmt.Sprintf(msg, args...)
	line := fmt.Sprintf("%s [%s] %s\n",
		time.Now().Format("2006-01-02 15:04:05"),
		level.String(),
		formatted,
	)

	l.mu.Lock()
	defer l.mu.Unlock()

	if l.stdout != nil {
		l.stdout.Write([]byte(line))
	}
	if l.file != nil {
		l.file.Write([]byte(line))
	}
}

// Debug logs a debug message
func (l *Logger) Debug(msg string, args ...any) {
	l.log(LevelDebug, msg, args...)
}

// Info logs an info message
func (l *Logger) Info(msg string, args ...any) {
	l.log(LevelInfo, msg, args...)
}

// Progress logs a progress message
func (l *Logger) Progress(msg string, args ...any) {
	l.log(LevelProgress, msg, args...)
}

// Warn logs a warning message
func (l *Logger) Warn(msg string, args ...any) {
	l.log(LevelWarn, msg, args...)
}

// Error logs an error message
func (l *Logger) Error(msg string, args ...any) {
	l.log(LevelError, msg, args...)
}

// Event logs a significant event to file AND DB (if configured)
func (l *Logger) Event(level Level, msg string) {
	// Format the message directly since Event doesn't take variadic args
	line := fmt.Sprintf("%s [%s] %s\n",
		time.Now().Format("2006-01-02 15:04:05"),
		level.String(),
		msg,
	)

	l.mu.Lock()
	if l.stdout != nil {
		l.stdout.Write([]byte(line))
	}
	if l.file != nil {
		l.file.Write([]byte(line))
	}
	l.mu.Unlock()

	if l.eventFn != nil {
		l.eventFn(level.String(), msg)
	}
}
