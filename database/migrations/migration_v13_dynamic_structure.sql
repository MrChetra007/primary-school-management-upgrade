-- =====================================================================
-- Migration v13 — Dynamic structure (multi school-type, enrollments)
-- =====================================================================
-- Phase 1 of the SaaS roadmap (docs/prompts/dynamic_fee_classname.md).
--
-- Turns the primary-school-only assumptions into a configurable structure
-- so the same app serves PRIMARY, ENGLISH and COMPUTER schools:
--   * schools.school_type  → drives default labels / fee cycle / scoring.
--   * classes.scoring_mode → 'subject_scores' (existing) or 'simple_result'.
--   * classes schedule/room/start/end → generic term/course support.
--   * student_enrollments  → a student can be enrolled in several classes.
--   * school-type aware promotion / completion.
--
-- Run AFTER schema_v11.sql + migration_v12_saas.sql.
-- Non-destructive: only ADD columns / tables / functions.
-- The data backfill lives in migration_v13_1_backfill_enrollments.sql and
-- must be run only after approval.
-- =====================================================================


-- =====================================================================
-- 1. SCHOOL TYPE  (drives labels + defaults on the frontend)
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'school_type') then
    create type school_type as enum ('primary', 'english', 'computer');
  end if;
end $$;

alter table schools
  add column if not exists school_type school_type not null default 'primary';

-- how end-of-year progression behaves for this school
alter table schools
  add column if not exists rollup_mode text not null default 'grade_promotion'
    check (rollup_mode in ('grade_promotion', 'level_up', 'complete_only'));

-- free-form per-school progression config (e.g. {"grade_max": 6, "prefix": "ថ្នាក់ទី"})
alter table schools
  add column if not exists rollup_config jsonb not null default '{}'::jsonb;


-- =====================================================================
-- 2. CLASSES  — scoring mode + generic term/course fields
-- =====================================================================
-- scoring_mode:
--   subject_scores → the existing monthly / semester subject score system.
--   simple_result  → level/grade + pass/fail + certificate (courses).
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'scoring_mode') then
    create type scoring_mode as enum ('subject_scores', 'simple_result');
  end if;
end $$;

alter table classes
  add column if not exists scoring_mode scoring_mode not null default 'subject_scores',
  add column if not exists start_date    date,
  add column if not exists end_date      date,
  add column if not exists schedule      jsonb,   -- { "days": ["mon","wed"], "start": "17:00", "end": "18:30" }
  add column if not exists room          text;

create index if not exists idx_classes_scoring_mode
  on classes (school_id, scoring_mode);


-- =====================================================================
-- 3. STUDENT ENROLLMENTS
-- =====================================================================
-- One row per student per class-enrolment. Students may have several
-- active enrolments at once (e.g. English + Computer) and may join or
-- withdraw mid-term. `students.class_id` stays for backward compatibility
-- during the transition (Phase 2/3 will read from here).
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'enrollment_status') then
    create type enrollment_status as enum ('active', 'completed', 'withdrawn');
  end if;
end $$;

create table if not exists student_enrollments (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id  uuid not null references students(id) on delete cascade,
  class_id    uuid not null references classes(id) on delete cascade,
  start_date  date not null default current_date,
  end_date    date,
  status      enrollment_status not null default 'active',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- a student can only be actively enrolled once in the same class
create unique index if not exists uq_student_active_enrollment
  on student_enrollments (student_id, class_id)
  where status = 'active';

create index if not exists idx_enrollments_school
  on student_enrollments (school_id, status);
create index if not exists idx_enrollments_student
  on student_enrollments (student_id);
create index if not exists idx_enrollments_class
  on student_enrollments (class_id);

-- updated_at maintenance
create or replace function touch_enrollment_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists on_enrollment_touch on student_enrollments;
create trigger on_enrollment_touch
  before update on student_enrollments
  for each row execute procedure touch_enrollment_updated_at();


-- =====================================================================
-- 4. RLS — student_enrollments
-- =====================================================================

alter table student_enrollments enable row level security;

-- super admin full access
drop policy if exists "student_enrollments: super_admin full" on student_enrollments;
create policy "student_enrollments: super_admin full"
  on student_enrollments for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- admin manages the school's enrolments
drop policy if exists "student_enrollments: admin manage own school" on student_enrollments;
create policy "student_enrollments: admin manage own school"
  on student_enrollments for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id() and school_active())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id() and school_active());

