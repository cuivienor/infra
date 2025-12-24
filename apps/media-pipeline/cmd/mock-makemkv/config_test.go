package main

import (
	"testing"
	"time"
)

func TestDiscType_Constants(t *testing.T) {
	// Verify disc type constants are defined
	tests := []struct {
		dt   DiscType
		want string
	}{
		{DiscTypeMovie, "movie"},
		{DiscTypeTVSeason, "tv_season"},
		{DiscTypeProblem, "problem"},
	}

	for _, tt := range tests {
		if string(tt.dt) != tt.want {
			t.Errorf("DiscType = %q, want %q", tt.dt, tt.want)
		}
	}
}

func TestConfig_Defaults(t *testing.T) {
	cfg := DefaultConfig()

	if cfg.TitleDuration != 5*time.Second {
		t.Errorf("TitleDuration = %v, want 5s", cfg.TitleDuration)
	}
	if cfg.DelayPerTitle != 0 {
		t.Errorf("DelayPerTitle = %v, want 0 for fast tests", cfg.DelayPerTitle)
	}
	if cfg.FailOnTitle != -1 {
		t.Errorf("FailOnTitle = %d, want -1 (no failure)", cfg.FailOnTitle)
	}
}

func TestGetProfile_BuiltinMovie(t *testing.T) {
	profile := GetProfile("big_buck_bunny")

	if profile == nil {
		t.Fatal("GetProfile returned nil for big_buck_bunny")
	}
	if profile.Name != "Big_Buck_Bunny" {
		t.Errorf("Name = %q, want Big_Buck_Bunny", profile.Name)
	}
	if profile.DiscTitle != "Big Buck Bunny" {
		t.Errorf("DiscTitle = %q, want 'Big Buck Bunny'", profile.DiscTitle)
	}
	if profile.DiscID != "BIGBUCKBUNNY" {
		t.Errorf("DiscID = %q, want BIGBUCKBUNNY", profile.DiscID)
	}
	if len(profile.Titles) < 1 {
		t.Error("Expected at least 1 title")
	}
	if profile.MainTitle != 0 {
		t.Errorf("MainTitle = %d, want 0", profile.MainTitle)
	}
}

func TestGetProfile_BuiltinTV(t *testing.T) {
	profile := GetProfile("simpsons_s01d01")

	if profile == nil {
		t.Fatal("GetProfile returned nil for simpsons_s01d01")
	}
	if profile.Name != "The_Simpsons_S01D01" {
		t.Errorf("Name = %q, want The_Simpsons_S01D01", profile.Name)
	}
	if len(profile.Titles) < 3 {
		t.Error("Expected at least 3 episodes on disc")
	}
	if profile.MainTitle != -1 {
		t.Errorf("MainTitle = %d, want -1 (no single main for TV)", profile.MainTitle)
	}
}

func TestGetProfile_ProblemDisc(t *testing.T) {
	profile := GetProfile("problem_disc")

	if profile == nil {
		t.Fatal("GetProfile returned nil for problem_disc")
	}
	if !profile.SimulateFailure {
		t.Error("problem_disc should have SimulateFailure = true")
	}
	if profile.FailAtPercent <= 0 || profile.FailAtPercent >= 100 {
		t.Errorf("FailAtPercent = %d, want 1-99", profile.FailAtPercent)
	}
}

func TestGetProfile_Unknown(t *testing.T) {
	profile := GetProfile("nonexistent_disc")

	if profile == nil {
		t.Fatal("GetProfile should return default profile for unknown disc")
	}
	// Should return a simple default movie profile
	if profile.Name == "" {
		t.Error("Default profile should have a name")
	}
}

func TestTitleInfo_Duration(t *testing.T) {
	title := TitleInfo{
		Index:    0,
		Name:     "Test Title",
		Duration: 5 * time.Second,
		Size:     1024 * 1024 * 100, // 100MB
		Filename: "title_t00.mkv",
	}

	if title.Duration != 5*time.Second {
		t.Errorf("Duration = %v, want 5s", title.Duration)
	}
	if title.Filename != "title_t00.mkv" {
		t.Errorf("Filename = %q, want title_t00.mkv", title.Filename)
	}
}
