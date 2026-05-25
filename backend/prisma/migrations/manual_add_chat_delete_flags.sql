-- Add soft-delete flags to ChatMessage.
-- Run this once in Supabase SQL Editor before deploying the new backend.
-- Safe to run multiple times — each ADD COLUMN IF NOT EXISTS is idempotent.

ALTER TABLE "ChatMessage"
  ADD COLUMN IF NOT EXISTS "deletedForAll"   BOOLEAN   NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS "deletedForAllAt" TIMESTAMP,
  ADD COLUMN IF NOT EXISTS "hiddenForUser"   BOOLEAN   NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS "hiddenForLawyer" BOOLEAN   NOT NULL DEFAULT FALSE;
