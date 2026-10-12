-- =====================================================================
-- Phase 2 tests — read/write split + enrollment-based cap (migration_v14)
-- =====================================================================
-- Run on staging after migration_v14_plan_limits_read_write.sql.
-- Read the result grid: every row must show PASS.
-- The DO block at the bottom RAISES on a critical failure.
-- =====================================================================

-- 1. helper functions exist -------------------------------------------
select 'school_is_writable() exists' as test,
       case when exists (
         select 1 from pg_proc where proname = 'school_is_writable'
       ) then 'PASS' else 'FAIL' end as result;

select 'plan_has_feature(text) exists' as test,
       case when exists (
         select 1 from pg_proc
         where proname = 'plan_has_feature'
           and pg_get_function_identity_arguments(oid) = 'text'
       ) then 'PASS' else 'FAIL' end as result;

select 'school_active() still exists' as test,
       case when exists (
         select 1 from pg_proc where proname = 'school_active'
       ) then 'PASS' else 'FAIL' end as result;

-- 2. grace period ------------------------------------------------------
select 'schools.grace_period_days exists (default 7)' as test,
       case when exists (
         select 1 from information_schema.columns
         where table_name = 'schools' and column_name = 'grace_period_days'
           and column_default like '%7%'
       ) then 'PASS' else 'FAIL' end as result;

-- 3. core tables: split read vs write, no combined "manage" policy -----
select 'core admin tables have read + write policies (no manage)' as test,
       case when not exists (
         select 1 from pg_policies
         where tablename in ('students','scores','attendances','classes',
                             'subjects','academic_years')
           and policyname like '%: admin manage own school'
       )
       and (
         select count(distinct tablename) from pg_policies
         where tablename in ('students','scores','attendances','classes',
                             'subjects','academic_years')
           and policyname like '%: admin read own school'
       ) = 6
       and (
         select count(distinct tablename) from pg_policies
         where tablename in ('students','scores','attendances','classes',
                             'subjects','academic_years')
           and policyname like '%: admin write own school'
       ) = 6
       then 'PASS' else 'FAIL' end as result;

-- read policy must NOT reference school_active/is_writable
select 'admin read policies are not subscription-gated' as test,
       case when not exists (
         select 1 from pg_policies
         where policyname like '%: admin read own school'
           and (coalesce(qual,'') ilike '%school_active%'
                or coalesce(qual,'') ilike '%school_is_writable%')
       ) then 'PASS' else 'FAIL' end as result;

-- write policy must reference school_is_writable
select 'admin write policies are writable-gated' as test,
       case when not exists (
         select 1 from pg_policies
         where policyname like '%: admin write own school'
           and coalesce(qual,'') not ilike '%school_is_writable%'
       ) then 'PASS' else 'FAIL' end as result;

-- 4. teacher student-scoped policies split -----------------------------
select 'teacher tables have read + write policies (no manage)' as test,
       case when not exists (
         select 1 from pg_policies
         where tablename in ('student_health','attendances','scores')
           and policyname like '%: teacher manage own class'
       )
       and (
         select count(distinct tablename) from pg_policies
         where tablename in ('student_health','attendances','scores')
           and policyname like '%: teacher read own class'
       ) = 3
       and (
         select count(distinct tablename) from pg_policies
         where tablename in ('student_health','attendances','scores')
           and policyname like '%: teacher write own class'
       ) = 3
       then 'PASS' else 'FAIL' end as result;

-- 5. fee tables split --------------------------------------------------
select 'fee tables have read + write policies' as test,
       case when (
         select count(distinct tablename) from pg_policies
         where tablename in ('fee_structures','student_fees','fee_payments')
           and policyname like '%: admin read own school'
       ) = 3
       and (
         select count(distinct tablename) from pg_policies
         where tablename in ('fee_structures','student_fees','fee_payments')
           and policyname like '%: admin write own school'
       ) = 3
       then 'PASS' else 'FAIL' end as result;

