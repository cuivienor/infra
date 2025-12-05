package ripper

import (
	"strings"
	"testing"
	"time"
)

func TestMakeMKVParser_ParseLine_TCOUT(t *testing.T) {
	p := NewMakeMKVParser()

	p.ParseLine("TCOUT:5")

	info := p.GetDiscInfo()
	if info.TitleCount != 5 {
		t.Errorf("TitleCount = %d, want 5", info.TitleCount)
	}
}

func TestMakeMKVParser_ParseLine_CINFO_DiscTitle(t *testing.T) {
	p := NewMakeMKVParser()

	// Attribute 2 is disc name
	p.ParseLine(`CINFO:2,0,"Big Buck Bunny"`)

	info := p.GetDiscInfo()
	if info.Name != "Big Buck Bunny" {
		t.Errorf("Name = %q, want 'Big Buck Bunny'", info.Name)
	}
}

func TestMakeMKVParser_ParseLine_CINFO_DiscID(t *testing.T) {
	p := NewMakeMKVParser()

	// Attribute 32 is volume name / disc ID
	p.ParseLine(`CINFO:32,0,"BIGBUCKBUNNY"`)

	info := p.GetDiscInfo()
	if info.ID != "BIGBUCKBUNNY" {
		t.Errorf("ID = %q, want 'BIGBUCKBUNNY'", info.ID)
	}
}

func TestMakeMKVParser_ParseLine_TINFO_TitleName(t *testing.T) {
	p := NewMakeMKVParser()

	// Attribute 2 is title name
	p.ParseLine(`TINFO:0,2,0,"Main Feature"`)

	info := p.GetDiscInfo()
	if len(info.Titles) != 1 {
		t.Fatalf("Expected 1 title, got %d", len(info.Titles))
	}
	if info.Titles[0].Name != "Main Feature" {
		t.Errorf("Title name = %q, want 'Main Feature'", info.Titles[0].Name)
	}
}

func TestMakeMKVParser_ParseLine_TINFO_Duration(t *testing.T) {
	p := NewMakeMKVParser()

	// Attribute 9 is duration
	p.ParseLine(`TINFO:0,9,0,"1:30:45"`)

	info := p.GetDiscInfo()
	if len(info.Titles) != 1 {
		t.Fatalf("Expected 1 title, got %d", len(info.Titles))
	}

	expected := 1*time.Hour + 30*time.Minute + 45*time.Second
	if info.Titles[0].Duration != expected {
		t.Errorf("Duration = %v, want %v", info.Titles[0].Duration, expected)
	}
}

func TestMakeMKVParser_ParseLine_TINFO_Size(t *testing.T) {
	p := NewMakeMKVParser()

	// Attribute 10 is size string
	p.ParseLine(`TINFO:0,10,0,"4.5 GB"`)

	info := p.GetDiscInfo()
	if len(info.Titles) != 1 {
		t.Fatalf("Expected 1 title, got %d", len(info.Titles))
	}

	// 4.5 GB in bytes
	expectedSize := int64(4.5 * 1024 * 1024 * 1024)
	// Allow some tolerance for floating point
	if info.Titles[0].Size < expectedSize-1000 || info.Titles[0].Size > expectedSize+1000 {
		t.Errorf("Size = %d, want ~%d", info.Titles[0].Size, expectedSize)
	}
}

func TestMakeMKVParser_ParseLine_TINFO_Filename(t *testing.T) {
	p := NewMakeMKVParser()

	// Attribute 27 is output filename
	p.ParseLine(`TINFO:0,27,0,"title_t00.mkv"`)

	info := p.GetDiscInfo()
	if len(info.Titles) != 1 {
		t.Fatalf("Expected 1 title, got %d", len(info.Titles))
	}
	if info.Titles[0].Filename != "title_t00.mkv" {
		t.Errorf("Filename = %q, want 'title_t00.mkv'", info.Titles[0].Filename)
	}
}

