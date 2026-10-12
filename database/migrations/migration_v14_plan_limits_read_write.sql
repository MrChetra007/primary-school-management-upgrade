-- =====================================================================
-- Migration v14 — Phase 2: read/write split + enrollment-based student cap
-- =====================================================================
-- Run AFTER migration_v13_dynamic_structure.sql (and v12/v12.1/v12.2).
--
-- Two changes from the original v12 paywall, per the SaaS roadmap spec:
--
-- 1. READS STAY OPEN, WRITES ARE BLOCKED.
--    v12/v12.2 put `school_active()` in BOTH `using` and `with check`, so
--    an admin/staff of an expired school could not even READ their data.
--    The spec wants the opposite: when a subscription lapses the admin can
--    still log in, open Billing, renew, and EXPORT students/scores/payments.
--    So every tenant policy is split into:
--       • "<t>: ... read ..."  → SELECT only, no subscription guard
--       • "<t>: ... write ..." → INSERT/UPDATE/DELETE, guarded by
--                                     school_is_writable()
--    Feature (plan) gating is preserved for reads via plan_has_feature(),
--    which ignores the subscription state.
--
-- 2. STUDENT CAP = DISTINCT STUDENTS WITH AN ACTIVE ENROLLMENT.
--    Enforced by a BEFORE INSERT/UPDATE trigger on student_enrollments so
--    the 200th distinct active student is allowed and the 201st rejected.
--    A transitional fallback keeps legacy schools (not yet backfilled into
--    student_enrollments) working until migration_v13_1 is run.
--
-- `school_active()` now also honours a default 7-day grace period that is
-- configurable per school (schools.grace_period_days).
-- =====================================================================


-- =====================================================================
-- 1. GRACE PERIOD  (default 7 days, configurable per school)
-- =====================================================================

alter table schools
  add column if not exists grace_period_days integer not null default 7
    check (grace_period_days >= 0);


-- =====================================================================
-- 2. HELPER FUNCTIONS
-- =====================================================================
-- school_active()       → subscription paid (plan_expires_at + grace).
-- school_is_writable()  → alias used in WRITE policies (reads stay open).
-- plan_has_feature(f)   → the school's PLAN enables the module, regardless
--                         of subscription state (so reads survive expiry).
-- has_feature(f)        → plan_has_feature(f) AND school_active() (writes).
-- =====================================================================

create or replace function school_active()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (
      select
        s.status = 'active'
        and (
          (
            s.plan_expires_at is not null
            and now() < s.plan_expires_at
                       + make_interval(days => coalesce(s.grace_period_days, 7))
          )
          or
          (s.grace_period_ends_at is not null and now() < s.grace_period_ends_at)
        )
      from schools s
      where s.id = get_user_school_id()
    ),
    false
  );
$$;

create or replace function school_is_writable()
returns boolean
language sql
security definer
stable
as $$
  select school_active();
$$;

create or replace function plan_has_feature(p_feature text)
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (
      select coalesce((p.features ->> p_feature)::boolean, false)
      from schools s
      join plans p on p.id = s.plan
      where s.id = get_user_school_id()
    ),
    false
  );
$$;

create or replace function has_feature(p_feature text)
returns boolean
language sql
security definer
stable
as $$
  select school_active() and plan_has_feature(p_feature);
$$;


-- =====================================================================
-- 3. CORE ADMIN TABLES — split read (open) vs write (guarded)
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'users', 'school_settings', 'school_information', 'academic_years',
    'subjects', 'teachers', 'classes', 'class_subjects', 'students',
    'student_health', 'student_checkups', 'student_growth',
    'student_vaccinations', 'student_sick_days', 'attendances', 'scores',
    'teacher_attendances', 'school_holidays', 'semester_config'
  ]
  loop
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin manage own school', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin read own school', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin write own school', t);

    execute format(
      'create policy %I on public.%I for select to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id())',
      t || ': admin read own school', t, 'admin'
    );

    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable()) '
      || 'with check (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable())',
      t || ': admin write own school', t, 'admin', 'admin'
    );
  end loop;
end $$;


-- =====================================================================
-- 4. TEACHER "manage own class" — split read vs write
--    (7 student-scoped tables, identical shape)
-- =====================================================================

do $$
declare
  t text;
  v_pred text :=
    'student_id in ('
    || 'select s.id from students s join classes c on c.id = s.class_id '
    || 'where c.teacher_id = (select id from teachers where user_id = auth.uid())'
    || ')';
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
    execute format('drop policy if exists %I on public.%I',
                   t || ': teacher read own class', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': teacher write own class', t);

    execute format(
      'create policy %I on public.%I for select to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and %s)',
      t || ': teacher read own class', t, 'teacher', v_pred
    );

    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable() and %s) '
      || 'with check (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable() and %s)',
      t || ': teacher write own class', t, 'teacher', v_pred, 'teacher', v_pred
    );
  end loop;
end $$;


-- =====================================================================
-- 5. STUDENTS — split the teacher "manage own class" for-all policy
-- =====================================================================

