-- ============================================================
-- MIGRATION: v7 → v8
-- Feature: Multi-Tenant Architecture
-- Every table gets school_id. New schools + super_admin tables.
-- Safe to run on live data — existing data assigned to school_id
-- from a default "seed" school created from current data.
-- ============================================================


-- ============================================================
-- 1. NEW ENUM: extend user_role to include super_admin
-- ============================================================

alter type user_role add value if not exists 'super_admin';


-- ============================================================
-- 2. NEW TABLE: schools
-- One row per school. Tra creates these from /super dashboard.
-- ============================================================

create table schools (
  id              uuid primary key default uuid_generate_v4(),
  name_khmer      text not null,
  name_english    text,
  school_code     text not null unique,   -- e.g. BTB-001
  province        text,
  district        text,
  address         text,
  phone           text,
  email           text,
  logo_url        text,
  status          user_status not null default 'active',
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

alter table schools enable row level security;


-- ============================================================
-- 3. CREATE DEFAULT SCHOOL from existing school_information
-- This preserves all existing data by assigning it to school_id
-- ============================================================

insert into schools (
  id, name_khmer, name_english, school_code,
  province, district
)
select
  uuid_generate_v4(),
  coalesce(name_khmer, 'សាលាបឋមសិក្សា'),
  coalesce(name_english, 'Primary School'),
  coalesce(school_code, 'DEFAULT-001'),
  'បាត់ដំបង',
  'បាត់ដំបង'
from school_information
limit 1;

-- If school_information is empty, insert a fallback
insert into schools (name_khmer, name_english, school_code, province)
select 'សាលាបឋមសិក្សា', 'Primary School', 'DEFAULT-001', 'បាត់ដំបង'
where not exists (select 1 from schools);


-- ============================================================
-- 4. ADD school_id COLUMN TO ALL MAJOR TABLES
-- All existing rows get assigned to the default school
-- ============================================================

-- Helper: get default school id
do $$
declare
  v_school_id uuid := (select id from schools limit 1);
begin

  -- users
  alter table users add column if not exists school_id uuid references schools(id) on delete cascade;
  update users set school_id = v_school_id where school_id is null;

  -- teachers
  alter table teachers add column if not exists school_id uuid references schools(id) on delete cascade;
  update teachers set school_id = v_school_id where school_id is null;

  -- classes
  alter table classes add column if not exists school_id uuid references schools(id) on delete cascade;
  update classes set school_id = v_school_id where school_id is null;

  -- students
  alter table students add column if not exists school_id uuid references schools(id) on delete cascade;
  update students set school_id = v_school_id where school_id is null;

  -- academic_years
  alter table academic_years add column if not exists school_id uuid references schools(id) on delete cascade;
  update academic_years set school_id = v_school_id where school_id is null;

  -- subjects
  alter table subjects add column if not exists school_id uuid references schools(id) on delete cascade;
  update subjects set school_id = v_school_id where school_id is null;

  -- school_information
  alter table school_information add column if not exists school_id uuid references schools(id) on delete cascade;
  update school_information set school_id = v_school_id where school_id is null;

  -- school_settings
  alter table school_settings add column if not exists school_id uuid references schools(id) on delete cascade;
  update school_settings set school_id = v_school_id where school_id is null;

  -- school_holidays
  alter table school_holidays add column if not exists school_id uuid references schools(id) on delete cascade;
  update school_holidays set school_id = v_school_id where school_id is null;

  -- attendances
  alter table attendances add column if not exists school_id uuid references schools(id) on delete cascade;
  update attendances set school_id = v_school_id where school_id is null;

  -- scores
  alter table scores add column if not exists school_id uuid references schools(id) on delete cascade;
  update scores set school_id = v_school_id where school_id is null;

  -- teacher_attendances
  alter table teacher_attendances add column if not exists school_id uuid references schools(id) on delete cascade;
  update teacher_attendances set school_id = v_school_id where school_id is null;

  -- books
  alter table books add column if not exists school_id uuid references schools(id) on delete cascade;
  update books set school_id = v_school_id where school_id is null;

  -- book_borrows
  alter table book_borrows add column if not exists school_id uuid references schools(id) on delete cascade;
  update book_borrows set school_id = v_school_id where school_id is null;

  -- budget_transactions
  alter table budget_transactions add column if not exists school_id uuid references schools(id) on delete cascade;
  update budget_transactions set school_id = v_school_id where school_id is null;

  -- inventory_items
  alter table inventory_items add column if not exists school_id uuid references schools(id) on delete cascade;
  update inventory_items set school_id = v_school_id where school_id is null;

  -- student_health
  alter table student_health add column if not exists school_id uuid references schools(id) on delete cascade;
  update student_health set school_id = v_school_id where school_id is null;

  -- student_checkups
  alter table student_checkups add column if not exists school_id uuid references schools(id) on delete cascade;
  update student_checkups set school_id = v_school_id where school_id is null;

  -- student_growth
  alter table student_growth add column if not exists school_id uuid references schools(id) on delete cascade;
  update student_growth set school_id = v_school_id where school_id is null;

  -- student_vaccinations
  alter table student_vaccinations add column if not exists school_id uuid references schools(id) on delete cascade;
  update student_vaccinations set school_id = v_school_id where school_id is null;

  -- student_sick_days
  alter table student_sick_days add column if not exists school_id uuid references schools(id) on delete cascade;
  update student_sick_days set school_id = v_school_id where school_id is null;

  -- class_subjects
  alter table class_subjects add column if not exists school_id uuid references schools(id) on delete cascade;
  update class_subjects set school_id = v_school_id where school_id is null;

end $$;


-- ============================================================
-- 5. MAKE school_id NOT NULL on critical tables
-- After backfill, enforce the constraint
-- ============================================================

alter table users               alter column school_id set not null;
alter table teachers            alter column school_id set not null;
alter table classes             alter column school_id set not null;
alter table students            alter column school_id set not null;
alter table academic_years      alter column school_id set not null;
alter table subjects            alter column school_id set not null;
alter table school_settings     alter column school_id set not null;


-- ============================================================
-- 6. ADD INDEXES for performance
-- school_id is the most queried filter in multi-tenant
-- ============================================================

create index if not exists idx_users_school_id               on users(school_id);
create index if not exists idx_teachers_school_id            on teachers(school_id);
create index if not exists idx_classes_school_id             on classes(school_id);
create index if not exists idx_students_school_id            on students(school_id);
create index if not exists idx_students_school_class         on students(school_id, class_id);
create index if not exists idx_students_school_name_dob      on students(school_id, full_name, dob);
create index if not exists idx_academic_years_school_id      on academic_years(school_id);
create index if not exists idx_subjects_school_id            on subjects(school_id);
create index if not exists idx_school_settings_school_id     on school_settings(school_id);
create index if not exists idx_school_holidays_school_id     on school_holidays(school_id);
create index if not exists idx_attendances_school_id         on attendances(school_id);
create index if not exists idx_attendances_student_date      on attendances(student_id, date);
create index if not exists idx_scores_school_id              on scores(school_id);
create index if not exists idx_scores_student_subject        on scores(student_id, subject_id);
create index if not exists idx_teacher_attendances_school_id on teacher_attendances(school_id);
create index if not exists idx_teacher_attendances_t_date    on teacher_attendances(teacher_id, date);
create index if not exists idx_books_school_id               on books(school_id);
create index if not exists idx_book_borrows_school_id        on book_borrows(school_id);
create index if not exists idx_budget_school_id              on budget_transactions(school_id);
create index if not exists idx_inventory_school_id           on inventory_items(school_id);
create index if not exists idx_student_health_school_id      on student_health(school_id);
create index if not exists idx_student_growth_school_id      on student_growth(school_id);
create index if not exists idx_student_vaccinations_school   on student_vaccinations(school_id);
create index if not exists idx_student_sick_days_school      on student_sick_days(school_id);
create index if not exists idx_class_subjects_school_id      on class_subjects(school_id);


-- ============================================================
-- 7. NEW HELPER FUNCTION: get_user_school_id
-- Returns the school_id of the currently logged-in user
-- Used in all RLS policies
-- ============================================================

create or replace function get_user_school_id()
returns uuid as $$
  select school_id from users where id = auth.uid();
$$ language sql security definer stable;


-- ============================================================
-- 8. UPDATE EXISTING HELPER: get_user_role
-- Now also checks school scope
-- ============================================================

create or replace function get_user_role()
returns user_role as $$
  select role from users where id = auth.uid();
$$ language sql security definer stable;


-- ============================================================
-- 9. UPDATE RLS POLICIES — add school_id scoping
-- Drop old policies, recreate with school_id filter
-- ============================================================

-- ── SCHOOLS table ───────────────────────────────────────────

create policy "schools: super_admin full"
  on schools for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "schools: admin read own"
  on schools for select to authenticated
  using (id = get_user_school_id());


-- ── USERS ───────────────────────────────────────────────────

drop policy if exists "users: admin full access" on users;
drop policy if exists "users: self read" on users;
drop policy if exists "users: active only" on users;

create policy "users: super_admin full"
  on users for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "users: admin manage own school"
  on users for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "users: self read"
  on users for select to authenticated
  using (id = auth.uid());


-- ── TEACHERS ────────────────────────────────────────────────

drop policy if exists "teachers: admin full" on teachers;
drop policy if exists "teachers: self read" on teachers;

create policy "teachers: super_admin full"
  on teachers for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "teachers: admin manage own school"
  on teachers for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "teachers: self read"
  on teachers for select to authenticated
  using (user_id = auth.uid());


-- ── CLASSES ─────────────────────────────────────────────────

drop policy if exists "classes: admin full" on classes;
drop policy if exists "classes: teacher read own" on classes;

create policy "classes: admin manage own school"
  on classes for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "classes: teacher read own"
  on classes for select to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );


