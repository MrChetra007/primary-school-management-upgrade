-- =====================================================================
-- Phase 1 tests — dynamic structure (migration_v13)
-- =====================================================================
-- Run on staging after migration_v13_dynamic_structure.sql.
-- Read the result grid: every row must show PASS.
-- The DO block at the bottom also RAISES on a critical failure so the
-- script stops loudly.
-- =====================================================================

-- 1. school_type column + default -------------------------------------
select 'schools.school_type exists & default primary' as test,
       case
         when exists (
           select 1 from information_schema.columns
           where table_name = 'schools' and column_name = 'school_type'
             and column_default like '%primary%'
         ) then 'PASS' else 'FAIL'
       end as result;

-- 2. school_type enum values ------------------------------------------
select 'school_type enum = primary/english/computer' as test,
       case
         when array(
           select unnest(enum_range(null::school_type))::text
         ) = array['primary','english','computer'] then 'PASS' else 'FAIL'
       end as result;

-- 3. schools.rollup_mode -------------------------------------------------
select 'schools.rollup_mode exists (default grade_promotion)' as test,
       case
         when exists (
           select 1 from information_schema.columns
           where table_name = 'schools' and column_name = 'rollup_mode'
             and column_default like '%grade_promotion%'
         ) then 'PASS' else 'FAIL'
       end as result;

-- 4. classes.scoring_mode + generic fields ------------------------------
select 'classes has scoring_mode/start_date/end_date/schedule/room' as test,
       case
         when (
           select count(*) from information_schema.columns
           where table_name = 'classes'
             and column_name in ('scoring_mode','start_date','end_date','schedule','room')
         ) = 5 then 'PASS' else 'FAIL'
       end as result;

select 'classes.scoring_mode default subject_scores' as test,
       case
         when exists (
           select 1 from information_schema.columns
           where table_name = 'classes' and column_name = 'scoring_mode'
             and column_default like '%subject_scores%'
         ) then 'PASS' else 'FAIL'
       end as result;

-- 5. student_enrollments table ------------------------------------------
select 'student_enrollments has all columns' as test,
       case
         when (
           select count(*) from information_schema.columns
           where table_name = 'student_enrollments'
             and column_name in ('id','school_id','student_id','class_id',
                                 'start_date','end_date','status','created_at','updated_at')
         ) = 9 then 'PASS' else 'FAIL'
       end as result;

select 'student_enrollments.enrollment_status = active/completed/withdrawn' as test,
       case
         when array(
           select unnest(enum_range(null::enrollment_status))::text
         ) = array['active','completed','withdrawn'] then 'PASS' else 'FAIL'
       end as result;

-- 6. unique active enrollment index -------------------------------------
select 'uq_student_active_enrollment partial unique index exists' as test,
       case
         when exists (
           select 1 from pg_indexes
           where tablename = 'student_enrollments'
             and indexname = 'uq_student_active_enrollment'
         ) then 'PASS' else 'FAIL'
       end as result;

-- 7. RLS enabled + 4 policies -------------------------------------------
select 'student_enrollments RLS enabled' as test,
       case
         when exists (
           select 1 from pg_tables
           where tablename = 'student_enrollments' and rowsecurity = true
         ) then 'PASS' else 'FAIL'
       end as result;

select 'student_enrollments has 3 policies' as test,
       case
         when (
           select count(*) from pg_policies where tablename = 'student_enrollments'
         ) = 3 then 'PASS' else 'FAIL'
       end as result;

-- 8. rollup function signature ------------------------------------------
select 'perform_student_rollup(uuid,uuid) returns jsonb' as test,
       case
         when exists (
           select 1 from pg_proc
           where proname = 'perform_student_rollup'
             and pg_get_function_identity_arguments(oid) = 'uuid, uuid'
         ) then 'PASS' else 'FAIL'
       end as result;


-- =====================================================================
-- Critical assertions (raise to abort the run)
-- =====================================================================
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'schools' and column_name = 'school_type'
  ) then
    raise exception 'Phase 1 FAIL: schools.school_type missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_name = 'classes' and column_name = 'scoring_mode'
  ) then
    raise exception 'Phase 1 FAIL: classes.scoring_mode missing';
  end if;

  if not exists (
    select 1 from pg_tables where tablename = 'student_enrollments'
  ) then
    raise exception 'Phase 1 FAIL: student_enrollments table missing';
  end if;

  raise notice 'Phase 1 critical assertions passed.';
end $$;


-- =====================================================================
-- Behaviour tests (need a school context; run manually in the SQL editor
-- as the table owner — RLS is bypassed there).
-- =====================================================================
-- Setup:
--   insert into schools (name_khmer, school_code, school_type)
--   values ('សាលាបញ្ចូលកម្មវិធីកុំព្យូទ័រ','TEST-COMP','computer')
--   returning id;
--
-- Assert defaults were applied:
--   select school_type, rollup_mode from schools where school_code = 'TEST-COMP';
--   -- expect: computer | grade_promotion
--
-- Assert one-active-enrollment-per-class rule:
--   -- insert an active enrollment twice for the same student+class → 2nd must fail
--
-- Cleanup:
--   delete from schools where school_code = 'TEST-COMP';
-- =====================================================================