drop policy if exists "students: teacher manage own class" on students;
drop policy if exists "students: teacher read own class" on students;
drop policy if exists "students: teacher write own class" on students;

create policy "students: teacher read own class"
  on students for select to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "students: teacher write own class"
  on students for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    school_is_writable() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    school_is_writable() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );


-- =====================================================================
-- 6. EXPLICIT STAFF READ POLICIES — drop the subscription guard
--    (reads stay open; library reads keep the plan feature check)
-- =====================================================================

drop policy if exists "subjects: teacher read own school" on subjects;
create policy "subjects: teacher read own school"
  on subjects for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id());

drop policy if exists "classes: teacher read own" on classes;
create policy "classes: teacher read own"
  on classes for select to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

drop policy if exists "class_subjects: teacher read own school" on class_subjects;
create policy "class_subjects: teacher read own school"
  on class_subjects for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id());

drop policy if exists "class_subjects: librarian read own school" on class_subjects;
create policy "class_subjects: librarian read own school"
  on class_subjects for select to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and plan_has_feature('library'));

drop policy if exists "students: librarian read own school" on students;
create policy "students: librarian read own school"
  on students for select to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and plan_has_feature('library'));

drop policy if exists "academic_years: staff read own school" on academic_years;
create policy "academic_years: staff read own school"
  on academic_years for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id());

drop policy if exists "school_holidays: staff read own school" on school_holidays;
create policy "school_holidays: staff read own school"
  on school_holidays for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id());

drop policy if exists "teacher_attendances: teacher read self" on teacher_attendances;
create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

drop policy if exists "books: teacher read own school" on books;
create policy "books: teacher read own school"
  on books for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id()
         and plan_has_feature('library'));


-- =====================================================================
-- 7. REPORT LINKS / MESSAGES — split read vs write (teacher + admin)
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array['report_links', 'report_messages']
  loop
    execute format('drop policy if exists %I on public.%I',
                   t || ': teacher manage own class', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': teacher read own class', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': teacher write own class', t);
  end loop;
end $$;

create policy "report_links: teacher read own class"
  on report_links for select to authenticated
  using (get_user_role() in ('teacher', 'admin') and school_id = get_user_school_id());

create policy "report_links: teacher write own class"
  on report_links for all to authenticated
  using (get_user_role() in ('teacher', 'admin') and school_id = get_user_school_id()
         and school_is_writable())
  with check (get_user_role() in ('teacher', 'admin') and school_id = get_user_school_id()
         and school_is_writable());

create policy "report_messages: teacher read own class"
  on report_messages for select to authenticated
  using (get_user_role() in ('teacher', 'admin') and school_id = get_user_school_id());

create policy "report_messages: teacher write own class"
  on report_messages for all to authenticated
  using (get_user_role() in ('teacher', 'admin') and school_id = get_user_school_id()
         and school_is_writable())
  with check (get_user_role() in ('teacher', 'admin') and school_id = get_user_school_id()
         and school_is_writable());


-- =====================================================================
-- 8. FEE TABLES — read open (feature-gated), write guarded
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array['fee_structures', 'student_fees', 'fee_payments']
  loop
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin manage own school', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin read own school', t);
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin write own school', t);

    execute format(
      'create policy %I on public.%I for select to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and plan_has_feature(''fees''))',
      t || ': admin read own school', t, 'admin'
    );

    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable() and plan_has_feature(''fees'')) '
      || 'with check (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable() and plan_has_feature(''fees''))',
      t || ': admin write own school', t, 'admin', 'admin'
    );
  end loop;
end $$;


-- =====================================================================
-- 9. PRO MODULES — read requires the plan feature, write also requires
--    an active subscription
-- =====================================================================

do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('books',               'admin',    'library'),
      ('books',               'librarian','library'),
      ('book_borrows',        'admin',    'library'),
      ('book_borrows',        'librarian','library'),
      ('budget_transactions', 'admin',    'budget'),
      ('inventory_items',     'admin',    'inventory')
    ) as v(tbl, rrole, feat)
  loop
    execute format('drop policy if exists %I on public.%I',
                   r.tbl || ': ' || r.rrole || ' manage own school', r.tbl);
    execute format('drop policy if exists %I on public.%I',
                   r.tbl || ': ' || r.rrole || ' read own school', r.tbl);
    execute format('drop policy if exists %I on public.%I',
                   r.tbl || ': ' || r.rrole || ' write own school', r.tbl);

    execute format(
      'create policy %I on public.%I for select to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and plan_has_feature(%L))',
      r.tbl || ': ' || r.rrole || ' read own school', r.tbl, r.rrole, r.feat
    );

    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable() and plan_has_feature(%L)) '
      || 'with check (get_user_role() = %L and school_id = get_user_school_id() '
      ||        'and school_is_writable() and plan_has_feature(%L))',
      r.tbl || ': ' || r.rrole || ' write own school', r.tbl,
      r.rrole, r.feat, r.rrole, r.feat
    );
  end loop;
end $$;


