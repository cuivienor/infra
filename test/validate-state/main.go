package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// stageMetadata mirrors scanner's expected structure
type stageMetadata struct {
	Type     string `json:"type"`
	Name     string `json:"name"`
	SafeName string `json:"safe_name"`
	Season   string `json:"season"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: validate-state <state-dir>")
		fmt.Println("Example: validate-state /path/to/.rip")
		os.Exit(1)
	}

	stateDir := os.Args[1]
	errors := validateStateDir(stateDir)

	if len(errors) > 0 {
		fmt.Println("FAIL: State validation errors:")
		for _, err := range errors {
			fmt.Printf("  - %s\n", err)
		}
		os.Exit(1)
	}

	fmt.Printf("PASS: %s is valid\n", stateDir)
	os.Exit(0)
}

func validateStateDir(stateDir string) []string {
	var errors []string

	// Check directory exists
	info, err := os.Stat(stateDir)
	if err != nil {
		return []string{fmt.Sprintf("state directory does not exist: %s", stateDir)}
	}
	if !info.IsDir() {
		return []string{fmt.Sprintf("not a directory: %s", stateDir)}
	}

	// Check metadata.json exists and is valid
	metadataPath := filepath.Join(stateDir, "metadata.json")
	metadataBytes, err := os.ReadFile(metadataPath)
	if err != nil {
		errors = append(errors, fmt.Sprintf("metadata.json missing or unreadable: %v", err))
	} else {
		var metadata stageMetadata
		if err := json.Unmarshal(metadataBytes, &metadata); err != nil {
			errors = append(errors, fmt.Sprintf("metadata.json invalid JSON: %v", err))
		} else {
			// Validate required fields
			if metadata.Type == "" {
				errors = append(errors, "metadata.json: 'type' field is empty")
			} else if metadata.Type != "movie" && metadata.Type != "tv" && metadata.Type != "show" {
				errors = append(errors, fmt.Sprintf("metadata.json: 'type' must be 'movie' or 'tv', got '%s'", metadata.Type))
			}
			if metadata.Name == "" {
				errors = append(errors, "metadata.json: 'name' field is empty")
			}
			if metadata.SafeName == "" {
				errors = append(errors, "metadata.json: 'safe_name' field is empty")
			}
		}
	}

	// Check status file exists and has valid value
	statusPath := filepath.Join(stateDir, "status")
	statusBytes, err := os.ReadFile(statusPath)
	if err != nil {
		errors = append(errors, fmt.Sprintf("status file missing or unreadable: %v", err))
	} else {
		status := strings.TrimSpace(string(statusBytes))
		validStatuses := map[string]bool{
			"pending": true, "in_progress": true, "completed": true, "failed": true,
		}
		if !validStatuses[status] {
			errors = append(errors, fmt.Sprintf("status file: invalid value '%s', must be one of: pending, in_progress, completed, failed", status))
		}
	}

	return errors
}
