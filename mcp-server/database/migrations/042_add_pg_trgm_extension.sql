-- Migration 042: Add pg_trgm Extension for Text Similarity
-- 
-- The decision and context search handlers use PostgreSQL's similarity() function
-- to find duplicate decisions and similar contexts. This function is provided by
-- the pg_trgm (trigram) extension, which must be created in the database.
--
-- This migration creates the extension if it doesn't already exist.

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Verify the extension is installed by checking if similarity() function exists
-- This will fail if pg_trgm installation fails, preventing silent errors
SELECT similarity('test', 'test') AS test_similarity;
