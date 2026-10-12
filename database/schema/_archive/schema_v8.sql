-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- schema_v8.sql — Full Schema (fresh install)
-- Version: 8 (roadmap v13)
-- Stack: Supabase (PostgreSQL)
-- ============================================================
--
-- ROLES:
--   super_admin → Tra only. Sees ALL schools. Creates schools + first admin.
--   admin       → School director. Manages their school only.
--   teacher     → Manages their assigned class only.
--   librarian   → Library only (books + borrows).
--   parent      → Anonymous (anon). Read-only via name + DOB.
--
-- KEY DESIGN DECISIONS:
--   1. Every staff member IS a teacher in Cambodian schools.
--      ALL users (admin/teacher/librarian) always have a teachers row.
--      role = system access level only, not identity.
--
--   2. Multi-tenant: every table has school_id.
--      RLS auto-scopes all queries to the user's school.
--      super_admin bypasses school RLS — sees everything.
--
--   3. Subjects are per-class (class_subjects junction table).
--      Grade 1-3 → no English. Grade 4-6 → English included.
--
--   4. Teacher check-in is once-per-day via DB function.
--      Auto-calculates present/late from school_settings thresholds.
--
--   5. Student rollup: end-of-year promotion via perform_student_rollup().
--      Grade 6 → is_graduated = true.
--
-- VERSION HISTORY:
--   v1 → Initial schema
--   v2 → Role system + RLS
--   v3 → Attendance improvements
--   v4 → All users have teachers row (Cambodian school design)
--   v5 → school_settings + teacher check-in + admin override
--   v6 → class_subjects junction table (per-class subjects)
--   v7 → is_graduated + student rollup functions
--   v8 → Multi-tenant: schools table + school_id on all tables
--         + super_admin role + 25+ indexes + updated RLS
-- ============================================================


-- ============================================================
-- EXTENSIONS
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;


-- ============================================================
-- ENUMS
-- ============================================================

create type user_status as enum ('active', 'inactive');

-- super_admin = Tra only (platform level)
-- admin       = school director (school level)
-- teacher     = class teacher
-- librarian   = library staff
create type user_role as enum ('super_admin', 'admin', 'teacher', 'librarian');

create type attendance_status as enum ('present', 'absent', 'late', 'permission');

create type score_type as enum ('monthly', 'semester', 'annual');

create type budget_type as enum ('income', 'expense');

create type borrow_status as enum ('borrowed', 'returned', 'overdue');

create type class_turn as enum ('morning', 'afternoon');

create type academic_status as enum ('active', 'inactive');


-- ============================================================
-- SCHOOLS
-- One row per school. Created by super_admin only.
-- ============================================================

create table schools (
  id              uuid primary key default uuid_generate_v4(),
  name_khmer      text not null,
  name_english    text,
  school_code     text not null unique,    -- e.g. BTB-001
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


-- ============================================================
-- USERS
-- Linked to Supabase auth.users.
-- role = system access level (not identity).
-- Every user ALWAYS has a matching teachers row.
-- school_id scopes user to their school (except super_admin).
-- ============================================================

create table users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  role        user_role not null default 'teacher',
  status      user_status not null default 'active',
  school_id   uuid references schools(id) on delete cascade default get_user_school_id(),  -- null for super_admin
  created_at  timestamptz default now()
);


-- ============================================================
-- SCHOOL SETTINGS
-- One row per school — configurable late thresholds + shift times.
-- Auto-created when super_admin_create_school() runs.
-- ============================================================

create table school_settings (
  id                     uuid primary key default uuid_generate_v4(),
  school_id              uuid not null unique references schools(id) on delete cascade default get_user_school_id(),
  morning_start          time not null default '07:00',
  morning_late_threshold time not null default '07:15',   -- late if check-in after this
  evening_start          time not null default '13:00',
  evening_late_threshold time not null default '13:15',   -- late if check-in after this
  created_at             timestamptz default now(),
  updated_at             timestamptz default now()
);


-- ============================================================
-- SCHOOL INFORMATION
-- Detailed school profile (name, logo, director, address...).
-- One row per school. Auto-created by super_admin_create_school().
-- ============================================================

create table school_information (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null unique references schools(id) on delete cascade default get_user_school_id(),
  name_khmer      text not null,
  name_english    text,
  school_code     text,
  director_name   text,
  address         text,
  phone           text,
  email           text,
  logo_url        text,                   -- Supabase Storage URL
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);


