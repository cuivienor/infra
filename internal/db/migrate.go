package db

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

// MigrateToItemCentric migrates existing TV show data to the new schema.
// This consolidates multiple media_items rows (one per season) into
// a single item with multiple seasons.
func (r *SQLiteRepository) MigrateToItemCentric(ctx context.Context) error {
	// Find TV shows that need migration (have season in media_items but no seasons table entries)
	query := `
		SELECT DISTINCT safe_name
		FROM media_items
		WHERE type = 'tv' AND season IS NOT NULL
		AND NOT EXISTS (
			SELECT 1 FROM seasons s
			JOIN media_items m2 ON s.item_id = m2.id
			WHERE m2.safe_name = media_items.safe_name
		)
	`

	rows, err := r.db.db.QueryContext(ctx, query)
	if err != nil {
		return fmt.Errorf("failed to find TV shows to migrate: %w", err)
	}
	defer rows.Close()

	var showsToMigrate []string
	for rows.Next() {
		var safeName string
		if err := rows.Scan(&safeName); err != nil {
			return fmt.Errorf("failed to scan safe_name: %w", err)
		}
		showsToMigrate = append(showsToMigrate, safeName)
	}

	for _, safeName := range showsToMigrate {
		if err := r.migrateShow(ctx, safeName); err != nil {
			return fmt.Errorf("failed to migrate show %s: %w", safeName, err)
		}
	}

	return nil
}

func (r *SQLiteRepository) migrateShow(ctx context.Context, safeName string) error {
	// Get all media_items for this show
	query := `
		SELECT id, name, season, created_at
		FROM media_items
		WHERE safe_name = ? AND type = 'tv'
		ORDER BY season ASC
	`

	rows, err := r.db.db.QueryContext(ctx, query, safeName)
	if err != nil {
		return err
	}
	defer rows.Close()

	var items []struct {
		id        int64
		name      string
		season    int
		createdAt string
	}

	for rows.Next() {
		var item struct {
			id        int64
			name      string
			season    int
			createdAt string
		}
		var seasonNull sql.NullInt64
		if err := rows.Scan(&item.id, &item.name, &seasonNull, &item.createdAt); err != nil {
			return err
		}
		if seasonNull.Valid {
			item.season = int(seasonNull.Int64)
		}
		items = append(items, item)
	}

	if len(items) == 0 {
		return nil
	}

	// Use the first item as the "parent" item
	parentID := items[0].id

	// Create seasons for each item
	for _, item := range items {
		// Get latest job to determine stage/status
		var stage, status string
		err := r.db.db.QueryRowContext(ctx, `
			SELECT stage, status FROM jobs
			WHERE media_item_id = ?
			ORDER BY created_at DESC LIMIT 1
		`, item.id).Scan(&stage, &status)

		if err == sql.ErrNoRows {
			stage = "rip"
			status = "pending"
		} else if err != nil {
			return err
		}

		now := time.Now().UTC().Format(time.RFC3339)
		_, err = r.db.db.ExecContext(ctx, `
			INSERT INTO seasons (item_id, number, current_stage, stage_status, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?, ?)
		`, parentID, item.season, stage, status, item.createdAt, now)
		if err != nil {
			return fmt.Errorf("failed to create season: %w", err)
		}

		// Update jobs to reference parent item
		if item.id != parentID {
			_, err = r.db.db.ExecContext(ctx, `
				UPDATE jobs SET media_item_id = ? WHERE media_item_id = ?
			`, parentID, item.id)
			if err != nil {
				return fmt.Errorf("failed to update jobs: %w", err)
			}

			// Delete the old media_item
			_, err = r.db.db.ExecContext(ctx, `
				DELETE FROM media_items WHERE id = ?
			`, item.id)
			if err != nil {
				return fmt.Errorf("failed to delete old media item: %w", err)
			}
		}
	}

	// Update parent item to remove season field and set status
	_, err = r.db.db.ExecContext(ctx, `
		UPDATE media_items SET season = NULL, status = 'active' WHERE id = ?
	`, parentID)
	if err != nil {
		return fmt.Errorf("failed to update parent item: %w", err)
	}

	return nil
}