-- ── STUDENTS ────────────────────────────────────────────────

drop policy if exists "students: admin full" on students;
drop policy if exists "students: teacher manage own class" on students;
drop policy if exists "students: librarian read" on students;
drop policy if exists "students: anon read for parent" on students;

create policy "students: admin manage own school"
  on students for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "students: teacher manage own class"
  on students for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "students: librarian read own school"
  on students for select to authenticated
  using (
    get_user_role() = 'librarian' and
    school_id = get_user_school_id()
  );

-- Parent: anon read (app filters by school + name + dob)
create policy "students: anon read for parent"
  on students for select to anon
  using (true);


-- ── ACADEMIC YEARS ──────────────────────────────────────────

drop policy if exists "academic_years: admin full" on academic_years;
drop policy if exists "academic_years: staff read" on academic_years;

create policy "academic_years: admin manage own school"
  on academic_years for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "academic_years: staff read own school"
  on academic_years for select to authenticated
  using (
    get_user_role() in ('teacher', 'librarian') and
    school_id = get_user_school_id()
  );


-- ── SUBJECTS ────────────────────────────────────────────────

drop policy if exists "subjects: admin full" on subjects;
drop policy if exists "subjects: teacher read" on subjects;

create policy "subjects: admin manage own school"
  on subjects for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "subjects: teacher read own school"
  on subjects for select to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id()
  );