-- ============================================================
-- ACADEMIC YEARS
-- Scoped per school. Admin manages their own school's years.
-- ============================================================

create table academic_years (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references schools(id) on delete cascade default get_user_school_id(),
  year_name   text not null,
  start_date  date not null,
  end_date    date not null,
  status      academic_status not null default 'active',
  created_at  timestamptz default now()
);


-- ============================================================
-- SUBJECTS
-- Global pool of subjects per school.
-- Assigned to specific classes via class_subjects junction table.
-- ============================================================

create table subjects (
  id            uuid primary key default uuid_generate_v4(),
  school_id     uuid not null references schools(id) on delete cascade default get_user_school_id(),
  subject_name  text not null,
  created_at    timestamptz default now()
);


-- ============================================================
-- TEACHERS
-- Personal/professional profile for ALL staff members.
-- Created for every user regardless of role (admin/teacher/librarian).
-- user_id is always required — never null.
-- ============================================================

create table teachers (
  id            uuid primary key default uuid_generate_v4(),
  school_id     uuid not null references schools(id) on delete cascade default get_user_school_id(),
  user_id       uuid not null unique references users(id) on delete cascade,
  full_name     text not null,
  gender        text,
  dob           date,
  phone_number  text,
  degree        text,
  address       text,
  email         text,
  profile_url   text,        -- Supabase Storage: teacher-profiles bucket
  created_at    timestamptz default now()
);


-- ============================================================
-- CLASSES
-- Scoped per school + academic year.
-- ============================================================

create table classes (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  class_name       text not null,
  teacher_id       uuid references teachers(id) on delete set null,
  academic_year_id uuid references academic_years(id) on delete cascade,
  turn             class_turn not null default 'morning',
  created_at       timestamptz default now()
);


-- ============================================================
-- CLASS SUBJECTS
-- Junction table: which subjects does each class have?
-- Grade 1-3 → no English. Grade 4-6 → English included.
-- Admin assigns subjects per class when creating/editing a class.
-- Score entry fetches subjects from this table — not global subjects.
-- ============================================================

create table class_subjects (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references schools(id) on delete cascade default get_user_school_id(),
  class_id   uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  created_at timestamptz default now(),
  unique(class_id, subject_id)
);


-- ============================================================
-- STUDENTS
-- ============================================================

create table students (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  real_id          text,
  full_name        text not null,
  gender           text,
  dob              date not null,
  address          text,
  phone_number     text,
  father_name      text,
  father_job       text,
  mother_name      text,
  mother_job       text,
  class_id         uuid references classes(id) on delete set null,
  is_scholarship   boolean default false,
  is_disability    boolean default false,
  is_graduated     boolean not null default false,   -- set true when grade 6 rolls over
  academic_year_id uuid references academic_years(id) on delete set null,
  created_at       timestamptz default now(),
  updated_at       date
);


-- ============================================================
-- STUDENT HEALTH
-- Static health profile: one row per student.
-- ============================================================

create table student_health (
  id                      uuid primary key default uuid_generate_v4(),
  school_id               uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id              uuid not null unique references students(id) on delete cascade,
  blood_type              text,
  allergies               text,
  medical_conditions      text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  vaccination_complete    boolean default false,
  created_at              timestamptz default now(),
  updated_at              date
);


-- ============================================================
-- STUDENT CHECKUPS
-- Periodic health visits — multiple rows per student.
-- ============================================================

create table student_checkups (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  type       text,
  result     text,
  vision     text,
  hearing    text,
  dental     text,
  notes      text
);


-- ============================================================
-- STUDENT GROWTH
-- Height/weight records over time.
-- ============================================================

create table student_growth (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  age        int4,
  height     numeric,
  weight     numeric
);


-- ============================================================
-- STUDENT VACCINATIONS
-- ============================================================

create table student_vaccinations (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id  uuid not null references students(id) on delete cascade,
  name        text not null,
  description text,
  completed   boolean default false,
  date        date
);


-- ============================================================
-- STUDENT SICK DAYS
-- ============================================================

create table student_sick_days (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  reason     text,
  duration   int4,
  notes      text
);


