//go:build integration

package publish

import (
	"os/exec"
	"testing"
)

func TestPublisher_Integration_MockFilebot(t *testing.T) {
	// Skip if filebot not installed
	if _, err := exec.LookPath("filebot"); err != nil {
		t.Skip("filebot not installed")
	}

	// This test would need actual filebot or a mock script
	// For now, test the components individually
	t.Skip("requires filebot setup")
}
