-- ============================================================
-- DOWNGRADE: v9 → v8
-- downgrade_v9_v8.sql
-- ============================================================
--
-- Reverses migration_v8_v9.sql exactly:
--   1. Drops report_messages table (and its data — irreversible)
--   2. Drops report_links table (and its data — irreversible)
--   3. Drops tightened anon policies on students/scores/attendances
--   4. Restores original open anon policies (using true)
--   5. Restores anon policies on health/growth/vaccinations/sick_days
--   6. Drops report-voices storage bucket policies + bucket
--
-- ⚠️  WARNING: All report_links and report_messages data will be
--     permanently deleted. Voice files in report-voices bucket
--     must be deleted manually from Supabase Storage dashboard
--     before dropping the bucket (or they will remain orphaned).
--
-- ============================================================

begin;


-- ============================================================
-- STEP 1: DROP report_messages (child first — FK dependency)
-- ============================================================

drop table if exists report_messages cascade;


-- ============================================================
-- STEP 2: DROP report_links
-- ============================================================

drop table if exists report_links cascade;


-- ============================================================
-- STEP 3: DROP TIGHTENED ANON POLICIES
-- ============================================================

drop policy if exists "students: anon read via report link"    on students;
drop policy if exists "attendances: anon read via report link" on attendances;
drop policy if exists "scores: anon read via report link"      on scores;


-- ============================================================
-- STEP 4: RESTORE ORIGINAL OPEN ANON POLICIES (v8)
-- ============================================================

create policy "students: anon read for parent"
  on students for select to anon
  using (true);

create policy "attendances: anon read for parent"
  on attendances for select to anon
  using (true);

create policy "scores: anon read for parent"
  on scores for select to anon
  using (true);


-- ============================================================
-- STEP 5: RESTORE ANON POLICIES ON HEALTH TABLES (v8)
-- ============================================================

create policy "student_health: anon read for parent"
  on student_health for select to anon
  using (true);

create policy "student_checkups: anon read for parent"
  on student_checkups for select to anon
  using (true);

create policy "student_growth: anon read for parent"
  on student_growth for select to anon
  using (true);

create policy "student_vaccinations: anon read for parent"
  on student_vaccinations for select to anon
  using (true);

create policy "student_sick_days: anon read for parent"
  on student_sick_days for select to anon
  using (true);


-- ============================================================
-- STEP 6: DROP report-voices STORAGE BUCKET POLICIES + BUCKET
--
-- ⚠️  Delete all files in the report-voices bucket manually
--     from the Supabase Storage dashboard BEFORE running this,
--     otherwise the bucket delete will fail (non-empty bucket).
-- ============================================================

drop policy if exists "report-voices: teacher full"       on storage.objects;
drop policy if exists "report-voices: anon parent upload" on storage.objects;
drop policy if exists "report-voices: anon parent update" on storage.objects;
drop policy if exists "report-voices: public read"        on storage.objects;

delete from storage.buckets where id = 'report-voices';


-- ============================================================
-- DONE
-- ============================================================

commit;

-- Post-downgrade checklist:
--   [ ] Verify report_links table is gone
--   [ ] Verify report_messages table is gone
--   [ ] Verify open anon policies restored on students/scores/attendances
--   [ ] Verify anon policies restored on student_health/growth/vaccinations/sick_days
--   [ ] Verify report-voices bucket is removed from Supabase Storage
--   [ ] Manually remove any orphaned .webm files from Storage dashboard
--   [ ] Test: parent search by name + DOB works again (if old frontend restored)
