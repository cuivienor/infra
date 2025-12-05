package main

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func TestOutputWriter_WriteDRV(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	w.WriteDRV(0, "BD-ROM HL-DT-ST", "Big Buck Bunny")

	output := buf.String()
	// DRV format: DRV:index,visible,enabled,flags,"device_name","disc_name"
	if !strings.Contains(output, "DRV:0,") {
		t.Errorf("Expected DRV:0,..., got %q", output)
	}
	if !strings.Contains(output, `"Big Buck Bunny"`) {
		t.Errorf("Expected disc name in output, got %q", output)
	}
}

func TestOutputWriter_WriteCINFO(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	// Write disc title (attribute 2)
	w.WriteCINFO(2, 0, "Big Buck Bunny")

	output := buf.String()
	// CINFO format: CINFO:id,code,"value"
	if !strings.HasPrefix(output, "CINFO:2,0,") {
		t.Errorf("Expected CINFO:2,0,..., got %q", output)
	}
	if !strings.Contains(output, `"Big Buck Bunny"`) {
		t.Errorf("Expected quoted value, got %q", output)
	}
}

func TestOutputWriter_WriteTCOUT(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	w.WriteTCOUT(5)

	output := buf.String()
	expected := "TCOUT:5\n"
	if output != expected {
		t.Errorf("Got %q, want %q", output, expected)
	}
}

func TestOutputWriter_WriteTINFO(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	// Write title name (attribute 2)
	w.WriteTINFO(0, 2, 0, "Big Buck Bunny")

	output := buf.String()
	// TINFO format: TINFO:titleIdx,attrId,code,"value"
	if !strings.HasPrefix(output, "TINFO:0,2,0,") {
		t.Errorf("Expected TINFO:0,2,0,..., got %q", output)
	}
	if !strings.Contains(output, `"Big Buck Bunny"`) {
		t.Errorf("Expected quoted value, got %q", output)
	}
}

func TestOutputWriter_WriteTINFO_Duration(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	// Write duration (attribute 9) - format should be "H:MM:SS"
	w.WriteTINFO(0, 9, 0, "0:05:30")

	output := buf.String()
	if !strings.Contains(output, `"0:05:30"`) {
		t.Errorf("Expected duration format in output, got %q", output)
	}
}

func TestOutputWriter_WritePRGV(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	// PRGV format: PRGV:current,total,max
	w.WritePRGV(32768, 0, 65536)

	output := buf.String()
	expected := "PRGV:32768,0,65536\n"
	if output != expected {
		t.Errorf("Got %q, want %q", output, expected)
	}
}

func TestOutputWriter_WriteMSG(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	w.WriteMSG(1005, "MakeMKV started")

	output := buf.String()
	if !strings.HasPrefix(output, "MSG:1005,") {
		t.Errorf("Expected MSG:1005,..., got %q", output)
	}
	if !strings.Contains(output, "MakeMKV started") {
		t.Errorf("Expected message in output, got %q", output)
	}
}

func TestOutputWriter_WriteDiscInfo(t *testing.T) {
	var buf bytes.Buffer
	w := NewOutputWriter(&buf)

	profile := &DiscProfile{
		Name:      "Big_Buck_Bunny",
		DiscTitle: "Big Buck Bunny",
		DiscID:    "BIGBUCKBUNNY",
		Titles: []TitleInfo{
			{Index: 0, Name: "Big Buck Bunny", Duration: 5 * time.Second, Size: 100 * 1024 * 1024, Filename: "title_t00.mkv"},
			{Index: 1, Name: "Making Of", Duration: 5 * time.Second, Size: 50 * 1024 * 1024, Filename: "title_t01.mkv"},
		},
		MainTitle: 0,
	}

	w.WriteDiscInfo(profile)

	output := buf.String()

	// Should contain CINFO for disc title
	if !strings.Contains(output, "CINFO:2,") {
		t.Error("Expected CINFO for disc title")
	}

	// Should contain TCOUT
	if !strings.Contains(output, "TCOUT:2") {
		t.Error("Expected TCOUT with title count")
	}

	// Should contain TINFO for each title
	if !strings.Contains(output, "TINFO:0,") {
		t.Error("Expected TINFO for title 0")
	}
	if !strings.Contains(output, "TINFO:1,") {
		t.Error("Expected TINFO for title 1")
	}
}

func TestFormatDuration(t *testing.T) {
	tests := []struct {
		duration time.Duration
		want     string
	}{
		{5 * time.Second, "0:00:05"},
		{65 * time.Second, "0:01:05"},
		{3661 * time.Second, "1:01:01"},
		{2*time.Hour + 30*time.Minute + 45*time.Second, "2:30:45"},
	}

	for _, tt := range tests {
		got := FormatDuration(tt.duration)
		if got != tt.want {
			t.Errorf("FormatDuration(%v) = %q, want %q", tt.duration, got, tt.want)
		}
	}
}

func TestFormatSize(t *testing.T) {
	tests := []struct {
		size int64
		want string
	}{
		{500 * 1024, "500 KB"},
		{50 * 1024 * 1024, "50.0 MB"},
		{1500 * 1024 * 1024, "1.5 GB"},
		{4 * 1024 * 1024 * 1024, "4.0 GB"},
	}

	for _, tt := range tests {
		got := FormatSize(tt.size)
		if got != tt.want {
			t.Errorf("FormatSize(%d) = %q, want %q", tt.size, got, tt.want)
		}
	}
}