func TestMakeMKVParser_MultipleTitles(t *testing.T) {
	p := NewMakeMKVParser()

	p.ParseLine("TCOUT:3")
	p.ParseLine(`TINFO:0,2,0,"Title 1"`)
	p.ParseLine(`TINFO:1,2,0,"Title 2"`)
	p.ParseLine(`TINFO:2,2,0,"Title 3"`)

	info := p.GetDiscInfo()
	if len(info.Titles) != 3 {
		t.Fatalf("Expected 3 titles, got %d", len(info.Titles))
	}
	if info.Titles[0].Name != "Title 1" {
		t.Errorf("Title 0 name = %q, want 'Title 1'", info.Titles[0].Name)
	}
	if info.Titles[2].Name != "Title 3" {
		t.Errorf("Title 2 name = %q, want 'Title 3'", info.Titles[2].Name)
	}
}

func TestParseProgress_ValidPRGV(t *testing.T) {
	current, total, max, ok := ParseProgress("PRGV:32768,0,65536")

	if !ok {
		t.Fatal("ParseProgress returned ok=false for valid PRGV")
	}
	if current != 32768 {
		t.Errorf("current = %d, want 32768", current)
	}
	if total != 0 {
		t.Errorf("total = %d, want 0", total)
	}
	if max != 65536 {
		t.Errorf("max = %d, want 65536", max)
	}
}

func TestParseProgress_InvalidLine(t *testing.T) {
	_, _, _, ok := ParseProgress("MSG:1005,0,1,\"Test\"")

	if ok {
		t.Error("ParseProgress should return ok=false for non-PRGV line")
	}
}

func TestParseProgress_Percentage(t *testing.T) {
	current, _, max, ok := ParseProgress("PRGV:32768,0,65536")

	if !ok {
		t.Fatal("ParseProgress failed")
	}

	percentage := float64(current) / float64(max) * 100
	if percentage != 50.0 {
		t.Errorf("percentage = %v, want 50.0", percentage)
	}
}

func TestParseDuration_ValidFormats(t *testing.T) {
	tests := []struct {
		input string
		want  time.Duration
	}{
		{"0:00:05", 5 * time.Second},
		{"0:01:30", 90 * time.Second},
		{"1:00:00", 1 * time.Hour},
		{"2:30:45", 2*time.Hour + 30*time.Minute + 45*time.Second},
	}

	for _, tt := range tests {
		got := parseDuration(tt.input)
		if got != tt.want {
			t.Errorf("parseDuration(%q) = %v, want %v", tt.input, got, tt.want)
		}
	}
}

func TestParseSize_ValidFormats(t *testing.T) {
	tests := []struct {
		input string
		want  int64
	}{
		{"100 KB", 100 * 1024},
		{"50 MB", 50 * 1024 * 1024},
		{"4.5 GB", int64(4.5 * 1024 * 1024 * 1024)},
		{"1 GB", 1 * 1024 * 1024 * 1024},
	}

	for _, tt := range tests {
		got := parseSize(tt.input)
		// Allow small tolerance for floating point
		diff := got - tt.want
		if diff < -1000 || diff > 1000 {
			t.Errorf("parseSize(%q) = %d, want %d", tt.input, got, tt.want)
		}
	}
}

func TestMakeMKVParser_ParseReader(t *testing.T) {
	input := `MSG:1005,0,1,"MakeMKV started"
CINFO:2,0,"Test Disc"
CINFO:32,0,"TESTDISC"
TCOUT:2
TINFO:0,2,0,"Main Feature"
TINFO:0,9,0,"1:30:00"
TINFO:0,27,0,"title_t00.mkv"
TINFO:1,2,0,"Bonus"
TINFO:1,9,0,"0:10:00"
`
	p := NewMakeMKVParser()
	err := p.ParseReader(strings.NewReader(input))
	if err != nil {
		t.Fatalf("ParseReader failed: %v", err)
	}

	info := p.GetDiscInfo()
	if info.Name != "Test Disc" {
		t.Errorf("Name = %q, want 'Test Disc'", info.Name)
	}
	if info.TitleCount != 2 {
		t.Errorf("TitleCount = %d, want 2", info.TitleCount)
	}
	if len(info.Titles) != 2 {
		t.Errorf("len(Titles) = %d, want 2", len(info.Titles))
	}
}