-- ============================================================
-- ATTENDANCES (Student)
-- Cambodia school days = Monday to Saturday.
-- Sundays + school_holidays = off days (shaded in calendar view).
-- ============================================================

create table attendances (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  status     attendance_status not null default 'present',
  reason     text,
  created_at timestamptz default now()
);


-- ============================================================
-- SCORES
-- Raw subject scores per student per month/semester.
-- Averages, ranks calculated on frontend (scoreCalculator.js).
-- ============================================================

create table scores (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id       uuid not null references students(id) on delete cascade,
  subject_id       uuid not null references subjects(id) on delete cascade,
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  score_type       score_type not null,
  score            numeric,
  month            int2,                   -- 1-12, null for semester
  created_at       timestamptz default now()
);


-- ============================================================
-- TEACHER ATTENDANCES
-- check_in_time: actual timestamp recorded when teacher checks in.
-- status: auto-calculated (present/late) by teacher_check_in() function.
-- note: filled by admin when overriding attendance manually.
-- unique(teacher_id, date): enforces one check-in per day at DB level.
-- ============================================================

create table teacher_attendances (
  id             uuid primary key default uuid_generate_v4(),
  school_id      uuid not null references schools(id) on delete cascade default get_user_school_id(),
  teacher_id     uuid not null references teachers(id) on delete cascade,
  date           date not null,
  check_in_time  timestamptz,
  status         attendance_status not null default 'present',
  note           text,
  created_at     timestamptz default now(),
  unique(teacher_id, date)
);


-- ============================================================
-- SCHOOL HOLIDAYS
-- Scoped per school + academic year.
-- Used to shade off days in attendance calendar/grid.
-- ============================================================

create table school_holidays (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  academic_year_id uuid references academic_years(id) on delete cascade,
  name             text not null,
  start_date       date not null,
  end_date         date not null,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);


-- ============================================================
-- BOOKS
-- ============================================================

create table books (
  id               int4 primary key generated always as identity,
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  title            varchar not null,
  author           varchar,
  isbn             varchar,
  category         varchar,
  total_copies     int4 default 1,
  available_copies int4 default 1,
  created_at       timestamptz default now()
);


-- ============================================================
-- BOOK BORROWS
-- ============================================================

create table book_borrows (
  id          int4 primary key generated always as identity,
  school_id   uuid not null references schools(id) on delete cascade default get_user_school_id(),
  book_id     int4 not null references books(id) on delete cascade,
  student_id  uuid not null references students(id) on delete cascade,
  borrow_date date not null,
  due_date    date not null,
  return_date date,
  status      borrow_status not null default 'borrowed',
  created_at  timestamptz default now()
);


-- ============================================================
-- BUDGET TRANSACTIONS
-- ============================================================

create table budget_transactions (
  id               int4 primary key generated always as identity,
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  academic_year_id uuid references academic_years(id) on delete set null,
  type             budget_type not null,
  date             date not null,
  description      text,
  category         text,
  amount           numeric not null,
  note             text,
  created_at       timestamptz default now()
);


-- ============================================================
-- INVENTORY ITEMS
-- ============================================================

create table inventory_items (
  id           int4 primary key generated always as identity,
  school_id    uuid not null references schools(id) on delete cascade default get_user_school_id(),
  name         text not null,
  category     text,
  quantity     int4 default 0,
  min_stock    int4 default 0,
  location     text,
  condition    text,
  description  text,
  notes        text,
  last_updated date,
  created_at   timestamptz default now()
);


-- ============================================================
-- PERFORMANCE INDEXES
-- school_id is the primary filter in every multi-tenant query.
-- ============================================================

