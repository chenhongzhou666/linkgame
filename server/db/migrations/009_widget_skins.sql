-- Migration 009: Widget skins support
-- Add widget_skins column to store purchased skin IDs as JSON array
-- Add active_skin_id column for the currently selected skin

ALTER TABLE users ADD COLUMN widget_skins TEXT NOT NULL DEFAULT '["default"]';
ALTER TABLE users ADD COLUMN active_skin_id TEXT NOT NULL DEFAULT 'default';
