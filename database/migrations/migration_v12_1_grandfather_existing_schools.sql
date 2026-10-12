-- ============================================================
-- Migration v12.1 — Grandfather existing schools
-- ============================================================
-- Run ONCE, right after migration_v12_saas.sql.
--
-- v12 introduces hard-blocking: a school with plan_expires_at = null is
-- treated as "never paid" and its admin is pushed to the billing page
-- (RLS `school_active()` also blocks core data access).
--
-- That is correct for schools created AFTER billing goes live, but it would
-- instantly lock out every school that already existed before rollout.
-- This statement grandfathers those schools by giving each one 12 months of
-- service from the moment the migration runs.
--
-- New schools created later still start with plan_expires_at = null and are
-- blocked until their first payment (Option A), since this migration does not
-- run again.
-- ============================================================

update schools
set plan_expires_at = now() + interval '12 months'
where plan_expires_at is null;

-- Verify: every pre-existing school should now have a future expiry.
-- select id, name_khmer, plan, plan_expires_at from schools order by created_at;