-- =====================================================================
-- 10. STUDENT CAP — distinct students with an ACTIVE enrollment
-- =====================================================================
-- BEFORE INSERT/UPDATE on student_enrollments:
--   • only 'active' rows count
--   • a student with several active enrollments counts once
--   • the 200th distinct active student is allowed, the 201st rejected
-- Transitional fallback: for schools that still have NO enrollment rows
-- (migration_v13_1 not yet applied), fall back to counting current
-- non-graduated students with a class, so the cap keeps working.
-- =====================================================================

create or replace function enforce_student_plan_limit()
returns trigger
language plpgsql
security definer
as $$
declare
  v_max   integer;
  v_plan  text;
  v_count integer;
begin
  -- only ACTIVE enrollments count toward the cap
  if new.status is distinct from 'active' then
    return new;
  end if;

  select s.plan, p.max_students
    into v_plan, v_max
  from schools s
  join plans p on p.id = s.plan
  where s.id = new.school_id;

  -- unlimited plan (Pro) → allow
  if v_max is null then
    return new;
  end if;

  select count(distinct sid)
    into v_count
  from (
    -- primary definition: distinct students with an active enrollment
    select e.student_id as sid
    from student_enrollments e
    where e.school_id = new.school_id
      and e.status = 'active'
      and e.student_id <> new.student_id

    union

    -- transitional fallback for schools not yet backfilled into enrollments
    select s.id
    from students s
    where s.school_id = new.school_id
      and s.is_graduated = false
      and s.class_id is not null
      and s.id <> new.student_id
      and not exists (
        select 1 from student_enrollments e2 where e2.school_id = new.school_id
      )
  ) x;

  if v_count >= v_max then
    raise exception
      'Plan limit reached: the % plan allows up to % active students. Upgrade to Pro for unlimited students.',
      initcap(v_plan), v_max
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

-- new enforcement point (enrollments)
drop trigger if exists on_enrollment_check_plan_limit on student_enrollments;
create trigger on_enrollment_check_plan_limit
  before insert or update of status, class_id on student_enrollments
  for each row execute procedure enforce_student_plan_limit();

-- legacy student-insert trigger is replaced by the enrollment trigger above.
-- (student creation flows should also create an enrollment row; see Phase 1.)
drop trigger if exists on_student_insert_check_limit on students;


-- =====================================================================
-- 11. BULK-OP CAP HELPERS  (pre-flight checks for import / rollup)
-- =====================================================================
-- school_student_usage()  → current active-student count + plan cap, so
--                           the UI can pre-check before a bulk insert
--                           instead of failing mid-statement.
-- check_rollup_capacity() → projected active students after a promotion,
--                           used to block a rollup that would exceed the cap
--                           before perform_student_rollup mutates anything.
-- =====================================================================

create or replace function school_student_usage()
returns table(used integer, max_students integer)
language sql
security definer
stable
as $$
  select
    coalesce((
      select count(distinct x.sid)
      from (
        select e.student_id as sid
        from student_enrollments e
        where e.school_id = get_user_school_id() and e.status = 'active'
        union
        select s.id as sid
        from students s
        where s.school_id = get_user_school_id()
          and s.is_graduated = false
          and s.class_id is not null
          and not exists (
            select 1 from student_enrollments e2 where e2.school_id = get_user_school_id()
          )
      ) x
    ), 0)::int as used,
    (
      select p.max_students
      from schools s
      join plans p on p.id = s.plan
      where s.id = get_user_school_id()
    )::int as max_students;
$$;

create or replace function check_rollup_capacity(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb
language plpgsql
security definer
stable
as $$
declare
  v_school_id uuid := get_user_school_id();
  v_mode      text;
  v_max       int;
  v_plan      text;
  v_projected int;
begin
  select rollup_mode into v_mode from schools where id = v_school_id;

  select s.plan, p.max_students
    into v_plan, v_max
  from schools s
  join plans p on p.id = s.plan
  where s.id = v_school_id;

  -- complete_only graduates everyone → no new active students
  if v_mode = 'complete_only' then
    return jsonb_build_object('allowed', true, 'projected', 0,
                              'max_students', v_max, 'plan', v_plan);
  end if;

  select count(*)
    into v_projected
  from students s
  where s.academic_year_id = p_old_year_id
    and s.school_id = v_school_id
    and s.is_graduated = false
    and (
      v_mode <> 'grade_promotion'
      or coalesce(extract_grade_from_class_name(
           (select c.class_name from classes c where c.id = s.class_id)
         ), 0) <> 6
    );

  return jsonb_build_object(
    'allowed', (v_max is null or v_projected <= v_max),
    'projected', v_projected,
    'max_students', v_max,
    'plan', v_plan
  );
end;
$$;


-- =====================================================================
-- VERIFY (run manually)
-- =====================================================================
-- select * from school_student_usage();
-- select check_rollup_capacity('<old>', '<new>');
-- select school_active(), school_is_writable(), plan_has_feature('fees');
-- select policyname from pg_policies
--   where tablename = 'students' order by policyname;
-- =====================================================================