-- staff (teacher / librarian) read-only, same school
drop policy if exists "student_enrollments: staff read own school" on student_enrollments;
create policy "student_enrollments: staff read own school"
  on student_enrollments for select to authenticated
  using (get_user_role() in ('teacher', 'librarian')
         and school_id = get_user_school_id() and school_active());


-- =====================================================================
-- 5. GENERIC PROMOTION / COMPLETION
-- =====================================================================
-- perform_student_rollup now branches on the school's rollup_mode:
--   grade_promotion → legacy primary behaviour (grade N → N+1, grade 6 graduates)
--   level_up        → same class name continues into the new year
--   complete_only   → everything is marked graduated (course finished)
-- The legacy branch is unchanged so existing primary schools behave exactly
-- as before. Non-primary schools never touch the Khmer grade parser.
-- =====================================================================

create or replace function perform_student_rollup(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb as $$
declare
  v_school_id    uuid := get_user_school_id();
  v_school_type  school_type;
  v_rollup_mode  text;
  v_grade        int;
  v_old_classes  uuid[];
  v_new_classes  uuid[];
  v_old_count    int;
  v_new_count    int;
  v_copied       int;
  v_total_copied int := 0;
  v_graduated    int := 0;
  v_summary      jsonb := '[]'::jsonb;
  v_i            int;
  v_new_name     text;
  v_new_id       uuid;
  v_old_name     text;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if p_old_year_id = p_new_year_id then
    raise exception 'Old and new academic year must be different';
  end if;

  select school_type, rollup_mode
    into v_school_type, v_rollup_mode
  from schools where id = v_school_id;

  -- ================================================================
  -- Generic (non primary grade) progression
  -- ================================================================
  if v_rollup_mode <> 'grade_promotion' then
    -- complete_only: mark every active student of the old year as finished
    if v_rollup_mode = 'complete_only' then
      insert into students (school_id, real_id, full_name, gender, dob, address, phone_number,
                            father_name, father_job, mother_name, mother_job, class_id,
                            is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
      select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number,
             s.father_name, s.father_job, s.mother_name, s.mother_job, null,
             s.is_scholarship, s.is_disability, true, p_new_year_id, now()
      from students s
      where s.academic_year_id = p_old_year_id
        and s.school_id = v_school_id
        and s.is_graduated = false;
      get diagnostics v_graduated = row_count;

      -- close the matching enrolments
      update student_enrollments e
      set status = 'completed', end_date = coalesce(e.end_date, current_date)
      from classes c
      where e.class_id = c.id
        and c.academic_year_id = p_old_year_id
        and c.school_id = v_school_id
        and e.status = 'active';

      return jsonb_build_object(
        'success', true,
        'mode', v_rollup_mode,
        'total_promoted', 0,
        'total_graduated', v_graduated,
        'details', v_summary
      );
    end if;

    -- level_up: same class name continues in the new year
    for v_old_name, v_old_classes in
      select class_name, array_agg(id order by class_name)
      from classes
      where academic_year_id = p_old_year_id and school_id = v_school_id
      group by class_name
    loop
      -- find / create the same-named class in the new year
      select id into v_new_id
      from classes
      where academic_year_id = p_new_year_id and school_id = v_school_id
        and class_name = v_old_name
      limit 1;

      if v_new_id is null then
        insert into classes (class_name, turn, academic_year_id, school_id)
        values (v_old_name, 'morning', p_new_year_id, v_school_id)
        returning id into v_new_id;
      end if;

      v_copied := 0;
      insert into students (school_id, real_id, full_name, gender, dob, address, phone_number,
                            father_name, father_job, mother_name, mother_job, class_id,
                            is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
      select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number,
             s.father_name, s.father_job, s.mother_name, s.mother_job, v_new_id,
             s.is_scholarship, s.is_disability, false, p_new_year_id, now()
      from students s
      where s.class_id = any(v_old_classes)
        and s.is_graduated = false and s.school_id = v_school_id;
      get diagnostics v_copied = row_count;

      v_total_copied := v_total_copied + v_copied;
      v_summary := v_summary || jsonb_build_object(
        'grade', v_old_name, 'action', 'level_up', 'students_moved', v_copied
      );
    end loop;

    return jsonb_build_object(
      'success', true,
      'mode', v_rollup_mode,
      'total_promoted', v_total_copied,
      'total_graduated', 0,
      'details', v_summary
    );
  end if;

  -- ================================================================
  -- Legacy primary grade promotion (UNCHANGED behaviour)
  -- ================================================================
  for v_grade in 1..5 loop
    select array_agg(id order by class_name) into v_old_classes
    from classes
    where academic_year_id = p_old_year_id and school_id = v_school_id
      and extract_grade_from_class_name(class_name) = v_grade;

    v_old_count := coalesce(array_length(v_old_classes, 1), 0);
    if v_old_count = 0 then continue; end if;

    select array_agg(id order by class_name) into v_new_classes
    from classes
    where academic_year_id = p_new_year_id and school_id = v_school_id
      and extract_grade_from_class_name(class_name) = v_grade + 1;

    v_new_count := coalesce(array_length(v_new_classes, 1), 0);

    if v_new_count = 0 then
      v_new_classes := '{}'::uuid[];
      for v_i in 1..v_old_count loop
        select class_name into v_old_name from classes where id = v_old_classes[v_i];
        v_new_name := generate_next_grade_class_name(v_old_name);
        if v_new_name is not null then
          insert into classes (class_name, turn, academic_year_id, school_id)
          values (v_new_name, 'morning', p_new_year_id, v_school_id)
          returning id into v_new_id;
          v_new_classes := array_append(v_new_classes, v_new_id);
        end if;
      end loop;
      v_new_count := coalesce(array_length(v_new_classes, 1), 0);
    end if;

    if v_new_count = 0 then
      v_summary := v_summary || jsonb_build_object(
        'grade', v_grade, 'action', 'skipped', 'students_affected', 0
      );
      continue;
    end if;

    v_copied := 0;

    if v_new_count = v_old_count then
      for v_i in 1..v_old_count loop
        insert into students (school_id, real_id, full_name, gender, dob, address, phone_number, father_name, father_job, mother_name, mother_job, class_id, is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
        select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number, s.father_name, s.father_job, s.mother_name, s.mother_job, v_new_classes[v_i], s.is_scholarship, s.is_disability, false, p_new_year_id, now()
        from students s
        where s.class_id = v_old_classes[v_i]
          and s.is_graduated = false and s.school_id = v_school_id;
        get diagnostics v_copied = row_count;
      end loop;
    else
      insert into students (school_id, real_id, full_name, gender, dob, address, phone_number, father_name, father_job, mother_name, mother_job, class_id, is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
      select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number, s.father_name, s.father_job, s.mother_name, s.mother_job, v_new_classes[1], s.is_scholarship, s.is_disability, false, p_new_year_id, now()
      from students s
      where s.class_id = any(v_old_classes)
        and s.is_graduated = false and s.school_id = v_school_id;
      get diagnostics v_copied = row_count;
    end if;

    v_total_copied := v_total_copied + v_copied;
    v_summary := v_summary || jsonb_build_object(
      'grade', v_grade,
      'action', case when v_new_count = v_old_count then 'paired' else 'merged' end,
      'students_moved', v_copied
    );
  end loop;

  select array_agg(id) into v_old_classes
  from classes
  where academic_year_id = p_old_year_id and school_id = v_school_id
    and extract_grade_from_class_name(class_name) = 6;

  if v_old_classes is not null then
    insert into students (school_id, real_id, full_name, gender, dob, address, phone_number, father_name, father_job, mother_name, mother_job, class_id, is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
    select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number, s.father_name, s.father_job, s.mother_name, s.mother_job, null, s.is_scholarship, s.is_disability, true, p_new_year_id, now()
    from students s
    where s.class_id = any(v_old_classes)
      and s.is_graduated = false and s.school_id = v_school_id;
    get diagnostics v_graduated = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', 'grade_promotion',
    'total_promoted', v_total_copied,
    'total_graduated', v_graduated,
    'details', v_summary
  );
end;
$$ language plpgsql security definer;


-- =====================================================================
-- VERIFY (run manually)
-- =====================================================================
-- select id, name_khmer, school_type, rollup_mode from schools;
-- select class_name, scoring_mode, room, schedule from classes limit 5;
-- select student_id, class_id, status from student_enrollments limit 5;
-- -- as a primary admin: select perform_student_rollup('<old>','<new>');
-- =====================================================================
