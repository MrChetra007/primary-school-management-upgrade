-- ============================================================
-- MIGRATION: schema(2) → schema(3)
-- Run this on your existing database to apply changes
-- Safe to run on a live Supabase project
-- ============================================================


-- ============================================================
-- 1. NEW ENUM: user_status
-- ============================================================

do $$ begin
  create type user_status as enum ('active', 'inactive');
exception
  when duplicate_object then null;
end $$;


-- ============================================================
-- 2. ADD COLUMN: users.status
-- ============================================================

alter table users
  add column if not exists status user_status not null default 'active';


-- ============================================================
-- DONE
-- ============================================================
-- Summary of changes applied:
--   • Added enum type: user_status ('active', 'inactive')
--   • Added column: users.status (user_status, default 'active')
--   • Added comment block about manage-user Edge Function
--     (no SQL changes needed for the comment section)
-- ============================================================
