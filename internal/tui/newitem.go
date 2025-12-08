package tui

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/cuivienor/media-pipeline/internal/model"
)

// NewItemForm holds the form state for creating a new item
type NewItemForm struct {
	Type       string // "movie" or "tv"
	Name       string
	Seasons    string // For TV: "1-5" or "1,2,3" or "1"
	focusIndex int
	err        string
}

// fields returns the list of field names in order
func (f *NewItemForm) fields() []string {
	if f.Type == "tv" {
		return []string{"type", "name", "seasons"}
	}
	return []string{"type", "name"}
}

// Validate returns an error message if the form is invalid
func (f *NewItemForm) Validate() string {
	if f.Name == "" {
		return "Name is required"
	}
	if f.Type == "tv" && f.Seasons == "" {
		return "Seasons is required for TV shows (e.g., '1-5' or '1,2,3')"
	}
	if f.Type == "tv" {
		if _, err := parseSeasons(f.Seasons); err != nil {
			return err.Error()
		}
	}
	return ""
}

// parseSeasons parses a season string like "1-5" or "1,2,3" into a slice of ints
func parseSeasons(s string) ([]int, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, fmt.Errorf("seasons cannot be empty")
	}

	seen := make(map[int]bool)

	// Handle range: "1-5"
	if strings.Contains(s, "-") {
		parts := strings.Split(s, "-")
		if len(parts) != 2 {
			return nil, fmt.Errorf("invalid range format, use '1-5'")
		}
		start, err := strconv.Atoi(strings.TrimSpace(parts[0]))
		if err != nil {
			return nil, fmt.Errorf("invalid start number")
		}
		end, err := strconv.Atoi(strings.TrimSpace(parts[1]))
		if err != nil {
			return nil, fmt.Errorf("invalid end number")
		}
		if start < 1 {
			return nil, fmt.Errorf("season numbers must be positive (1 or greater)")
		}
		if start > end {
			return nil, fmt.Errorf("start must be less than or equal to end")
		}
		var seasons []int
		for i := start; i <= end; i++ {
			seasons = append(seasons, i)
		}
		return seasons, nil
	}

	// Handle comma-separated: "1,2,3"
	if strings.Contains(s, ",") {
		parts := strings.Split(s, ",")
		var seasons []int
		for _, p := range parts {
			n, err := strconv.Atoi(strings.TrimSpace(p))
			if err != nil {
				return nil, fmt.Errorf("invalid season number: %s", p)
			}
			if n < 1 {
				return nil, fmt.Errorf("season numbers must be positive (1 or greater)")
			}
			if seen[n] {
				return nil, fmt.Errorf("duplicate season number: %d", n)
			}
			seasons = append(seasons, n)
			seen[n] = true
		}
		return seasons, nil
	}

	// Single number
	n, err := strconv.Atoi(s)
	if err != nil {
		return nil, fmt.Errorf("invalid season number")
	}
	if n < 1 {
		return nil, fmt.Errorf("season numbers must be positive (1 or greater)")
	}
	return []int{n}, nil
}

// renderNewItemForm renders the new item form view
func (a *App) renderNewItemForm() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("New Item"))
	b.WriteString("\n\n")

	form := a.newItemForm
	fields := form.fields()

	for i, field := range fields {
		prefix := "  "
		if i == form.focusIndex {
			prefix = "> "
		}

		switch field {
		case "type":
			typeStr := "[movie]  tv"
			if form.Type == "tv" {
				typeStr = " movie  [tv]"
			}
			b.WriteString(fmt.Sprintf("%sType: %s\n", prefix, typeStr))
		case "name":
			b.WriteString(fmt.Sprintf("%sName: %s\n", prefix, form.Name))
		case "seasons":
			b.WriteString(fmt.Sprintf("%sSeasons: %s\n", prefix, form.Seasons))
			b.WriteString(mutedItemStyle.Render("        (e.g., '1-5' or '1,2,3')"))
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")

	if form.err != "" {
		b.WriteString(errorStyle.Render(form.err))
		b.WriteString("\n\n")
	}

	b.WriteString(helpStyle.Render("[Enter] Create  [Tab] Next field  [Esc] Cancel"))

	return b.String()
}

// handleNewItemKey handles key presses in the new item form
func (a *App) handleNewItemKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	form := a.newItemForm
	fields := form.fields()

	switch msg.String() {
	case "tab", "down":
		form.focusIndex = (form.focusIndex + 1) % len(fields)
		return a, nil

	case "shift+tab", "up":
		form.focusIndex--
		if form.focusIndex < 0 {
			form.focusIndex = len(fields) - 1
		}
		return a, nil

	case "left", "right":
		if fields[form.focusIndex] == "type" {
			if form.Type == "movie" {
				form.Type = "tv"
			} else {
				form.Type = "movie"
			}
		}
		return a, nil

	case "enter":
		if err := form.Validate(); err != "" {
			form.err = err
			return a, nil
		}
		return a, a.createNewItem()

	case "backspace":
		field := fields[form.focusIndex]
		switch field {
		case "name":
			if len(form.Name) > 0 {
				form.Name = form.Name[:len(form.Name)-1]
			}
		case "seasons":
			if len(form.Seasons) > 0 {
				form.Seasons = form.Seasons[:len(form.Seasons)-1]
			}
		}
		return a, nil

	case "esc":
		a.currentView = ViewItemList
		a.newItemForm = nil
		return a, nil

	default:
		if len(msg.String()) == 1 {
			field := fields[form.focusIndex]
			char := msg.String()
			switch field {
			case "name":
				form.Name += char
			case "seasons":
				// Allow digits, comma, dash
				if (char >= "0" && char <= "9") || char == "," || char == "-" {
					form.Seasons += char
				}
			}
		}
		return a, nil
	}
}

// itemCreatedMsg is sent when item creation completes
type itemCreatedMsg struct {
	item *model.MediaItem
	err  error
}

// createNewItem creates a new item in the database
func (a *App) createNewItem() tea.Cmd {
	return func() tea.Msg {
		form := a.newItemForm
		ctx := context.Background()

		safeName := strings.ReplaceAll(form.Name, " ", "_")

		item := &model.MediaItem{
			Type:       model.MediaType(form.Type),
			Name:       form.Name,
			SafeName:   safeName,
			ItemStatus: model.ItemStatusNotStarted,
		}

		// For movies, set initial stage
		if form.Type == "movie" {
			item.CurrentStage = model.StageRip
			item.StageStatus = model.StatusPending
		}

		if err := a.repo.CreateMediaItem(ctx, item); err != nil {
			return itemCreatedMsg{err: err}
		}

		// For TV shows, create seasons
		if form.Type == "tv" {
			seasons, _ := parseSeasons(form.Seasons)
			for _, num := range seasons {
				season := &model.Season{
					ItemID:       item.ID,
					Number:       num,
					CurrentStage: model.StageRip,
					StageStatus:  model.StatusPending,
				}
				if err := a.repo.CreateSeason(ctx, season); err != nil {
					return itemCreatedMsg{err: fmt.Errorf("failed to create season %d: %w", num, err)}
				}
			}
		}

		return itemCreatedMsg{item: item}
	}
}