create index idx_users_school_id               on users(school_id);
create index idx_teachers_school_id            on teachers(school_id);
create index idx_classes_school_id             on classes(school_id);
create index idx_classes_year                  on classes(academic_year_id);
create index idx_students_school_id            on students(school_id);
create index idx_students_school_class         on students(school_id, class_id);
create index idx_students_school_name_dob      on students(school_id, full_name, dob);
create index idx_academic_years_school_id      on academic_years(school_id);
create index idx_subjects_school_id            on subjects(school_id);
create index idx_class_subjects_school_id      on class_subjects(school_id);
create index idx_class_subjects_class          on class_subjects(class_id);
create index idx_school_settings_school_id     on school_settings(school_id);
create index idx_school_holidays_school_id     on school_holidays(school_id);
create index idx_attendances_school_id         on attendances(school_id);
create index idx_attendances_student_date      on attendances(student_id, date);
create index idx_scores_school_id              on scores(school_id);
create index idx_scores_student_subject        on scores(student_id, subject_id);
create index idx_scores_student_type_month     on scores(student_id, score_type, month);
create index idx_teacher_attendances_school_id on teacher_attendances(school_id);
create index idx_teacher_attendances_t_date    on teacher_attendances(teacher_id, date);
create index idx_books_school_id               on books(school_id);
create index idx_book_borrows_school_id        on book_borrows(school_id);
create index idx_budget_school_id              on budget_transactions(school_id);
create index idx_inventory_school_id           on inventory_items(school_id);
create index idx_student_health_school_id      on student_health(school_id);
create index idx_student_checkups_school_id    on student_checkups(school_id);
create index idx_student_growth_school_id      on student_growth(school_id);
create index idx_student_vaccinations_school   on student_vaccinations(school_id);
create index idx_student_sick_days_school      on student_sick_days(school_id);


-- ============================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================================

alter table schools               enable row level security;
alter table users                 enable row level security;
alter table school_settings       enable row level security;
alter table school_information    enable row level security;
alter table academic_years        enable row level security;
alter table subjects              enable row level security;
alter table teachers              enable row level security;
alter table classes               enable row level security;
alter table class_subjects        enable row level security;
alter table students              enable row level security;
alter table student_health        enable row level security;
alter table student_checkups      enable row level security;
alter table student_growth        enable row level security;
alter table student_vaccinations  enable row level security;
alter table student_sick_days     enable row level security;
alter table attendances           enable row level security;
alter table scores                enable row level security;
alter table teacher_attendances   enable row level security;
alter table school_holidays       enable row level security;
alter table books                 enable row level security;
alter table book_borrows          enable row level security;
alter table budget_transactions   enable row level security;
alter table inventory_items       enable row level security;


-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Get current user's role
create or replace function get_user_role()
returns user_role as $$
  select role from users where id = auth.uid();
$$ language sql security definer stable;

-- Get current user's school_id
create or replace function get_user_school_id()
returns uuid as $$
  select school_id from users where id = auth.uid();
$$ language sql security definer stable;


-- ============================================================
-- RLS POLICIES
-- ============================================================


-- ------------------------------------------------------------
-- SCHOOLS
-- ------------------------------------------------------------

create policy "schools: super_admin full"
  on schools for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "schools: admin read own"
  on schools for select to authenticated
  using (id = get_user_school_id());


-- ------------------------------------------------------------
-- USERS
-- ------------------------------------------------------------

create policy "users: super_admin full"
  on users for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "users: admin manage own school"
  on users for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "users: self read"
  on users for select to authenticated
  using (id = auth.uid());


-- ------------------------------------------------------------
-- SCHOOL SETTINGS
-- ------------------------------------------------------------

create policy "school_settings: super_admin full"
  on school_settings for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "school_settings: admin manage own school"
  on school_settings for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "school_settings: staff read own school"
  on school_settings for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- SCHOOL INFORMATION
-- ------------------------------------------------------------

create policy "school_information: super_admin full"
  on school_information for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "school_information: admin manage own school"
  on school_information for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "school_information: staff read own school"
  on school_information for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- ACADEMIC YEARS
-- ------------------------------------------------------------

create policy "academic_years: admin manage own school"
  on academic_years for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "academic_years: staff read own school"
  on academic_years for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- SUBJECTS
-- ------------------------------------------------------------

create policy "subjects: admin manage own school"
  on subjects for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "subjects: teacher read own school"
  on subjects for select to authenticated
  using (get_user_role() = 'teacher' and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- TEACHERS
-- ------------------------------------------------------------

create policy "teachers: super_admin full"
  on teachers for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

create policy "teachers: admin manage own school"
  on teachers for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "teachers: self read"
  on teachers for select to authenticated
  using (user_id = auth.uid());


-- ------------------------------------------------------------
-- CLASSES
-- ------------------------------------------------------------

create policy "classes: admin manage own school"
  on classes for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "classes: teacher read own"
  on classes for select to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );


-- ------------------------------------------------------------
-- CLASS SUBJECTS
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- STUDENTS
-- ------------------------------------------------------------

