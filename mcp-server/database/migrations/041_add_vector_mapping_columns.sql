-- Migration 041: Add Vector Mapping Columns for Dimensionality Reduction
--
-- Purpose: Add support for 2D/3D vector visualization of high-dimensional embeddings
-- The code in context.ts and dimensionality-reduction.ts expects these columns
-- for mapping 1536-dimensional vectors to lower dimensions for UI visualization
--
-- Date: 2025-12-18

BEGIN;

-- Add vector mapping columns to contexts table
ALTER TABLE contexts
ADD COLUMN IF NOT EXISTS vector_x FLOAT,
ADD COLUMN IF NOT EXISTS vector_y FLOAT,
ADD COLUMN IF NOT EXISTS vector_z FLOAT,
ADD COLUMN IF NOT EXISTS mapping_method VARCHAR(50) DEFAULT 'tsne',
ADD COLUMN IF NOT EXISTS mapped_at TIMESTAMP WITH TIME ZONE;

-- Add indexes for efficient filtering
CREATE INDEX IF NOT EXISTS idx_contexts_vector_x ON contexts(vector_x) WHERE vector_x IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contexts_vector_y ON contexts(vector_y) WHERE vector_y IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contexts_vector_z ON contexts(vector_z) WHERE vector_z IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contexts_mapping_method ON contexts(mapping_method);

-- Add comments explaining the columns
COMMENT ON COLUMN contexts.vector_x IS 'First dimension of reduced vector representation (e.g., t-SNE, UMAP)';
COMMENT ON COLUMN contexts.vector_y IS 'Second dimension of reduced vector representation (e.g., t-SNE, UMAP)';
COMMENT ON COLUMN contexts.vector_z IS 'Third dimension of reduced vector representation (for 3D visualization)';
COMMENT ON COLUMN contexts.mapping_method IS 'Method used for dimensionality reduction (e.g., tsne, umap, pca)';
COMMENT ON COLUMN contexts.mapped_at IS 'Timestamp when vectors were last mapped to lower dimensions';

COMMIT;

-- Verification queries
SELECT 'Migration 041 completed successfully' as status;