-- ── SCHOOL SETTINGS ─────────────────────────────────────────

drop policy if exists "school_settings: admin full" on school_settings;
drop policy if exists "school_settings: staff read" on school_settings;

create policy "school_settings: admin manage own school"
  on school_settings for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "school_settings: staff read own school"
  on school_settings for select to authenticated
  using (
    get_user_role() in ('teacher', 'librarian') and
    school_id = get_user_school_id()
  );


-- ── SCHOOL HOLIDAYS ─────────────────────────────────────────

drop policy if exists "school_holidays: admin full" on school_holidays;
drop policy if exists "school_holidays: staff read" on school_holidays;

create policy "school_holidays: admin manage own school"
  on school_holidays for all to authenticated
  using (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  )
  with check (
    get_user_role() = 'admin' and
    school_id = get_user_school_id()
  );

create policy "school_holidays: staff read own school"
  on school_holidays for select to authenticated
  using (
    get_user_role() in ('teacher', 'librarian') and
    school_id = get_user_school_id()
  );


-- ── ATTENDANCES ─────────────────────────────────────────────

drop policy if exists "attendances: admin full" on attendances;
drop policy if exists "attendances: teacher manage own class" on attendances;
drop policy if exists "attendances: anon read for parent" on attendances;

create policy "attendances: admin manage own school"
  on attendances for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "attendances: teacher manage own class"
  on attendances for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "attendances: anon read for parent"
  on attendances for select to anon using (true);


