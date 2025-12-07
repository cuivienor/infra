package organize

import (
	"os"
	"path/filepath"
	"testing"
)

func TestValidator_ValidateMovie(t *testing.T) {
	tests := []struct {
		name    string
		setup   func(dir string)
		wantOK  bool
		wantErr string
	}{
		{
			name: "valid: _main has files, root empty",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_main"), 0755)
				os.WriteFile(filepath.Join(dir, "_main", "movie.mkv"), []byte{}, 0644)
			},
			wantOK: true,
		},
		{
			name: "valid: _main and _extras with .rip state dir",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_main"), 0755)
				os.WriteFile(filepath.Join(dir, "_main", "movie.mkv"), []byte{}, 0644)
				os.MkdirAll(filepath.Join(dir, "_extras"), 0755)
				os.WriteFile(filepath.Join(dir, "_extras", "extra.mkv"), []byte{}, 0644)
				os.MkdirAll(filepath.Join(dir, ".rip"), 0755)
			},
			wantOK: true,
		},
		{
			name: "invalid: root has loose files",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_main"), 0755)
				os.WriteFile(filepath.Join(dir, "_main", "movie.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "title_t00.mkv"), []byte{}, 0644)
			},
			wantOK:  false,
			wantErr: "root directory not empty",
		},
		{
			name: "invalid: root has non-underscore directory",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_main"), 0755)
				os.WriteFile(filepath.Join(dir, "_main", "movie.mkv"), []byte{}, 0644)
				os.MkdirAll(filepath.Join(dir, "extras"), 0755)
			},
			wantOK:  false,
			wantErr: "root directory not empty",
		},
		{
			name: "invalid: _main missing",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_extras"), 0755)
			},
			wantOK:  false,
			wantErr: "_main directory not found",
		},
		{
			name: "invalid: _main has no mkv files",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_main"), 0755)
				os.WriteFile(filepath.Join(dir, "_main", "readme.txt"), []byte{}, 0644)
			},
			wantOK:  false,
			wantErr: "_main has no .mkv files",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			tt.setup(dir)

			v := &Validator{}
			result := v.ValidateMovie(dir)

			if result.Valid != tt.wantOK {
				t.Errorf("Valid = %v, want %v", result.Valid, tt.wantOK)
			}
			if !tt.wantOK {
				if len(result.Errors) == 0 {
					t.Error("expected errors but got none")
				}
				if tt.wantErr != "" {
					found := false
					for _, err := range result.Errors {
						if containsSubstring(err, tt.wantErr) {
							found = true
							break
						}
					}
					if !found {
						t.Errorf("expected error containing %q, got %v", tt.wantErr, result.Errors)
					}
				}
			}
		})
	}
}

func TestValidator_ValidateTV(t *testing.T) {
	tests := []struct {
		name    string
		setup   func(dir string)
		wantOK  bool
		wantErr string
	}{
		{
			name: "valid: sequential episodes starting at 1",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
				os.WriteFile(filepath.Join(dir, "_episodes", "01.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "02.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "03.mkv"), []byte{}, 0644)
			},
			wantOK: true,
		},
		{
			name: "valid: episodes with names",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
				os.WriteFile(filepath.Join(dir, "_episodes", "01_Pilot.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "02_Episode_Two.mkv"), []byte{}, 0644)
			},
			wantOK: true,
		},
		{
			name: "valid: multi-episode files",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
				os.WriteFile(filepath.Join(dir, "_episodes", "01-02.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "03.mkv"), []byte{}, 0644)
			},
			wantOK: true,
		},
		{
			name: "invalid: root has loose files",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
				os.WriteFile(filepath.Join(dir, "_episodes", "01.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "title_t00.mkv"), []byte{}, 0644)
			},
			wantOK:  false,
			wantErr: "root directory not empty",
		},
		{
			name: "invalid: _episodes missing",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_extras"), 0755)
			},
			wantOK:  false,
			wantErr: "_episodes directory not found",
		},
		{
			name: "invalid: _episodes has no mkv files",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
			},
			wantOK:  false,
			wantErr: "_episodes has no valid episode files",
		},
		{
			name: "invalid: gap in episode sequence",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
				os.WriteFile(filepath.Join(dir, "_episodes", "01.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "03.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "04.mkv"), []byte{}, 0644)
			},
			wantOK:  false,
			wantErr: "missing episode 2",
		},
		{
			name: "invalid: multiple gaps in sequence",
			setup: func(dir string) {
				os.MkdirAll(filepath.Join(dir, "_episodes"), 0755)
				os.WriteFile(filepath.Join(dir, "_episodes", "01.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "03.mkv"), []byte{}, 0644)
				os.WriteFile(filepath.Join(dir, "_episodes", "05.mkv"), []byte{}, 0644)
			},
			wantOK:  false,
			wantErr: "missing episode",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			tt.setup(dir)

			v := &Validator{}
			result := v.ValidateTV(dir)

			if result.Valid != tt.wantOK {
				t.Errorf("Valid = %v, want %v", result.Valid, tt.wantOK)
			}
			if !tt.wantOK {
				if len(result.Errors) == 0 {
					t.Error("expected errors but got none")
				}
				if tt.wantErr != "" {
					found := false
					for _, err := range result.Errors {
						if containsSubstring(err, tt.wantErr) {
							found = true
							break
						}
					}
					if !found {
						t.Errorf("expected error containing %q, got %v", tt.wantErr, result.Errors)
					}
				}
			}
		})
	}
}