-- 6. pro modules split (role-qualified names) --------------------------
select 'pro modules have role-qualified read + write policies' as test,
       case when exists (
         select 1 from pg_policies
         where tablename = 'books' and policyname = 'books: admin read own school'
       )
       and exists (
         select 1 from pg_policies
         where tablename = 'books' and policyname = 'books: admin write own school'
       )
       and exists (
         select 1 from pg_policies
         where tablename = 'books' and policyname = 'books: librarian read own school'
       )
       and exists (
         select 1 from pg_policies
         where tablename = 'inventory_items'
           and policyname = 'inventory_items: admin write own school'
       )
       then 'PASS' else 'FAIL' end as result;

-- 7. report links split ------------------------------------------------
select 'report_links has open read + guarded write' as test,
       case when exists (
         select 1 from pg_policies
         where tablename = 'report_links'
           and policyname = 'report_links: teacher read own class'
           and coalesce(qual,'') not ilike '%school_is_writable%'
       )
       and exists (
         select 1 from pg_policies
         where tablename = 'report_links'
           and policyname = 'report_links: teacher write own class'
           and coalesce(qual,'') ilike '%school_is_writable%'
       )
       then 'PASS' else 'FAIL' end as result;

-- 8. enrollment cap trigger --------------------------------------------
select 'on_enrollment_check_plan_limit trigger exists' as test,
       case when exists (
         select 1 from pg_trigger
         where tgname = 'on_enrollment_check_plan_limit'
           and not tgisinternal
       ) then 'PASS' else 'FAIL' end as result;

select 'legacy on_student_insert_check_limit trigger removed' as test,
       case when not exists (
         select 1 from pg_trigger
         where tgname = 'on_student_insert_check_limit' and not tgisinternal
       ) then 'PASS' else 'FAIL' end as result;

-- 9. bulk-op helpers ---------------------------------------------------
select 'school_student_usage() returns (used, max_students)' as test,
       case when (
         select pg_get_function_result(oid) like '%integer, max_students integer%'
         from pg_proc where proname = 'school_student_usage'
       ) then 'PASS' else 'FAIL' end as result;

select 'check_rollup_capacity(uuid,uuid) exists' as test,
       case when exists (
         select 1 from pg_proc
         where proname = 'check_rollup_capacity'
           and pg_get_function_identity_arguments(oid) = 'uuid, uuid'
       ) then 'PASS' else 'FAIL' end as result;


-- =====================================================================
-- Critical assertions (raise to abort the run)
-- =====================================================================
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'school_is_writable') then
    raise exception 'Phase 2 FAIL: school_is_writable() missing';
  end if;

  if not exists (select 1 from pg_proc where proname = 'plan_has_feature') then
    raise exception 'Phase 2 FAIL: plan_has_feature() missing';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'on_enrollment_check_plan_limit' and not tgisinternal
  ) then
    raise exception 'Phase 2 FAIL: enrollment cap trigger missing';
  end if;

  if exists (
    select 1 from pg_policies
    where tablename = 'students' and policyname = 'students: admin manage own school'
  ) then
    raise exception 'Phase 2 FAIL: students still has combined manage policy';
  end if;

  raise notice 'Phase 2 critical assertions passed.';
end $$;


-- =====================================================================
-- Behaviour tests (run manually as table owner — RLS bypassed)
-- =====================================================================
-- Cap boundaries (p_max from plans.max_students, Basic = 200):
--   1. Seed a school on the Basic plan with 199 active enrollments.
--   2. Insert the 200th active enrollment  → expect SUCCESS.
--   3. Insert the 201st active enrollment  → expect check_violation.
--   4. Insert a 2nd active enrollment for an already-counted student
--      → expect SUCCESS (distinct students, not rows).
--   5. Update an enrollment status active → withdrawn, then insert a new
--      active enrollment → expect SUCCESS (slot freed).
--
-- Read/write split (as an admin of an EXPIRED school via PostgREST):
--   - select * from students limit 1;        → expect rows (read open)
--   - insert/update/delete on students;      → expect RLS denial
--   - select * from fee_payments;            → expect rows (read open)
--   - insert into fee_structures ...;        → expect RLS denial
-- =====================================================================
