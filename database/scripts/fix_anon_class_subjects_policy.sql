-- ============================================================
-- Fix: Missing anon RLS policy for class_subjects
-- 
-- Problem: subjects anon policy joins class_subjects but that
-- table had no anon policy, so RLS blocked the subquery → all
-- subjects returned 0 results for anon users (parent portal).
--
-- Run this in your Supabase SQL editor.
-- ============================================================

create policy "class_subjects: anon read via report link"
  on class_subjects for select to anon
  using (
    class_id in (select class_id from report_links)
  );