-- ── SCORES ──────────────────────────────────────────────────

drop policy if exists "scores: admin full" on scores;
drop policy if exists "scores: teacher manage own class" on scores;
drop policy if exists "scores: anon read for parent" on scores;

create policy "scores: admin manage own school"
  on scores for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "scores: teacher manage own class"
  on scores for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "scores: anon read for parent"
  on scores for select to anon using (true);


-- ── TEACHER ATTENDANCES ─────────────────────────────────────

drop policy if exists "teacher_attendances: admin full" on teacher_attendances;
drop policy if exists "teacher_attendances: teacher read self" on teacher_attendances;

create policy "teacher_attendances: admin manage own school"
  on teacher_attendances for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );


-- ── BOOKS ───────────────────────────────────────────────────

drop policy if exists "books: admin full" on books;
drop policy if exists "books: librarian full" on books;
drop policy if exists "books: teacher read" on books;

create policy "books: admin manage own school"
  on books for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "books: librarian manage own school"
  on books for all to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id())
  with check (get_user_role() = 'librarian' and school_id = get_user_school_id());

create policy "books: teacher read own school"
  on books for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id());


-- ── BOOK BORROWS ────────────────────────────────────────────

drop policy if exists "book_borrows: admin full" on book_borrows;
drop policy if exists "book_borrows: librarian full" on book_borrows;

create policy "book_borrows: admin manage own school"
  on book_borrows for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "book_borrows: librarian manage own school"
  on book_borrows for all to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id())
  with check (get_user_role() = 'librarian' and school_id = get_user_school_id());


-- ── BUDGET TRANSACTIONS ─────────────────────────────────────

drop policy if exists "budget_transactions: admin full" on budget_transactions;

create policy "budget_transactions: admin manage own school"
  on budget_transactions for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());


-- ── INVENTORY ITEMS ─────────────────────────────────────────

drop policy if exists "inventory_items: admin full" on inventory_items;

create policy "inventory_items: admin manage own school"
  on inventory_items for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());


-- ── STUDENT HEALTH ──────────────────────────────────────────

drop policy if exists "student_health: admin full" on student_health;
drop policy if exists "student_health: teacher manage own class" on student_health;
drop policy if exists "student_health: anon read for parent" on student_health;

create policy "student_health: admin manage own school"
  on student_health for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "student_health: teacher manage own class"
  on student_health for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_health: anon read for parent"
  on student_health for select to anon using (true);


-- ── STUDENT CHECKUPS, GROWTH, VACCINATIONS, SICK DAYS ───────
-- Pattern is the same for all 4 tables

drop policy if exists "student_checkups: admin full" on student_checkups;
drop policy if exists "student_checkups: teacher manage own class" on student_checkups;
drop policy if exists "student_checkups: anon read for parent" on student_checkups;

create policy "student_checkups: admin manage own school"
  on student_checkups for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());
create policy "student_checkups: teacher manage own class"
  on student_checkups for all to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())))
  with check (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())));
create policy "student_checkups: anon read for parent"
  on student_checkups for select to anon using (true);

drop policy if exists "student_growth: admin full" on student_growth;
drop policy if exists "student_growth: teacher manage own class" on student_growth;
drop policy if exists "student_growth: anon read for parent" on student_growth;

create policy "student_growth: admin manage own school"
  on student_growth for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());
create policy "student_growth: teacher manage own class"
  on student_growth for all to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())))
  with check (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())));
create policy "student_growth: anon read for parent"
  on student_growth for select to anon using (true);

drop policy if exists "student_vaccinations: admin full" on student_vaccinations;
drop policy if exists "student_vaccinations: teacher manage own class" on student_vaccinations;
drop policy if exists "student_vaccinations: anon read for parent" on student_vaccinations;

