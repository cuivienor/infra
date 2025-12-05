package ripper

import (
	"bufio"
	"io"
	"strconv"
	"strings"
	"time"
)

// MakeMKVParser parses MakeMKV output lines
type MakeMKVParser struct {
	discInfo DiscInfo
}

// NewMakeMKVParser creates a new parser
func NewMakeMKVParser() *MakeMKVParser {
	return &MakeMKVParser{
		discInfo: DiscInfo{
			Titles: []TitleInfo{},
		},
	}
}

// GetDiscInfo returns the parsed disc information
func (p *MakeMKVParser) GetDiscInfo() *DiscInfo {
	return &p.discInfo
}

// ParseLine parses a single line of MakeMKV output
func (p *MakeMKVParser) ParseLine(line string) {
	line = strings.TrimSpace(line)
	if line == "" {
		return
	}

	// Find the type prefix (e.g., "TCOUT:", "CINFO:", "TINFO:")
	colonIdx := strings.Index(line, ":")
	if colonIdx == -1 {
		return
	}

	prefix := line[:colonIdx]
	data := line[colonIdx+1:]

	switch prefix {
	case "TCOUT":
		p.parseTCOUT(data)
	case "CINFO":
		p.parseCINFO(data)
	case "TINFO":
		p.parseTINFO(data)
	}
}

// ParseReader parses all lines from a reader
func (p *MakeMKVParser) ParseReader(r io.Reader) error {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		p.ParseLine(scanner.Text())
	}
	return scanner.Err()
}

// parseTCOUT handles title count output: TCOUT:5
func (p *MakeMKVParser) parseTCOUT(data string) {
	count, err := strconv.Atoi(data)
	if err == nil {
		p.discInfo.TitleCount = count
	}
}

// parseCINFO handles disc info: CINFO:attr,code,"value"
func (p *MakeMKVParser) parseCINFO(data string) {
	parts := splitCSV(data)
	if len(parts) < 3 {
		return
	}

	attrID, err := strconv.Atoi(parts[0])
	if err != nil {
		return
	}

	value := unquote(parts[2])

	switch attrID {
	case 2: // Disc name
		p.discInfo.Name = value
	case 32: // Volume name / disc ID
		p.discInfo.ID = value
	}
}

// parseTINFO handles title info: TINFO:title,attr,code,"value"
func (p *MakeMKVParser) parseTINFO(data string) {
	parts := splitCSV(data)
	if len(parts) < 4 {
		return
	}

	titleIdx, err := strconv.Atoi(parts[0])
	if err != nil {
		return
	}

	attrID, err := strconv.Atoi(parts[1])
	if err != nil {
		return
	}

	value := unquote(parts[3])

	// Ensure we have enough title slots
	for len(p.discInfo.Titles) <= titleIdx {
		p.discInfo.Titles = append(p.discInfo.Titles, TitleInfo{
			Index: len(p.discInfo.Titles),
		})
	}

	title := &p.discInfo.Titles[titleIdx]

	switch attrID {
	case 2: // Title name
		title.Name = value
	case 9: // Duration
		title.Duration = parseDuration(value)
	case 10: // Size string
		title.Size = parseSize(value)
	case 27: // Output filename
		title.Filename = value
	}
}

// ParseProgress parses a PRGV progress line: PRGV:current,total,max
// Returns current, total, max values and ok=true if valid
func ParseProgress(line string) (current, total, max int, ok bool) {
	if !strings.HasPrefix(line, "PRGV:") {
		return 0, 0, 0, false
	}

	data := line[5:] // Skip "PRGV:"
	parts := strings.Split(data, ",")
	if len(parts) != 3 {
		return 0, 0, 0, false
	}

	var err error
	current, err = strconv.Atoi(parts[0])
	if err != nil {
		return 0, 0, 0, false
	}

	total, err = strconv.Atoi(parts[1])
	if err != nil {
		return 0, 0, 0, false
	}

	max, err = strconv.Atoi(parts[2])
	if err != nil {
		return 0, 0, 0, false
	}

	return current, total, max, true
}

// parseDuration parses a duration string like "1:30:45" into time.Duration
func parseDuration(s string) time.Duration {
	parts := strings.Split(s, ":")
	if len(parts) != 3 {
		return 0
	}

	hours, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0
	}

	minutes, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0
	}

	seconds, err := strconv.Atoi(parts[2])
	if err != nil {
		return 0
	}

	return time.Duration(hours)*time.Hour +
		time.Duration(minutes)*time.Minute +
		time.Duration(seconds)*time.Second
}

// parseSize parses a size string like "4.5 GB" into bytes
func parseSize(s string) int64 {
	parts := strings.Fields(s)
	if len(parts) != 2 {
		return 0
	}

	value, err := strconv.ParseFloat(parts[0], 64)
	if err != nil {
		return 0
	}

	unit := strings.ToUpper(parts[1])
	var multiplier float64

	switch unit {
	case "KB":
		multiplier = 1024
	case "MB":
		multiplier = 1024 * 1024
	case "GB":
		multiplier = 1024 * 1024 * 1024
	case "TB":
		multiplier = 1024 * 1024 * 1024 * 1024
	default:
		multiplier = 1
	}

	return int64(value * multiplier)
}

// splitCSV splits a CSV line, respecting quoted strings
func splitCSV(s string) []string {
	var parts []string
	var current strings.Builder
	inQuotes := false

	for _, r := range s {
		switch {
		case r == '"':
			inQuotes = !inQuotes
			current.WriteRune(r)
		case r == ',' && !inQuotes:
			parts = append(parts, current.String())
			current.Reset()
		default:
			current.WriteRune(r)
		}
	}
	parts = append(parts, current.String())

	return parts
}

// unquote removes surrounding quotes from a string
func unquote(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		return s[1 : len(s)-1]
	}
	return s
}
