-- ============================================================
-- Jerry App — Add binary license storage to lawyer_profiles
-- Run in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Add BYTEA column for storing license image directly in the database.
-- license_data  : the raw binary bytes of the image (stored as base64 by PostgREST)
-- license_mime  : MIME type so we know how to render it (image/jpeg, image/png, etc.)

ALTER TABLE public.lawyer_profiles
  ADD COLUMN IF NOT EXISTS license_data      BYTEA,
  ADD COLUMN IF NOT EXISTS license_mime      TEXT;

-- The existing license_url column (Supabase Storage path) is no longer used.
-- You can leave it or drop it:
-- ALTER TABLE public.lawyer_profiles DROP COLUMN IF EXISTS license_url;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'lawyer_profiles'
ORDER BY ordinal_position;
