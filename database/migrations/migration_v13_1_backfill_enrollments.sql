-- =====================================================================
-- Migration v13.1 — Backfill student_enrollments  (RUN ONLY AFTER APPROVAL)
-- =====================================================================
-- DATA MIGRATION — does not change the schema.
--
-- Copies every current `students.class_id` into an active
-- `student_enrollments` row so existing students become enrolments.
--
-- Safe / idempotent:
--   * only inserts students that have a class_id
--   * only inserts rows that do not already have an enrollment for that class
--   * running it twice creates no duplicates
--
-- It does NOT delete students.class_id — the legacy column keeps working
-- while Phase 2/3 progressively move to enrolments.
--
-- Run AFTER migration_v13_dynamic_structure.sql.
-- =====================================================================

insert into student_enrollments (school_id, student_id, class_id, start_date, status)
select s.school_id,
       s.id,
       s.class_id,
       coalesce(s.created_at::date, current_date),
       'active'::enrollment_status
from students s
where s.class_id is not null
  and not exists (
    select 1
    from student_enrollments e
    where e.student_id = s.id
      and e.class_id = s.class_id
      and e.status = 'active'
  );

-- Verify:
--   select count(*) from students where class_id is not null;          -- expected
--   select count(*) from student_enrollments where status = 'active';  -- should match