func TestValidator_ParseEpisodeNumbers(t *testing.T) {
	tests := []struct {
		filename string
		want     []int // Changed to slice to support multi-episode files
		wantOK   bool
	}{
		{"01.mkv", []int{1}, true},
		{"02.mkv", []int{2}, true},
		{"10.mkv", []int{10}, true},
		{"01_Pilot.mkv", []int{1}, true},
		{"01_Episode_Name.mkv", []int{1}, true},
		{"01-02.mkv", []int{1, 2}, true}, // Multi-episode, parses all in range
		{"01-02_Combined.mkv", []int{1, 2}, true},
		{"episode_01.mkv", nil, false}, // Doesn't start with number
		{"1.mkv", []int{1}, true},
		{"001.mkv", []int{1}, true},
		{"readme.txt", nil, false},
		{"invalid.mkv", nil, false},
	}

	v := &Validator{}
	for _, tt := range tests {
		t.Run(tt.filename, func(t *testing.T) {
			dir := t.TempDir()
			filepath := filepath.Join(dir, tt.filename)
			os.WriteFile(filepath, []byte{}, 0644)

			episodes := v.parseEpisodeNumbers([]string{filepath})
			if tt.wantOK {
				if len(episodes) != len(tt.want) {
					t.Errorf("expected %d episodes, got %d", len(tt.want), len(episodes))
				} else {
					for i := range episodes {
						if episodes[i] != tt.want[i] {
							t.Errorf("parsed episodes = %v, want %v", episodes, tt.want)
							break
						}
					}
				}
			} else {
				if len(episodes) != 0 {
					t.Errorf("expected no episodes parsed, got %v", episodes)
				}
			}
		})
	}
}

func TestValidator_FindGaps(t *testing.T) {
	tests := []struct {
		name     string
		episodes []int
		want     []int
	}{
		{
			name:     "no gaps",
			episodes: []int{1, 2, 3, 4},
			want:     nil,
		},
		{
			name:     "single gap",
			episodes: []int{1, 3, 4},
			want:     []int{2},
		},
		{
			name:     "multiple gaps",
			episodes: []int{1, 3, 5, 7},
			want:     []int{2, 4, 6},
		},
		{
			name:     "empty list",
			episodes: []int{},
			want:     nil,
		},
		{
			name:     "single episode",
			episodes: []int{1},
			want:     nil,
		},
		{
			name:     "starting at non-1",
			episodes: []int{5, 6, 8},
			want:     []int{7},
		},
	}

	v := &Validator{}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := v.findGaps(tt.episodes)
			if len(got) != len(tt.want) {
				t.Errorf("findGaps() = %v, want %v", got, tt.want)
				return
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Errorf("findGaps() = %v, want %v", got, tt.want)
					break
				}
			}
		})
	}
}

// Helper function to check if a string contains a substring
func containsSubstring(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || findSubstring(s, substr))
}

func findSubstring(s, substr string) bool {
	for i := 0; i+len(substr) <= len(s); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