create policy "students: admin manage own school"
  on students for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

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
  using (get_user_role() = 'librarian' and school_id = get_user_school_id());

-- Parent: anon read (app filters by school + name + dob)
create policy "students: anon read for parent"
  on students for select to anon
  using (true);


-- ------------------------------------------------------------
-- STUDENT HEALTH
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- STUDENT CHECKUPS
-- ------------------------------------------------------------

create policy "student_checkups: admin manage own school"
  on student_checkups for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "student_checkups: teacher manage own class"
  on student_checkups for all to authenticated
  using (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_checkups: anon read for parent"
  on student_checkups for select to anon using (true);


-- ------------------------------------------------------------
-- STUDENT GROWTH
-- ------------------------------------------------------------

create policy "student_growth: admin manage own school"
  on student_growth for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "student_growth: teacher manage own class"
  on student_growth for all to authenticated
  using (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_growth: anon read for parent"
  on student_growth for select to anon using (true);


-- ------------------------------------------------------------
-- STUDENT VACCINATIONS
-- ------------------------------------------------------------

create policy "student_vaccinations: admin manage own school"
  on student_vaccinations for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "student_vaccinations: teacher manage own class"
  on student_vaccinations for all to authenticated
  using (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_vaccinations: anon read for parent"
  on student_vaccinations for select to anon using (true);


-- ------------------------------------------------------------
-- STUDENT SICK DAYS
-- ------------------------------------------------------------

create policy "student_sick_days: admin manage own school"
  on student_sick_days for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "student_sick_days: teacher manage own class"
  on student_sick_days for all to authenticated
  using (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and school_id = get_user_school_id() and
    student_id in (
      select s.id from students s join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_sick_days: anon read for parent"
  on student_sick_days for select to anon using (true);


-- ------------------------------------------------------------
-- ATTENDANCES
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- SCORES
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- TEACHER ATTENDANCES
-- ------------------------------------------------------------

create policy "teacher_attendances: admin manage own school"
  on teacher_attendances for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

-- Teacher reads own attendance only
-- Write access only via teacher_check_in() function (enforces once-per-day)
create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );


-- ------------------------------------------------------------
-- SCHOOL HOLIDAYS
-- ------------------------------------------------------------

create policy "school_holidays: admin manage own school"
  on school_holidays for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "school_holidays: staff read own school"
  on school_holidays for select to authenticated
  using (get_user_role() in ('teacher', 'librarian') and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- BOOKS
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- BOOK BORROWS
-- ------------------------------------------------------------

create policy "book_borrows: admin manage own school"
  on book_borrows for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "book_borrows: librarian manage own school"
  on book_borrows for all to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id())
  with check (get_user_role() = 'librarian' and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- BUDGET TRANSACTIONS
-- ------------------------------------------------------------

create policy "budget_transactions: admin manage own school"
  on budget_transactions for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());


-- ------------------------------------------------------------
-- INVENTORY ITEMS
-- ------------------------------------------------------------

create policy "inventory_items: admin manage own school"
  on inventory_items for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());


-- ============================================================
-- DB FUNCTIONS
-- ============================================================


-- ------------------------------------------------------------
-- handle_new_user (trigger)
-- Fires on auth.users insert — auto creates public.users row.
-- school_id and role pulled from raw_user_meta_data.
-- manage-user Edge Function sets these when creating accounts.
-- ------------------------------------------------------------

create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, role, school_id)
  values (
    new.id,
    new.email,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'teacher'),
    case 
      when new.raw_user_meta_data->>'school_id' = '' then null
      else (new.raw_user_meta_data->>'school_id')::uuid 
    end
  );
  return new;
exception when others then
  -- Log the error to the database logs
  raise notice 'Error in handle_new_user for email %: %', new.email, sqlerrm;
  raise exception 'Database error creating new user: %', sqlerrm;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function handle_new_user();

-- ============================================================
-- FIX: handle_new_user trigger
-- Problem: school_id cast fails if value is null/invalid UUID
--          causing "Database error creating new user" on all
--          non-super_admin user creation via Edge Function.
-- ============================================================

create or replace function handle_new_user()
returns trigger as $$
declare
  v_role      user_role;
  v_school_id uuid;
  v_raw_role  text;
  v_raw_school text;
begin
  -- Safely extract role
  v_raw_role := new.raw_user_meta_data->>'role';
  v_role := coalesce(
    case
      when v_raw_role in ('super_admin','admin','teacher','librarian')
      then v_raw_role::user_role
      else null
    end,
    'teacher'
  );

  -- Safely extract school_id (null if missing, empty, or not a valid UUID)
  v_raw_school := trim(new.raw_user_meta_data->>'school_id');
  begin
    if v_raw_school is not null and v_raw_school != '' then
      v_school_id := v_raw_school::uuid;
    else
      v_school_id := null;
    end if;
  exception when others then
    v_school_id := null;
  end;

  insert into public.users (id, email, role, school_id)
  values (new.id, new.email, v_role, v_school_id)
  on conflict (id) do update
    set role      = excluded.role,
        school_id = excluded.school_id;

  return new;

exception when others then
  raise notice 'handle_new_user failed for %: %', new.email, sqlerrm;
  raise exception 'Database error creating new user: %', sqlerrm;
end;
$$ language plpgsql security definer;

-- ------------------------------------------------------------
-- teacher_check_in
-- Teacher calls once per day. Records exact timestamp.
-- Auto-calculates present/late from school_settings thresholds.
-- Blocked if already checked in today (unique constraint).
-- ------------------------------------------------------------

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
  -- Get teacher + school
  select id, school_id into v_teacher_id, v_school_id
  from teachers where user_id = auth.uid();

  if v_teacher_id is null then
    raise exception 'Teacher profile not found';
  end if;

  -- Enforce once-per-day (also enforced by unique constraint)
  select * into v_existing
  from teacher_attendances
  where teacher_id = v_teacher_id and date = v_today;

  if v_existing.id is not null then
    raise exception 'Already checked in today at %', v_existing.check_in_time;
  end if;

  -- Get teacher's class turn (morning/afternoon)
  select c.turn into v_turn
  from classes c
  where c.teacher_id = v_teacher_id and c.school_id = v_school_id
  limit 1;

  v_turn := coalesce(v_turn, 'morning');

  -- Get configured late thresholds for this school
  select * into v_settings
  from school_settings where school_id = v_school_id limit 1;

  if v_turn = 'morning' then
    v_threshold := v_settings.morning_late_threshold;
  else
    v_threshold := v_settings.evening_late_threshold;
  end if;

  -- Auto-calculate status
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


-- ------------------------------------------------------------
-- admin_override_teacher_attendance
-- Admin manually sets or overrides any teacher's attendance.
-- Upserts — works whether record exists or not.
-- ------------------------------------------------------------

create or replace function admin_override_teacher_attendance(
  p_teacher_id uuid,
  p_date       date,
  p_status     attendance_status,
  p_note       text default null
)
returns void as $$
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  insert into teacher_attendances (teacher_id, date, status, note, school_id)
  values (p_teacher_id, p_date, p_status, p_note, get_user_school_id())
  on conflict (teacher_id, date)
  do update set status = excluded.status, note = excluded.note;
end;
$$ language plpgsql security definer;


-- ------------------------------------------------------------
-- admin_update_user_status
-- Deactivate → sets banned_until in auth.users (blocks login).
-- Reactivate → clears ban.
-- ------------------------------------------------------------

create or replace function admin_update_user_status(
  p_user_id uuid,
  p_status  user_status
)
returns void as $$
begin
  if get_user_role() not in ('admin', 'super_admin') then
    raise exception 'Permission denied';
  end if;

  -- Admin can only affect users in their own school
  if get_user_role() = 'admin' then
    if not exists (
      select 1 from users
      where id = p_user_id and school_id = get_user_school_id()
    ) then
      raise exception 'User not found in your school';
    end if;
  end if;

  update users set status = p_status where id = p_user_id;

  if p_status = 'inactive' then
    update auth.users set banned_until = '2099-12-31' where id = p_user_id;
  else
    update auth.users set banned_until = null where id = p_user_id;
  end if;
end;
$$ language plpgsql security definer;


-- ------------------------------------------------------------
-- admin_update_user_role
-- Change a user's role (admin or super_admin only).
-- ------------------------------------------------------------

create or replace function admin_update_user_role(
  p_user_id uuid,
  p_role    user_role
)
returns void as $$
begin
  if get_user_role() not in ('admin', 'super_admin') then
    raise exception 'Permission denied';
  end if;

  -- admin cannot assign super_admin role
  if get_user_role() = 'admin' and p_role = 'super_admin' then
    raise exception 'Cannot assign super_admin role';
  end if;

  update users set role = p_role where id = p_user_id;
end;
$$ language plpgsql security definer;


-- ------------------------------------------------------------
-- super_admin_create_school
-- Tra only. Creates school + auto-creates school_settings
-- + school_information rows atomically.
-- Returns new school_id for use in Edge Function manage-user.
-- ------------------------------------------------------------

create or replace function super_admin_create_school(
  p_name_khmer   text,
  p_name_english text,
  p_school_code  text,
  p_province     text,
  p_district     text
)
returns uuid as $$
declare
  v_school_id uuid;
begin
  if get_user_role() != 'super_admin' then
    raise exception 'Permission denied: super_admin only';
  end if;

  insert into schools (name_khmer, name_english, school_code, province, district)
  values (p_name_khmer, p_name_english, p_school_code, p_province, p_district)
  returning id into v_school_id;

  -- Auto-create singleton settings row for new school
  insert into school_settings (school_id) values (v_school_id);

  -- Auto-create school information row
  insert into school_information (school_id, name_khmer, name_english, school_code)
  values (v_school_id, p_name_khmer, p_name_english, p_school_code);

  return v_school_id;
end;
$$ language plpgsql security definer;


-- ------------------------------------------------------------
-- Khmer numeral helpers (for student rollup)
-- ------------------------------------------------------------

create or replace function khmer_to_int(p_khmer text)
returns int as $$
declare v_result text := p_khmer;
begin
  v_result := replace(v_result, '០', '0'); v_result := replace(v_result, '១', '1');
  v_result := replace(v_result, '២', '2'); v_result := replace(v_result, '៣', '3');
  v_result := replace(v_result, '៤', '4'); v_result := replace(v_result, '៥', '5');
  v_result := replace(v_result, '៦', '6'); v_result := replace(v_result, '៧', '7');
  v_result := replace(v_result, '៨', '8'); v_result := replace(v_result, '៩', '9');
  return v_result::int;
end;
$$ language plpgsql immutable;

create or replace function int_to_khmer(p_int int)
returns text as $$
declare v_result text := p_int::text;
begin
  v_result := replace(v_result, '0', '០'); v_result := replace(v_result, '1', '១');
  v_result := replace(v_result, '2', '២'); v_result := replace(v_result, '3', '៣');
  v_result := replace(v_result, '4', '៤'); v_result := replace(v_result, '5', '៥');
  v_result := replace(v_result, '6', '៦'); v_result := replace(v_result, '7', '៧');
  v_result := replace(v_result, '8', '៨'); v_result := replace(v_result, '9', '៩');
  return v_result;
end;
$$ language plpgsql immutable;

create or replace function extract_grade_from_class_name(p_class_name text)
returns int as $$
declare
  v_stripped     text;
  v_digits       text := '';
  v_char         text;
  v_i            int;
  v_khmer_digits text := '០១២៣៤៥៦៧៨៩';
begin
  v_stripped := replace(p_class_name, 'ថ្នាក់ទី', '');
  for v_i in 1..char_length(v_stripped) loop
    v_char := substring(v_stripped from v_i for 1);
    if strpos(v_khmer_digits, v_char) > 0 then
      v_digits := v_digits || v_char;
    else exit;
    end if;
  end loop;
  if v_digits = '' then return null; end if;
  return khmer_to_int(v_digits);
end;
$$ language plpgsql immutable;


-- ------------------------------------------------------------
-- perform_student_rollup
-- End-of-year: promotes students grade N → N+1.
-- Grade 6 → is_graduated = true, class_id = null.
-- School-scoped — only affects caller's school.
-- ------------------------------------------------------------

create or replace function perform_student_rollup(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb as $$
declare
  v_school_id   uuid := get_user_school_id();
  v_grade       int;
  v_old_classes uuid[];
  v_new_classes uuid[];
  v_old_count   int;
  v_new_count   int;
  v_moved       int;
  v_total_moved int := 0;
  v_graduated   int := 0;
  v_summary     jsonb := '[]'::jsonb;
  v_i           int;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if p_old_year_id = p_new_year_id then
    raise exception 'Old and new academic year must be different';
  end if;

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
      v_summary := v_summary || jsonb_build_object(
        'grade', v_grade, 'action', 'skipped', 'students_affected', 0
      );
      continue;
    end if;

    v_moved := 0;

    if v_new_count = v_old_count then
      for v_i in 1..v_old_count loop
        update students
        set class_id = v_new_classes[v_i], academic_year_id = p_new_year_id
        where class_id = v_old_classes[v_i]
          and is_graduated = false and school_id = v_school_id;
        get diagnostics v_moved = row_count;
      end loop;
    else
      update students
      set class_id = v_new_classes[1], academic_year_id = p_new_year_id
      where class_id = any(v_old_classes)
        and is_graduated = false and school_id = v_school_id;
      get diagnostics v_moved = row_count;
    end if;

    v_total_moved := v_total_moved + v_moved;
    v_summary := v_summary || jsonb_build_object(
      'grade', v_grade,
      'action', case when v_new_count = v_old_count then 'paired' else 'merged' end,
      'students_moved', v_moved
    );
  end loop;

  -- Grade 6 → graduate
  select array_agg(id) into v_old_classes
  from classes
  where academic_year_id = p_old_year_id and school_id = v_school_id
    and extract_grade_from_class_name(class_name) = 6;

  if v_old_classes is not null then
    update students
    set is_graduated = true, class_id = null, academic_year_id = p_new_year_id
    where class_id = any(v_old_classes)
      and is_graduated = false and school_id = v_school_id;
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


-- ------------------------------------------------------------
-- clone_classes_structure
-- Copies class definitions (name, turn) from old → new year.
-- Does NOT copy students or teacher assignments.
-- ------------------------------------------------------------

create or replace function clone_classes_structure(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns int as $$
declare v_count int;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  insert into classes (class_name, turn, academic_year_id, school_id)
  select class_name, turn, p_new_year_id, get_user_school_id()
  from classes
  where academic_year_id = p_old_year_id
    and school_id = get_user_school_id()
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$ language plpgsql security definer;


-- ============================================================
-- SUPABASE STORAGE BUCKET: teacher-profiles
-- Public bucket — all staff profile pictures stored here.
-- File path: {user_id}/{filename}
-- ============================================================

insert into storage.buckets (id, name, public)
values ('teacher-profiles', 'teacher-profiles', true)
on conflict do nothing;

create policy "teacher-profiles: admin full"
  on storage.objects for all to authenticated
  using (bucket_id = 'teacher-profiles' and get_user_role() in ('admin', 'super_admin'))
  with check (bucket_id = 'teacher-profiles' and get_user_role() in ('admin', 'super_admin'));

create policy "teacher-profiles: self upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'teacher-profiles' and
    (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "teacher-profiles: self update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'teacher-profiles' and
    (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "teacher-profiles: public read"
  on storage.objects for select to public
  using (bucket_id = 'teacher-profiles');


-- ============================================================
-- SUPABASE EDGE FUNCTION: manage-user
-- Required for: create user, reset password, delete user.
-- Needs service_role key — runs server-side only.
-- Create file: supabase/functions/manage-user/index.ts
--
-- Handles these actions via POST body { action, payload }:
--
--   action: "create"
--     payload: {
--       email, password, role, school_id,
--       full_name, gender, dob, phone_number,
--       degree, address, profile_url
--     }
--     → creates auth.users (sets raw_user_meta_data with role + school_id)
--     → trigger handle_new_user() auto creates public.users
--     → inserts teachers row (full profile, user_id linked)
--     NOTE: ALL roles get a teachers row
--
--   action: "reset_password"
--     payload: { user_id, new_password }
--     → updates auth user password
--
--   action: "delete"
--     payload: { user_id }
--     → deletes auth user (cascades to public.users + teachers)
--
-- Security:
--   super_admin → can create users for ANY school (passes school_id)
--   admin       → Edge Function enforces school_id = caller's school_id
--
-- Called from Vue frontend:
--   supabase.functions.invoke('manage-user', { body: { action, payload } })
-- ============================================================


-- ============================================================
-- DONE — schema_v8.sql
-- Fresh install covers all versions v1 → v8
-- For upgrading existing installs: run migration_v7_v8.sql instead
-- ============================================================