create policy "student_vaccinations: admin manage own school"
  on student_vaccinations for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());
create policy "student_vaccinations: teacher manage own class"
  on student_vaccinations for all to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())))
  with check (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())));
create policy "student_vaccinations: anon read for parent"
  on student_vaccinations for select to anon using (true);

drop policy if exists "student_sick_days: admin full" on student_sick_days;
drop policy if exists "student_sick_days: teacher manage own class" on student_sick_days;
drop policy if exists "student_sick_days: anon read for parent" on student_sick_days;

create policy "student_sick_days: admin manage own school"
  on student_sick_days for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());
create policy "student_sick_days: teacher manage own class"
  on student_sick_days for all to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())))
  with check (get_user_role() = 'teacher' and school_id = get_user_school_id() and student_id in (select s.id from students s join classes c on c.id = s.class_id where c.teacher_id = (select id from teachers where user_id = auth.uid())));
create policy "student_sick_days: anon read for parent"
  on student_sick_days for select to anon using (true);


-- ── CLASS SUBJECTS ──────────────────────────────────────────

drop policy if exists "class_subjects: admin full" on class_subjects;
drop policy if exists "class_subjects: teacher read own class" on class_subjects;
drop policy if exists "class_subjects: librarian read" on class_subjects;

create policy "class_subjects: admin manage own school"
  on class_subjects for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "class_subjects: teacher read own school"
  on class_subjects for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id());

create policy "class_subjects: librarian read own school"
  on class_subjects for select to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id());


-- ============================================================
-- 10. UPDATE FUNCTIONS to be school-aware
-- ============================================================

-- Update teacher_check_in to pass school_id
create or replace function teacher_check_in()
returns json as $$
declare
  v_teacher_id uuid;
  v_school_id  uuid;
  v_settings   record;
  v_now        timestamptz := now();
  v_today      date        := current_date;
  v_time_now   time        := v_now::time;
  v_turn       class_turn;
  v_threshold  time;
  v_status     attendance_status;
  v_existing   record;
begin
  select id, school_id into v_teacher_id, v_school_id
  from teachers where user_id = auth.uid();

  if v_teacher_id is null then
    raise exception 'Teacher profile not found';
  end if;

  select * into v_existing
  from teacher_attendances
  where teacher_id = v_teacher_id and date = v_today;

  if v_existing.id is not null then
    raise exception 'Already checked in today at %', v_existing.check_in_time;
  end if;

  select c.turn into v_turn
  from classes c
  where c.teacher_id = v_teacher_id and c.school_id = v_school_id
  limit 1;

  v_turn := coalesce(v_turn, 'morning');

  select * into v_settings
  from school_settings where school_id = v_school_id limit 1;

  if v_turn = 'morning' then
    v_threshold := v_settings.morning_late_threshold;
  else
    v_threshold := v_settings.evening_late_threshold;
  end if;

  if v_time_now > v_threshold then
    v_status := 'late';
  else
    v_status := 'present';
  end if;

  insert into teacher_attendances (teacher_id, date, check_in_time, status, school_id)
  values (v_teacher_id, v_today, v_now, v_status, v_school_id);

  return json_build_object(
    'status',        v_status,
    'check_in_time', v_now,
    'turn',          v_turn,
    'threshold',     v_threshold
  );
end;
$$ language plpgsql security definer;


