package main

import (
	"time"
)

// DiscType defines the type of disc being mocked
type DiscType string

const (
	DiscTypeMovie    DiscType = "movie"
	DiscTypeTVSeason DiscType = "tv_season"
	DiscTypeProblem  DiscType = "problem"
)

// TitleInfo represents a title found on the disc
type TitleInfo struct {
	Index    int
	Name     string
	Duration time.Duration
	Size     int64  // bytes
	Filename string // output filename
}

// DiscProfile defines a complete disc simulation
type DiscProfile struct {
	Name            string      // e.g., "Big_Buck_Bunny", "The_Simpsons_S01D01"
	DiscTitle       string      // Human readable disc title
	DiscID          string      // e.g., "BIGBUCKBUNNY", "SIMPSONS_S1"
	Titles          []TitleInfo // Titles on the disc
	MainTitle       int         // Index of main title (for movies), -1 for TV
	SimulateFailure bool        // Whether to simulate a rip failure
	FailAtPercent   int         // Percent at which to fail (1-99)
}

// Config holds mock behavior configuration
type Config struct {
	DiscType      DiscType      // Type of disc to simulate
	Profile       string        // Profile name to use
	TitleDuration time.Duration // Duration of each generated title
	DelayPerTitle time.Duration // Simulated time to "rip" each title
	FailOnTitle   int           // Title index to fail on (-1 for no failure)
	OutputDir     string        // Where to write files
}

// DefaultConfig returns a configuration suitable for fast testing
func DefaultConfig() Config {
	return Config{
		DiscType:      DiscTypeMovie,
		Profile:       "big_buck_bunny",
		TitleDuration: 5 * time.Second,
		DelayPerTitle: 0, // Instant for fast tests
		FailOnTitle:   -1,
	}
}

// BuiltinProfiles contains pre-defined disc profiles for testing
var BuiltinProfiles = map[string]*DiscProfile{
	"big_buck_bunny": {
		Name:      "Big_Buck_Bunny",
		DiscTitle: "Big Buck Bunny",
		DiscID:    "BIGBUCKBUNNY",
		Titles: []TitleInfo{
			{Index: 0, Name: "Big Buck Bunny", Duration: 5 * time.Second, Size: 100 * 1024 * 1024, Filename: "title_t00.mkv"},
			{Index: 1, Name: "Making Of", Duration: 5 * time.Second, Size: 50 * 1024 * 1024, Filename: "title_t01.mkv"},
			{Index: 2, Name: "Trailer", Duration: 5 * time.Second, Size: 20 * 1024 * 1024, Filename: "title_t02.mkv"},
		},
		MainTitle: 0,
	},
	"simpsons_s01d01": {
		Name:      "The_Simpsons_S01D01",
		DiscTitle: "The Simpsons: Season 1: Disc 1",
		DiscID:    "SIMPSONS_S1D1",
		Titles: []TitleInfo{
			{Index: 0, Name: "Simpsons Roasting on an Open Fire", Duration: 5 * time.Second, Size: 80 * 1024 * 1024, Filename: "title_t00.mkv"},
			{Index: 1, Name: "Bart the Genius", Duration: 5 * time.Second, Size: 80 * 1024 * 1024, Filename: "title_t01.mkv"},
			{Index: 2, Name: "Homer's Odyssey", Duration: 5 * time.Second, Size: 80 * 1024 * 1024, Filename: "title_t02.mkv"},
			{Index: 3, Name: "There's No Disgrace Like Home", Duration: 5 * time.Second, Size: 80 * 1024 * 1024, Filename: "title_t03.mkv"},
			{Index: 4, Name: "Bart the General", Duration: 5 * time.Second, Size: 80 * 1024 * 1024, Filename: "title_t04.mkv"},
		},
		MainTitle: -1, // No single main title for TV
	},
	"problem_disc": {
		Name:            "Problem_Disc",
		DiscTitle:       "Problem Disc",
		DiscID:          "PROBLEMDISC",
		Titles:          []TitleInfo{{Index: 0, Name: "Title 00", Duration: 5 * time.Second, Size: 100 * 1024 * 1024, Filename: "title_t00.mkv"}},
		MainTitle:       0,
		SimulateFailure: true,
		FailAtPercent:   45,
	},
}

// defaultProfile is used when no matching profile is found
var defaultProfile = &DiscProfile{
	Name:      "Default_Movie",
	DiscTitle: "Default Movie",
	DiscID:    "DEFAULTMOVIE",
	Titles: []TitleInfo{
		{Index: 0, Name: "Main Feature", Duration: 5 * time.Second, Size: 100 * 1024 * 1024, Filename: "title_t00.mkv"},
	},
	MainTitle: 0,
}

// GetProfile returns a disc profile by name, or default if not found
func GetProfile(name string) *DiscProfile {
	if profile, ok := BuiltinProfiles[name]; ok {
		return profile
	}
	return defaultProfile
}
