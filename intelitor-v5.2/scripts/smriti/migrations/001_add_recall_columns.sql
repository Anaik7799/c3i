-- Migration: Add Recall Features (Vectors + SRS)
-- Date: 2026-01-13
-- Author: SMRITI Cybernetic Architect

-- 1. Add Vector Embedding Column (BLOB for raw float32 array)
ALTER TABLE holons ADD COLUMN vector_embedding BLOB;

-- 2. Add Spaced Repetition System (SRS) Columns
ALTER TABLE holons ADD COLUMN srs_next_review TEXT;
ALTER TABLE holons ADD COLUMN srs_interval INTEGER DEFAULT 0;
ALTER TABLE holons ADD COLUMN srs_ease_factor REAL DEFAULT 2.5;
ALTER TABLE holons ADD COLUMN srs_repetitions INTEGER DEFAULT 0;

-- 3. Create Index for SRS Queries
CREATE INDEX idx_holons_srs_next_review ON holons(srs_next_review);
