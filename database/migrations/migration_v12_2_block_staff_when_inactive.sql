-- =====================================================================
-- Migration v12.2 — Extend the paywall to staff (teacher + librarian)
-- =====================================================================
-- Run AFTER migration_v12_saas.sql (and v12.1).
--
-- v12 only re-gated the "<table>: admin manage own school" core policies,
-- so a teacher/librarian on an unpaid or expired school could still read
-- and write students, attendance, scores, books, etc. This closes that gap
-- by recreating every staff policy with the same `school_active()` guard
-- used for admins. Library-related staff policies additionally require
-- `has_feature('library')` (Pro).
--
-- The combined teacher+admin policies (report_links, report_messages) are
-- re-gated here too, which also closes an admin hole in v12.
--
-- Anon parent-portal policies are intentionally left untouched.
-- =====================================================================


-- =====================================================================
-- 1. Teacher "manage own class" on every student-scoped table
--    (identical USING/WITH CHECK shape for all of them)
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'student_health',
    'student_checkups',
    'student_growth',
    'student_vaccinations',
    'student_sick_days',
    'attendances',
    'scores'
  ]
  loop
    execute format('drop policy if exists %I on public.%I',
                   t || ': teacher manage own class', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using ('
      ||   'get_user_role() = %L and school_id = get_user_school_id() and school_active() '
      ||   'and student_id in ('
      ||     'select s.id from students s join classes c on c.id = s.class_id '
      ||     'where c.teacher_id = (select id from teachers where user_id = auth.uid())'
      ||   ')'
      || ') '
      || 'with check ('
      ||   'get_user_role() = %L and school_id = get_user_school_id() and school_active() '
      ||   'and student_id in ('
      ||     'select s.id from students s join classes c on c.id = s.class_id '
      ||     'where c.teacher_id = (select id from teachers where user_id = auth.uid())'
      ||   ')'
      || ')',
      t || ': teacher manage own class', t, 'teacher', 'teacher'
    );
  end loop;
end $$;


-- =====================================================================
-- 2. Explicit staff policies
-- =====================================================================

-- subjects: teacher read own school
drop policy if exists "subjects: teacher read own school" on subjects;
create policy "subjects: teacher read own school"
  on subjects for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id()
         and school_active());

-- classes: teacher read own
drop policy if exists "classes: teacher read own" on classes;
create policy "classes: teacher read own"
  on classes for select to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    school_active() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- class_subjects: teacher read own school
drop policy if exists "class_subjects: teacher read own school" on class_subjects;
create policy "class_subjects: teacher read own school"
  on class_subjects for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id()
         and school_active());

-- class_subjects: librarian read own school (library is Pro)
drop policy if exists "class_subjects: librarian read own school" on class_subjects;
create policy "class_subjects: librarian read own school"
  on class_subjects for select to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

-- students: teacher manage own class
drop policy if exists "students: teacher manage own class" on students;
create policy "students: teacher manage own class"
  on students for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    school_active() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    school_active() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

-- students: librarian read own school (library is Pro)
drop policy if exists "students: librarian read own school" on students;
create policy "students: librarian read own school"
  on students for select to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

-- academic_years: staff read own school
drop policy if exists "academic_years: staff read own school" on academic_years;
create policy "academic_years: staff read own school"
  on academic_years for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id()
         and school_active());

-- school_holidays: staff read own school
drop policy if exists "school_holidays: staff read own school" on school_holidays;
create policy "school_holidays: staff read own school"
  on school_holidays for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id()
         and school_active());

-- teacher_attendances: teacher read self
drop policy if exists "teacher_attendances: teacher read self" on teacher_attendances;
create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (
    school_id = get_user_school_id() and
    school_active() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- books: teacher read own school (library is Pro)
drop policy if exists "books: teacher read own school" on books;
create policy "books: teacher read own school"
  on books for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

-- report_links: teacher manage own class (teacher + admin)
drop policy if exists "report_links: teacher manage own class" on report_links;
create policy "report_links: teacher manage own class"
  on report_links for all to authenticated
  using (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id() and
    school_active()
  )
  with check (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id() and
    school_active()
  );

-- report_messages: teacher manage (teacher + admin)
drop policy if exists "report_messages: teacher manage" on report_messages;
create policy "report_messages: teacher manage"
  on report_messages for all to authenticated
  using (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id() and
    school_active()
  )
  with check (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id() and
    school_active()
  );


-- =====================================================================
-- VERIFY (run manually while logged in as a teacher of an unpaid school)
-- =====================================================================
-- select count(*) from students;   -- expect 0 / permission denied
-- select count(*) from scores;     -- expect 0
-- select school_active();          -- expect false
-- =====================================================================
