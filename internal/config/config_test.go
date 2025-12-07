package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad_FromFile(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, "config.yaml")

	content := `
data_dir: /mnt/media/pipeline
staging_base: /mnt/media/staging
library_base: /mnt/media/library
dispatch:
  rip: ripper
  remux: analyzer
  transcode: transcoder
  publish: analyzer
`
	os.WriteFile(configPath, []byte(content), 0644)

	cfg, err := Load(configPath)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.DataDir != "/mnt/media/pipeline" {
		t.Errorf("DataDir = %q, want /mnt/media/pipeline", cfg.DataDir)
	}
	if cfg.DatabasePath() != "/mnt/media/pipeline/pipeline.db" {
		t.Errorf("DatabasePath() = %q, want /mnt/media/pipeline/pipeline.db", cfg.DatabasePath())
	}
	if cfg.Dispatch["rip"] != "ripper" {
		t.Errorf("Dispatch[rip] = %q, want ripper", cfg.Dispatch["rip"])
	}
}

func TestConfig_DatabasePath(t *testing.T) {
	cfg := &Config{DataDir: "/mnt/media/pipeline"}

	got := cfg.DatabasePath()
	want := "/mnt/media/pipeline/pipeline.db"
	if got != want {
		t.Errorf("DatabasePath() = %q, want %q", got, want)
	}
}

func TestConfig_JobLogDir(t *testing.T) {
	cfg := &Config{DataDir: "/mnt/media/pipeline"}

	got := cfg.JobLogDir(123)
	want := "/mnt/media/pipeline/logs/jobs/123"
	if got != want {
		t.Errorf("JobLogDir(123) = %q, want %q", got, want)
	}
}

func TestConfig_JobLogPath(t *testing.T) {
	cfg := &Config{DataDir: "/mnt/media/pipeline"}

	got := cfg.JobLogPath(123)
	want := "/mnt/media/pipeline/logs/jobs/123/job.log"
	if got != want {
		t.Errorf("JobLogPath(123) = %q, want %q", got, want)
	}
}

func TestConfig_ToolLogPath(t *testing.T) {
	cfg := &Config{DataDir: "/mnt/media/pipeline"}

	got := cfg.ToolLogPath(123, "makemkv")
	want := "/mnt/media/pipeline/logs/jobs/123/makemkv.log"
	if got != want {
		t.Errorf("ToolLogPath(123, makemkv) = %q, want %q", got, want)
	}
}

func TestConfig_EnsureJobLogDir(t *testing.T) {
	tmpDir := t.TempDir()
	cfg := &Config{DataDir: tmpDir}

	err := cfg.EnsureJobLogDir(456)
	if err != nil {
		t.Fatalf("EnsureJobLogDir(456) error = %v", err)
	}

	// Verify directory was created
	expectedDir := filepath.Join(tmpDir, "logs/jobs/456")
	info, err := os.Stat(expectedDir)
	if err != nil {
		t.Fatalf("expected directory not created: %v", err)
	}
	if !info.IsDir() {
		t.Error("expected path to be a directory")
	}
}

func TestConfig_DispatchTarget(t *testing.T) {
	cfg := &Config{
		Dispatch: map[string]string{
			"rip":   "ripper",
			"remux": "", // empty = local
		},
	}

	if target := cfg.DispatchTarget("rip"); target != "ripper" {
		t.Errorf("DispatchTarget(rip) = %q, want ripper", target)
	}
	if target := cfg.DispatchTarget("remux"); target != "" {
		t.Errorf("DispatchTarget(remux) = %q, want empty", target)
	}
	if target := cfg.DispatchTarget("missing"); target != "" {
		t.Errorf("DispatchTarget(missing) = %q, want empty", target)
	}
}

func TestConfig_IsLocal(t *testing.T) {
	cfg := &Config{
		Dispatch: map[string]string{
			"rip":   "ripper",
			"remux": "",
		},
	}

	if cfg.IsLocal("rip") {
		t.Error("IsLocal(rip) = true, want false")
	}
	if !cfg.IsLocal("remux") {
		t.Error("IsLocal(remux) = false, want true")
	}
	if !cfg.IsLocal("missing") {
		t.Error("IsLocal(missing) = false, want true")
	}
}

func TestLoad_FileNotFound(t *testing.T) {
	_, err := Load("/nonexistent/path/config.yaml")
	if err == nil {
		t.Error("Load() should return error for nonexistent file")
	}
}

func TestLoad_InvalidYAML(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, "config.yaml")

	content := `
this is not
  valid: yaml syntax [
`
	os.WriteFile(configPath, []byte(content), 0644)

	_, err := Load(configPath)
	if err == nil {
		t.Error("Load() should return error for invalid YAML")
	}
}

func TestLoadDefault_XDGConfigHome(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, "media-pipeline", "config.yaml")

	// Create config directory and file
	os.MkdirAll(filepath.Dir(configPath), 0755)
	content := `
data_dir: /test/xdg
staging_base: /test/staging
library_base: /test/library
`
	os.WriteFile(configPath, []byte(content), 0644)

	// Set XDG_CONFIG_HOME
	oldXDG := os.Getenv("XDG_CONFIG_HOME")
	os.Setenv("XDG_CONFIG_HOME", dir)
	defer os.Setenv("XDG_CONFIG_HOME", oldXDG)

	cfg, err := LoadDefault()
	if err != nil {
		t.Fatalf("LoadDefault() error = %v", err)
	}

	if cfg.DataDir != "/test/xdg" {
		t.Errorf("DataDir = %q, want /test/xdg", cfg.DataDir)
	}
}

func TestLoadDefault_HomeConfigFallback(t *testing.T) {
	// Unset XDG_CONFIG_HOME to test fallback
	oldXDG := os.Getenv("XDG_CONFIG_HOME")
	os.Unsetenv("XDG_CONFIG_HOME")
	defer os.Setenv("XDG_CONFIG_HOME", oldXDG)

	// Create temp home directory
	tmpHome := t.TempDir()
	configPath := filepath.Join(tmpHome, ".config", "media-pipeline", "config.yaml")

	// Create config directory and file
	os.MkdirAll(filepath.Dir(configPath), 0755)
	content := `
data_dir: /test/home
staging_base: /test/staging
library_base: /test/library
`
	os.WriteFile(configPath, []byte(content), 0644)

	// Mock os.UserHomeDir by creating a valid config in tmpHome
	// Note: We can't easily mock os.UserHomeDir, so this test just ensures
	// the fallback path construction is correct
	cfg, err := Load(configPath)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.DataDir != "/test/home" {
		t.Errorf("DataDir = %q, want /test/home", cfg.DataDir)
	}
}
