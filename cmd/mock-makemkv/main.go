package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

// Options holds parsed command-line options
type Options struct {
	ProfileName string        // Disc profile to use
	DiscPath    string        // Disc path (e.g., "disc:0")
	Titles      string        // Titles to rip ("all" or comma-separated indices)
	OutputDir   string        // Output directory for mkv command
	Delay       time.Duration // Delay between progress updates
	SkipFFmpeg  bool          // Skip actual ffmpeg generation (for testing)
}

func main() {
	cmd, opts, err := ParseArgs(os.Args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		usage()
		os.Exit(1)
	}

	switch cmd {
	case "info":
		if err := RunInfo(os.Stdout, opts); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	case "mkv":
		if err := RunMkv(os.Stdout, opts); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	}
}

// ParseArgs parses command-line arguments
// Returns command name, options, and any error
func ParseArgs(args []string) (string, *Options, error) {
	if len(args) < 2 {
		return "", nil, errors.New("missing command")
	}

	opts := &Options{
		ProfileName: "big_buck_bunny", // default profile
	}

	// Parse flags first
	i := 1
	for i < len(args) {
		switch args[i] {
		case "--profile":
			if i+1 >= len(args) {
				return "", nil, errors.New("--profile requires a value")
			}
			opts.ProfileName = args[i+1]
			i += 2
		case "--delay":
			if i+1 >= len(args) {
				return "", nil, errors.New("--delay requires a value")
			}
			d, err := time.ParseDuration(args[i+1])
			if err != nil {
				return "", nil, fmt.Errorf("invalid delay: %w", err)
			}
			opts.Delay = d
			i += 2
		case "--skip-ffmpeg":
			opts.SkipFFmpeg = true
			i++
		// Accept makemkvcon flags (ignored for compatibility)
		case "-r", "--robot", "--noscan", "--minlength", "--messages", "--progress", "--debug", "--directio":
			i++
		default:
			// Not a flag, must be command
			goto parseCommand
		}
	}

parseCommand:
	if i >= len(args) {
		return "", nil, errors.New("missing command")
	}

	cmd := args[i]
	i++

	switch cmd {
	case "info":
		if i >= len(args) {
			return "", nil, errors.New("info requires disc path")
		}
		opts.DiscPath = args[i]
		return "info", opts, nil

	case "mkv":
		if i+2 >= len(args) {
			return "", nil, errors.New("mkv requires: disc titles output_dir")
		}
		opts.DiscPath = args[i]
		opts.Titles = args[i+1]
		opts.OutputDir = args[i+2]
		return "mkv", opts, nil

	default:
		return "", nil, fmt.Errorf("unknown command: %s", cmd)
	}
}

// RunInfo executes the info command
func RunInfo(w io.Writer, opts *Options) error {
	profile := GetProfile(opts.ProfileName)
	out := NewOutputWriter(w)
	out.WriteDiscInfo(profile)
	return nil
}

// RunMkv executes the mkv command
func RunMkv(w io.Writer, opts *Options) error {
	profile := GetProfile(opts.ProfileName)
	out := NewOutputWriter(w)

	// Create output directory
	if err := os.MkdirAll(opts.OutputDir, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Write initial disc info
	out.WriteDiscInfo(profile)

	// Check for simulated failure
	if profile.SimulateFailure {
		return simulateFailure(w, out, profile, opts)
	}

	// Rip each title
	for i, title := range profile.Titles {
		outputPath := filepath.Join(opts.OutputDir, title.Filename)

		// Write progress: starting title
		out.WriteMSG(5021, fmt.Sprintf("Saving %d titles", len(profile.Titles)))
		out.WritePRGT(5022, fmt.Sprintf("Saving title %d of %d", i+1, len(profile.Titles)))

		// Generate actual MKV file if not skipped
		if !opts.SkipFFmpeg {
			if err := GenerateSyntheticMKV(outputPath, title.Duration); err != nil {
				return fmt.Errorf("failed to generate %s: %w", title.Filename, err)
			}
		} else {
			// Create empty file for testing
			if err := os.WriteFile(outputPath, []byte{}, 0644); err != nil {
				return fmt.Errorf("failed to create %s: %w", title.Filename, err)
			}
		}

		// Write progress updates
		steps := 10
		for step := 0; step <= steps; step++ {
			progress := float64(step) / float64(steps)
			current := int(progress * 65536)
			out.WritePRGV(current, 0, 65536)

			if opts.Delay > 0 {
				time.Sleep(opts.Delay / time.Duration(steps))
			}
		}
	}

	// Write completion message
	out.WriteMSG(5010, fmt.Sprintf("Copy complete. %d titles saved.", len(profile.Titles)))

	return nil
}

// simulateFailure simulates a disc read failure
func simulateFailure(w io.Writer, out *OutputWriter, profile *DiscProfile, opts *Options) error {
	// Progress up to failure point
	failAt := float64(profile.FailAtPercent) / 100.0
	steps := 20
	failStep := int(float64(steps) * failAt)

	for step := 0; step <= failStep; step++ {
		progress := float64(step) / float64(steps)
		current := int(progress * 65536)
		out.WritePRGV(current, 0, 65536)

		if opts.Delay > 0 {
			time.Sleep(opts.Delay / time.Duration(steps))
		}
	}

	// Write error message
	out.WriteMSG(5055, "Copy failed")
	out.WriteMSG(2011, fmt.Sprintf("Read error at %d%%", profile.FailAtPercent))

	return fmt.Errorf("simulated read error at %d%%", profile.FailAtPercent)
}

func usage() {
	fmt.Println(`Usage: mock-makemkv [options] <command> [args]

Commands:
  info <disc>                    Show disc information
  mkv <disc> <titles> <output>   Rip titles to output directory

Options:
  --profile <name>    Use a specific disc profile (default: big_buck_bunny)
                      Available: big_buck_bunny, simpsons_s01d01, problem_disc
  --delay <duration>  Add delay between progress updates (e.g., 100ms)
  --skip-ffmpeg       Skip actual file generation (for testing)

Examples:
  mock-makemkv info disc:0
  mock-makemkv mkv disc:0 all /output/dir
  mock-makemkv --profile simpsons_s01d01 info disc:0
  mock-makemkv --delay 50ms mkv disc:0 all /output/dir`)
}
