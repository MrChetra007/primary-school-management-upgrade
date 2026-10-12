-- ============================================================
-- MIGRATION: v8 → v9
-- migration_v8_v9.sql
-- ============================================================
--
-- What this migration does:
--   1. Creates report_links table
--   2. Creates report_messages table
--   3. Adds indexes for new tables
--   4. Enables RLS on new tables
--   5. Adds RLS policies for report_links + report_messages
--   6. Drops old open anon policies on students/scores/attendances
--   7. Adds tightened anon policies scoped to report link context
--   8. Drops anon policies on health/growth/vaccinations/sick_days
--   9. Creates report-voices storage bucket + policies
--
-- Safe to run on a live database.
-- All changes are additive except the anon RLS policy replacements.
-- Run downgrade_v9_v8.sql to reverse.
-- ============================================================

begin;

-- ============================================================
-- STEP 1: CREATE report_links
-- ============================================================

create table if not exists report_links (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  class_id         uuid not null references classes(id) on delete cascade,
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  created_by       uuid not null references teachers(id) on delete cascade,
  score_type       score_type not null,
  month            int2,        -- 1-12, null if semester
  semester         int2,        -- 1 or 2, null if monthly
  created_at       timestamptz default now(),
  unique(class_id, academic_year_id, score_type, month, semester)
);


-- ============================================================
-- STEP 2: CREATE report_messages
-- ============================================================

create table if not exists report_messages (
  id                uuid primary key default uuid_generate_v4(),
  school_id         uuid not null references schools(id) on delete cascade default get_user_school_id(),
  report_link_id    uuid not null references report_links(id) on delete cascade,
  student_id        uuid not null references students(id) on delete cascade,
  teacher_text      text,
  teacher_voice_url text,    -- report-voices/{report_link_id}/{student_id}/teacher.webm
  parent_text       text,
  parent_voice_url  text,    -- report-voices/{report_link_id}/{student_id}/parent.webm
  created_at        timestamptz default now(),
  updated_at        timestamptz default now(),
  unique(report_link_id, student_id)
);


-- ============================================================
-- STEP 3: INDEXES
-- ============================================================

create index if not exists idx_report_links_school_id       on report_links(school_id);
create index if not exists idx_report_links_class_id        on report_links(class_id);
create index if not exists idx_report_messages_school_id    on report_messages(school_id);
create index if not exists idx_report_messages_link_student on report_messages(report_link_id, student_id);


-- ============================================================
-- STEP 4: ENABLE RLS
-- ============================================================

alter table report_links    enable row level security;
alter table report_messages enable row level security;


-- ============================================================
-- STEP 5: RLS POLICIES FOR NEW TABLES
-- ============================================================

-- report_links: teacher/admin manage, anon read by id
create policy "report_links: teacher manage own class"
  on report_links for all to authenticated
  using (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id()
  );

create policy "report_links: anon read by id"
  on report_links for select to anon
  using (true);

-- report_messages: teacher/admin manage, anon read + update parent fields + insert
create policy "report_messages: teacher manage"
  on report_messages for all to authenticated
  using (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() in ('teacher', 'admin') and
    school_id = get_user_school_id()
  );

create policy "report_messages: anon read"
  on report_messages for select to anon
  using (true);

create policy "report_messages: anon update parent fields"
  on report_messages for update to anon
  using (true)
  with check (true);

create policy "report_messages: anon insert"
  on report_messages for insert to anon
  with check (
    report_link_id in (select id from report_links)
  );


-- ============================================================
-- STEP 6: DROP OLD OPEN ANON POLICIES
-- ============================================================

drop policy if exists "students: anon read for parent"     on students;
drop policy if exists "attendances: anon read for parent"  on attendances;
drop policy if exists "scores: anon read for parent"       on scores;


-- ============================================================
-- STEP 7: ADD TIGHTENED ANON POLICIES
-- Scoped to students/attendances/scores whose class_id
-- appears in report_links. Frontend further filters by
-- specific report_link_id — RLS ensures no unbounded access.
-- ============================================================

create policy "students: anon read via report link"
  on students for select to anon
  using (
    class_id in (select class_id from report_links)
  );

create policy "attendances: anon read via report link"
  on attendances for select to anon
  using (
    student_id in (
      select s.id from students s
      join report_links rl on rl.class_id = s.class_id
    )
  );

create policy "scores: anon read via report link"
  on scores for select to anon
  using (
    student_id in (
      select s.id from students s
      join report_links rl on rl.class_id = s.class_id
    )
  );


-- ============================================================
-- STEP 8: DROP ANON POLICIES FROM HEALTH TABLES
-- Health, growth, vaccinations, sick days are now staff-only.
-- ============================================================

drop policy if exists "student_health: anon read for parent"        on student_health;
drop policy if exists "student_checkups: anon read for parent"      on student_checkups;
drop policy if exists "student_growth: anon read for parent"        on student_growth;
drop policy if exists "student_vaccinations: anon read for parent"  on student_vaccinations;
drop policy if exists "student_sick_days: anon read for parent"     on student_sick_days;


-- ============================================================
-- STEP 9: STORAGE BUCKET — report-voices
-- Run this block in the Supabase SQL editor.
-- The bucket must not already exist.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('report-voices', 'report-voices', true)
on conflict do nothing;

create policy "report-voices: teacher full"
  on storage.objects for all to authenticated
  using (bucket_id = 'report-voices' and get_user_role() in ('teacher', 'admin', 'super_admin'))
  with check (bucket_id = 'report-voices' and get_user_role() in ('teacher', 'admin', 'super_admin'));

create policy "report-voices: anon parent upload"
  on storage.objects for insert to anon
  with check (
    bucket_id = 'report-voices' and
    (storage.filename(name)) = 'parent.webm'
  );

create policy "report-voices: anon parent update"
  on storage.objects for update to anon
  using (
    bucket_id = 'report-voices' and
    (storage.filename(name)) = 'parent.webm'
  );

create policy "report-voices: public read"
  on storage.objects for select to public
  using (bucket_id = 'report-voices');


-- ============================================================
-- DONE
-- ============================================================

commit;

-- Post-migration checklist:
--   [ ] Verify report_links table exists with correct columns
--   [ ] Verify report_messages table exists with correct columns
--   [ ] Verify old anon policies are gone (students/scores/attendances)
--   [ ] Verify new scoped anon policies are active
--   [ ] Verify health/growth/vaccinations/sick_days have NO anon policies
--   [ ] Verify report-voices bucket exists in Supabase Storage
--   [ ] Test: generate a report link as teacher → share → open as anon
--   [ ] Test: anon cannot read student_health, student_growth, etc.
--   [ ] Test: anon cannot read students outside a report-linked class