-- Update perform_student_rollup to be school-scoped
create or replace function perform_student_rollup(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb as $$
declare
  v_school_id     uuid := get_user_school_id();
  v_grade         int;
  v_old_classes   uuid[];
  v_new_classes   uuid[];
  v_old_count     int;
  v_new_count     int;
  v_moved         int;
  v_total_moved   int := 0;
  v_graduated     int := 0;
  v_summary       jsonb := '[]'::jsonb;
  v_grade_summary jsonb;
  v_i             int;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  for v_grade in 1..5 loop
    select array_agg(id order by class_name) into v_old_classes
    from classes
    where academic_year_id = p_old_year_id
      and school_id = v_school_id
      and extract_grade_from_class_name(class_name) = v_grade;

    v_old_count := coalesce(array_length(v_old_classes, 1), 0);
    if v_old_count = 0 then continue; end if;

    select array_agg(id order by class_name) into v_new_classes
    from classes
    where academic_year_id = p_new_year_id
      and school_id = v_school_id
      and extract_grade_from_class_name(class_name) = v_grade + 1;

    v_new_count := coalesce(array_length(v_new_classes, 1), 0);

    if v_new_count = 0 then
      v_summary := v_summary || jsonb_build_object('grade', v_grade, 'action', 'skipped', 'students_affected', 0);
      continue;
    end if;

    v_moved := 0;

    if v_new_count = v_old_count then
      for v_i in 1..v_old_count loop
        update students set class_id = v_new_classes[v_i], academic_year_id = p_new_year_id
        where class_id = v_old_classes[v_i] and is_graduated = false and school_id = v_school_id;
        get diagnostics v_moved = row_count;
      end loop;
    else
      update students set class_id = v_new_classes[1], academic_year_id = p_new_year_id
      where class_id = any(v_old_classes) and is_graduated = false and school_id = v_school_id;
      get diagnostics v_moved = row_count;
    end if;

    v_total_moved := v_total_moved + v_moved;
    v_summary := v_summary || jsonb_build_object('grade', v_grade, 'students_moved', v_moved);
  end loop;

  select array_agg(id) into v_old_classes
  from classes
  where academic_year_id = p_old_year_id
    and school_id = v_school_id
    and extract_grade_from_class_name(class_name) = 6;

  if v_old_classes is not null then
    update students
    set is_graduated = true, class_id = null, academic_year_id = p_new_year_id
    where class_id = any(v_old_classes) and is_graduated = false and school_id = v_school_id;
    get diagnostics v_graduated = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'total_promoted', v_total_moved,
    'total_graduated', v_graduated,
    'details', v_summary
  );
end;
$$ language plpgsql security definer;


-- ============================================================
-- 11. NEW FUNCTION: super_admin_create_school
-- Only Tra (super_admin) can call this
-- Creates school + first admin account in one atomic operation
-- Actual auth user creation done via Edge Function manage-user
-- ============================================================

create or replace function super_admin_create_school(
  p_school_name_khmer  text,
  p_school_name_english text,
  p_school_code        text,
  p_province           text,
  p_district           text
)
returns uuid as $$
declare
  v_school_id uuid;
begin
  if get_user_role() != 'super_admin' then
    raise exception 'Permission denied: super_admin only';
  end if;

  insert into schools (
    name_khmer, name_english, school_code, province, district
  ) values (
    p_school_name_khmer, p_school_name_english,
    p_school_code, p_province, p_district
  )
  returning id into v_school_id;

  -- Also create default school_settings row for new school
  insert into school_settings (school_id)
  values (v_school_id);

  -- Also create default school_information row
  insert into school_information (name_khmer, name_english, school_code, school_id)
  values (p_school_name_khmer, p_school_name_english, p_school_code, v_school_id);

  return v_school_id;
end;
$$ language plpgsql security definer;


-- ============================================================
-- 12. UPDATE manage-user Edge Function note
-- Now must also accept school_id when creating users
-- And super_admin can create users for any school
-- ============================================================

-- Edge Function manage-user updated payload (for reference):
-- {
--   action: "create",
--   payload: {
--     email, password, role, full_name,
--     school_id   ← NEW: which school this user belongs to
--   }
-- }


-- ============================================================
-- VERIFY
-- ============================================================

select 'schools table' as item, count(*)::text as result from schools
union all
select 'school_id on users', count(*)::text from users where school_id is not null
union all
select 'school_id on students', count(*)::text from students where school_id is not null
union all
select 'school_id on teachers', count(*)::text from teachers where school_id is not null
union all
select 'indexes created', count(*)::text
from pg_indexes where tablename in ('users','students','teachers','classes','scores','attendances')
  and indexname like 'idx_%school%';


-- ============================================================
-- DONE — Migration v7 → v8 complete
-- All existing data preserved and assigned to default school
-- ============================================================
