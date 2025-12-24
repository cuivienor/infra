-- File: internal/db/migrations/002_item_centric.sql
-- Item-centric schema changes: adds status tracking at item/season level

-- Create seasons table for TV shows
CREATE TABLE IF NOT EXISTS seasons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
    number INTEGER NOT NULL,
    current_stage TEXT NOT NULL DEFAULT 'rip' CHECK (current_stage IN ('rip', 'organize', 'remux', 'transcode', 'publish')),
    stage_status TEXT NOT NULL DEFAULT 'pending' CHECK (stage_status IN ('pending', 'in_progress', 'completed', 'failed')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(item_id, number)
);

CREATE INDEX IF NOT EXISTS idx_seasons_item ON seasons(item_id);
CREATE INDEX IF NOT EXISTS idx_seasons_status ON seasons(stage_status);

-- Add new columns to media_items (only if they don't exist)
-- Note: SQLite doesn't support IF NOT EXISTS for ALTER TABLE ADD COLUMN
-- These will fail silently on re-run (handled by migration system)

-- Add status column for item-level status
-- Default 'active' means existing items are considered active
ALTER TABLE media_items ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('not_started', 'active', 'completed'));

-- Add current_stage for movies (TV uses seasons table)
ALTER TABLE media_items ADD COLUMN current_stage TEXT DEFAULT 'rip' CHECK (current_stage IN ('rip', 'organize', 'remux', 'transcode', 'publish'));

-- Add stage_status for movies (TV uses seasons table)
ALTER TABLE media_items ADD COLUMN stage_status TEXT DEFAULT 'pending' CHECK (stage_status IN ('pending', 'in_progress', 'completed', 'failed'));

-- Add season_id to jobs table (nullable - NULL for movies, set for TV)
ALTER TABLE jobs ADD COLUMN season_id INTEGER REFERENCES seasons(id) ON DELETE CASCADE;
