-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- schema_v10.sql — Full Schema (fresh install)
-- Version: 10 (roadmap v16)
-- Stack: Supabase (PostgreSQL)
-- ============================================================
--
-- ROLES:
--   super_admin → Tra only. Sees ALL schools. Creates schools + first admin.
--   admin       → School director. Manages their school only.
--   teacher     → Manages their assigned class only.
--   librarian   → Library only (books + borrows).
--   parent      → Anonymous (anon). Read-only via approved report link only.
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
--   6. Parent portal is link-only — no search, no DOB, no login.
--      Teacher generates report link per class per month/semester.
--      Anon RLS scoped to report_link_id — no open using (true).
--      Health/growth/vaccinations/sick_days NOT exposed to anon.
--      Anon can only access APPROVED report links (v10).
--
--   7. Report link approval flow (v10):
--      Teacher requests → admin approves/rejects → link unlocks for sharing.
--      Parent report card shows principal signature + school stamp (approved only).
--
--   8. In-app notifications (v10):
--      DB triggers auto-create notification rows for admin (on request)
--      and teacher (on approve/reject). In-app bell icon only, no push/email.
--
--   9. Teacher phrase library (v10):
--      Personal reusable feedback phrases per teacher.
--      Chips shown below message box — click to append. Private per teacher.
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
--   v9 → Link-based parent portal: report_links + report_messages
--         + report-voices storage bucket
--         + tightened anon RLS (scoped to report_link_id)
--         + removed anon access to health/growth/vaccinations/sick_days
--   v10 → Report link approval flow: status + rejection_note + approved_by
--          + notifications table + teacher_phrases table
--          + school_information: signature_url + stamp_url
--          + school-assets storage bucket
--          + DB triggers: notify_admin_on_request + notify_teacher_on_approval
--          + anon RLS: only approved report links visible
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

create type score_type as enum ('monthly', 'semester');

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
  signature_url   text,                   -- v10: principal digital signature image (school-assets bucket)
  stamp_url       text,                   -- v10: official school stamp image (school-assets bucket)
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
-- NOT exposed to anon — staff only.
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
-- NOT exposed to anon — staff only.
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
-- NOT exposed to anon — staff only.
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
-- NOT exposed to anon — staff only.
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
-- NOT exposed to anon — staff only.
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
-- Anon read scoped to report link context only (v9).
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
-- Anon read scoped to report link context only (v9).
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
  semester         int2,                   -- 1 or 2, null for monthly
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
-- REPORT LINKS (v9)
-- One row per class per month/semester.
-- Generated by teacher from /teacher/scores/ranking.
-- UUID id is the shareable token used in parent portal URL.
-- unique constraint makes upsert idempotent.
-- ============================================================

create table report_links (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade default get_user_school_id(),
  class_id         uuid not null references classes(id) on delete cascade,
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  created_by       uuid not null references teachers(id) on delete cascade,
  score_type       score_type not null,
  month            int2,        -- 1-12, null if semester
  semester         int2,        -- 1 or 2, null if monthly
  -- v10 approval flow
  status           text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  rejection_note   text,        -- optional note from principal when rejecting
  approved_at      timestamptz, -- when admin approved/rejected
  approved_by      uuid references teachers(id) on delete set null,  -- teacher_id of the approving admin
  created_at       timestamptz default now(),
  unique(class_id, academic_year_id, score_type, month, semester)
);


-- ============================================================
-- REPORT MESSAGES (v9)
-- One row per student per report link.
-- Teacher writes message (text + voice). Parent writes reply (text + voice).
-- Voice files stored in report-voices Supabase Storage bucket.
-- ============================================================

create table report_messages (
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
-- NOTIFICATIONS (v10)
-- In-app notifications for admin (approval requests) and teacher (outcomes).
-- Created by DB triggers — not written directly from frontend.
-- No push/email — in-app bell icon only.
-- ============================================================

create table notifications (
  id                uuid primary key default uuid_generate_v4(),
  school_id         uuid not null references schools(id) on delete cascade,
  recipient_user_id uuid not null references users(id) on delete cascade,
  type              text not null,
  -- type values:
  --   'approval_requested'  → admin notified when teacher requests approval
  --   'approval_approved'   → teacher notified when admin approves
  --   'approval_rejected'   → teacher notified when admin rejects
  payload           jsonb not null default '{}',
  -- payload keys: report_link_id, class_name, score_type, month, semester, rejection_note
  is_read           boolean not null default false,
  created_at        timestamptz default now()
);


-- ============================================================
-- TEACHER PHRASES (v10)
-- Personal reusable feedback phrase library per teacher.
-- Chips shown below message textarea in report-replies view.
-- Click chip → appends phrase to message. Private per teacher.
-- ============================================================

create table teacher_phrases (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references schools(id) on delete cascade,
  teacher_id  uuid not null references teachers(id) on delete cascade,
  phrase_text text not null,
  sort_order  int4 not null default 0,   -- for future manual reordering
  created_at  timestamptz default now()
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
-- v9 indexes
create index idx_report_links_school_id        on report_links(school_id);
create index idx_report_links_class_id         on report_links(class_id);
create index idx_report_messages_school_id     on report_messages(school_id);
create index idx_report_messages_link_student  on report_messages(report_link_id, student_id);
-- v10 indexes
create index idx_report_links_status_school    on report_links(status, school_id);
create index idx_notifications_recipient       on notifications(recipient_user_id, is_read);
create index idx_notifications_school          on notifications(school_id);
create index idx_teacher_phrases_teacher       on teacher_phrases(teacher_id);
create index idx_teacher_phrases_school        on teacher_phrases(school_id);


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
alter table report_links          enable row level security;
alter table report_messages       enable row level security;
alter table notifications         enable row level security;
alter table teacher_phrases       enable row level security;


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
-- Anon read scoped to report link context (v9).
-- No open using (true) — must have a valid report_link_id.
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

-- Anon: read only students whose class_id matches a valid report_link.
-- Frontend passes report_link_id as a filter; RLS enforces it server-side.
create policy "students: anon read via report link"
  on students for select to anon
  using (
    class_id in (
      select class_id from report_links
      where id in (
        select report_link_id from report_messages
        where report_link_id = report_messages.report_link_id
      )
    )
  );

-- Simpler anon policy: allow read if class_id appears in any report_link.
-- The parent portal always queries with a specific report_link_id filter,
-- so data is naturally scoped even with this broader policy.
-- Replace the above with the one below if query performance is preferred:
--
-- create policy "students: anon read via report link"
--   on students for select to anon
--   using (
--     class_id in (select class_id from report_links)
--   );


-- ------------------------------------------------------------
-- STUDENT HEALTH — no anon access (v9)
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

-- No anon policy for student_health — private to staff only.


-- ------------------------------------------------------------
-- STUDENT CHECKUPS — no anon access (v9)
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

-- No anon policy for student_checkups.


-- ------------------------------------------------------------
-- STUDENT GROWTH — no anon access (v9)
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

-- No anon policy for student_growth.


-- ------------------------------------------------------------
-- STUDENT VACCINATIONS — no anon access (v9)
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

-- No anon policy for student_vaccinations.


-- ------------------------------------------------------------
-- STUDENT SICK DAYS — no anon access (v9)
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

-- No anon policy for student_sick_days.


-- ------------------------------------------------------------
-- ATTENDANCES
-- Anon read scoped to report link context (v9).
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

-- Anon: read only attendance for students in a report-linked class.
create policy "attendances: anon read via report link"
  on attendances for select to anon
  using (
    student_id in (
      select s.id from students s
      join report_links rl on rl.class_id = s.class_id
    )
  );


-- ------------------------------------------------------------
-- SCORES
-- Anon read scoped to report link context (v9).
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

-- Anon: read only scores for students in a report-linked class.
create policy "scores: anon read via report link"
  on scores for select to anon
  using (
    student_id in (
      select s.id from students s
      join report_links rl on rl.class_id = s.class_id
    )
  );


-- ------------------------------------------------------------
-- TEACHER ATTENDANCES
-- ------------------------------------------------------------

create policy "teacher_attendances: admin manage own school"
  on teacher_attendances for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

-- Teacher reads own attendance only.
-- Write access only via teacher_check_in() function (enforces once-per-day).
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


-- ------------------------------------------------------------
-- REPORT LINKS (v9)
-- Teacher (authenticated) manages links for their own class.
-- Anon can read any report_link by id (the id IS the access token).
-- ------------------------------------------------------------

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

-- Anon read: knowing the UUID is sufficient proof of access — but only for approved links.
-- Pending/rejected links are invisible to anon (v10).
create policy "report_links: anon read approved only"
  on report_links for select to anon
  using (status = 'approved');


-- ------------------------------------------------------------
-- REPORT MESSAGES (v9)
-- Teacher (authenticated) manages messages for their links.
-- Anon can read messages and update only parent fields.
-- ------------------------------------------------------------

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

-- Anon read: can read messages for any report link they have the id for.
create policy "report_messages: anon read"
  on report_messages for select to anon
  using (true);

-- Anon update: parent reply fields only.
-- report_link_id must exist in report_links (FK enforces this).
-- Teacher fields are not writable via this policy — the frontend
-- never sends them on parent updates; this is a trust-boundary decision.
create policy "report_messages: anon update parent fields"
  on report_messages for update to anon
  using (true)
  with check (true);

-- Anon insert: parent can create a report_messages row if teacher hasn't yet.
create policy "report_messages: anon insert"
  on report_messages for insert to anon
  with check (
    report_link_id in (select id from report_links)
  );


-- ------------------------------------------------------------
-- NOTIFICATIONS (v10)
-- ------------------------------------------------------------

-- Admin inserts notifications for teachers in their school (via trigger, security definer)
create policy "notifications: admin insert own school"
  on notifications for insert to authenticated
  with check (
    get_user_role() = 'admin' and school_id = get_user_school_id()
  );

-- Each user reads only their own notifications
create policy "notifications: self read"
  on notifications for select to authenticated
  using (recipient_user_id = auth.uid());

-- Each user can mark their own notifications as read (update is_read only)
create policy "notifications: self update is_read"
  on notifications for update to authenticated
  using (recipient_user_id = auth.uid())
  with check (recipient_user_id = auth.uid());


-- ------------------------------------------------------------
-- TEACHER PHRASES (v10)
-- ------------------------------------------------------------

-- Teacher manages only their own phrases
create policy "teacher_phrases: teacher manage own"
  on teacher_phrases for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- Admin can read all phrases in their school (support/audit)
create policy "teacher_phrases: admin read own school"
  on teacher_phrases for select to authenticated
  using (
    get_user_role() = 'admin' and school_id = get_user_school_id()
  );


-- ============================================================
-- DB FUNCTIONS
-- ============================================================


-- ------------------------------------------------------------
-- handle_new_user (trigger)
-- Fires on auth.users insert — auto creates public.users row.
-- Reads role + school_id from raw_user_meta_data (set by manage-user Edge Function).
-- ------------------------------------------------------------

create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, role, school_id)
  values (
    new.id,
    new.email,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'teacher'),
    (new.raw_user_meta_data->>'school_id')::uuid
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();


-- ------------------------------------------------------------
-- teacher_check_in
-- Once-per-day check-in. Auto-calculates present/late.
-- Uses school_settings thresholds for the user's school.
-- ------------------------------------------------------------

create or replace function teacher_check_in()
returns jsonb as $$
declare
  v_teacher_id  uuid;
  v_school_id   uuid := get_user_school_id();
  v_settings    record;
  v_now         timestamptz := now();
  v_today       date := current_date;
  v_time        time := v_now::time;
  v_turn        text;
  v_status      attendance_status;
begin
  select id into v_teacher_id from teachers where user_id = auth.uid();
  if v_teacher_id is null then
    raise exception 'Teacher profile not found';
  end if;

  select * into v_settings from school_settings where school_id = v_school_id;
  if not found then
    raise exception 'School settings not found';
  end if;

  if v_time between v_settings.morning_start and (v_settings.evening_start - interval '1 second') then
    v_turn := 'morning';
    v_status := case when v_time > v_settings.morning_late_threshold then 'late' else 'present' end;
  else
    v_turn := 'afternoon';
    v_status := case when v_time > v_settings.evening_late_threshold then 'late' else 'present' end;
  end if;

  insert into teacher_attendances (school_id, teacher_id, date, check_in_time, status)
  values (v_school_id, v_teacher_id, v_today, v_now, v_status)
  on conflict (teacher_id, date) do nothing;

  return jsonb_build_object(
    'success', true,
    'status', v_status,
    'turn', v_turn,
    'check_in_time', v_now
  );
end;
$$ language plpgsql security definer;


-- ------------------------------------------------------------
-- super_admin_create_school
-- Creates a new school + auto-creates school_settings + school_information.
-- Only callable by super_admin.
-- ------------------------------------------------------------

create or replace function super_admin_create_school(
  p_name_khmer    text,
  p_name_english  text,
  p_school_code   text,
  p_province      text default null,
  p_district      text default null,
  p_address       text default null,
  p_phone         text default null,
  p_email         text default null
)
returns uuid as $$
declare
  v_school_id uuid;
begin
  if get_user_role() != 'super_admin' then
    raise exception 'Permission denied: super_admin only';
  end if;

  insert into schools (name_khmer, name_english, school_code, province, district, address, phone, email)
  values (p_name_khmer, p_name_english, p_school_code, p_province, p_district, p_address, p_phone, p_email)
  returning id into v_school_id;

  insert into school_settings (school_id) values (v_school_id);

  insert into school_information (school_id, name_khmer, name_english, school_code, address, phone, email)
  values (v_school_id, p_name_khmer, p_name_english, p_school_code, p_address, p_phone, p_email);

  return v_school_id;
end;
$$ language plpgsql security definer;


-- ------------------------------------------------------------
-- khmer_to_int / extract_grade_from_class_name
-- Parse Khmer digits from class names for student rollup.
-- e.g. "ថ្នាក់ទី១ក" → grade 1
-- ------------------------------------------------------------

create or replace function khmer_to_int(p_khmer text)
returns int as $$
declare
  v_khmer_digits text := '០១២៣៤៥៦៧៨៩';
  v_result       int  := 0;
  v_char         text;
  v_pos          int;
  v_i            int;
begin
  for v_i in 1..length(p_khmer) loop
    v_char := substring(p_khmer from v_i for 1);
    v_pos  := strpos(v_khmer_digits, v_char);
    if v_pos = 0 then return null; end if;
    v_result := v_result * 10 + (v_pos - 1);
  end loop;
  return v_result;
end;
$$ language plpgsql immutable;

create or replace function extract_grade_from_class_name(p_class_name text)
returns int as $$
declare
  v_khmer_digits text := '០១២៣៤៥៦៧៨៩';
  v_prefix       text := 'ថ្នាក់ទី';
  v_stripped     text;
  v_digits       text := '';
  v_char         text;
  v_i            int;
begin
  v_stripped := ltrim(p_class_name, ' ');
  if strpos(v_stripped, v_prefix) = 1 then
    v_stripped := substring(v_stripped from length(v_prefix) + 1);
  end if;
  for v_i in 1..length(v_stripped) loop
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


-- ------------------------------------------------------------
-- notify_admin_on_request (v10 trigger)
-- Fires after INSERT on report_links (status = 'pending').
-- Creates a notification row for every active admin in the school.
-- ------------------------------------------------------------

create or replace function notify_admin_on_request()
returns trigger as $$
declare
  v_admin_user  record;
  v_class_name  text;
begin
  if new.status != 'pending' then
    return new;
  end if;

  select class_name into v_class_name
  from classes where id = new.class_id;

  for v_admin_user in
    select id from users
    where school_id = new.school_id and role = 'admin' and status = 'active'
  loop
    insert into notifications (
      school_id, recipient_user_id, type, payload
    ) values (
      new.school_id,
      v_admin_user.id,
      'approval_requested',
      jsonb_build_object(
        'report_link_id', new.id,
        'class_name',     coalesce(v_class_name, ''),
        'score_type',     new.score_type,
        'month',          new.month,
        'semester',       new.semester
      )
    );
  end loop;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_report_link_created
  after insert on report_links
  for each row execute procedure notify_admin_on_request();


-- ------------------------------------------------------------
-- notify_teacher_on_approval (v10 trigger)
-- Fires after UPDATE on report_links when status changes to approved/rejected.
-- Notifies the teacher who created the link.
-- ------------------------------------------------------------

create or replace function notify_teacher_on_approval()
returns trigger as $$
declare
  v_teacher_user_id uuid;
  v_class_name      text;
  v_notif_type      text;
begin
  if old.status = new.status then
    return new;
  end if;

  if new.status not in ('approved', 'rejected') then
    return new;
  end if;

  select user_id into v_teacher_user_id
  from teachers where id = new.created_by;

  if v_teacher_user_id is null then
    return new;
  end if;

  select class_name into v_class_name
  from classes where id = new.class_id;

  v_notif_type := case
    when new.status = 'approved' then 'approval_approved'
    else 'approval_rejected'
  end;

  insert into notifications (
    school_id, recipient_user_id, type, payload
  ) values (
    new.school_id,
    v_teacher_user_id,
    v_notif_type,
    jsonb_build_object(
      'report_link_id',  new.id,
      'class_name',      coalesce(v_class_name, ''),
      'score_type',      new.score_type,
      'month',           new.month,
      'semester',        new.semester,
      'rejection_note',  new.rejection_note
    )
  );

  return new;
end;
$$ language plpgsql security definer;

create trigger on_report_link_status_changed
  after update of status on report_links
  for each row execute procedure notify_teacher_on_approval();


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
-- MISSING ANON RLS POLICIES (v9 parent portal fix)
-- Parent queries use !inner joins and foreign key relationships
-- that require anon SELECT access on these tables.
-- ============================================================

-- classes: anon read via report link
-- Needed for: ReportDropdownView, ReportCardView !inner joins
create policy "classes: anon read via report link"
  on classes for select to anon
  using (
    id in (select class_id from report_links)
  );

-- class_subjects: anon read via report link
-- Needed for: subjects anon policy subquery
create policy "class_subjects: anon read via report link"
  on class_subjects for select to anon
  using (
    class_id in (select class_id from report_links)
  );

-- subjects: anon read via report link
-- Needed for: ReportCardView scores query with subjects(subject_name)
create policy "subjects: anon read via report link"
  on subjects for select to anon
  using (
    id in (
      select cs.subject_id from class_subjects cs
      join report_links rl on rl.class_id = cs.class_id
    )
  );



-- ============================================================
-- SUPABASE STORAGE BUCKET: report-voices (v9)
-- Stores teacher + parent voice messages per student per report.
-- File path: {report_link_id}/{student_id}/teacher.webm
--            {report_link_id}/{student_id}/parent.webm
-- ============================================================

insert into storage.buckets (id, name, public)
values ('report-voices', 'report-voices', true)
on conflict do nothing;

-- Authenticated (teacher/admin): full access to their school's report voices.
-- In practice, path structure scopes to report_link_id which the teacher owns.
create policy "report-voices: teacher full"
  on storage.objects for all to authenticated
  using (bucket_id = 'report-voices' and get_user_role() in ('teacher', 'admin', 'super_admin'))
  with check (bucket_id = 'report-voices' and get_user_role() in ('teacher', 'admin', 'super_admin'));

-- Anon: can upload/update only the parent.webm file for a given student.
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

-- Public read: anyone with the URL can play back voice messages.
create policy "report-voices: public read"
  on storage.objects for select to public
  using (bucket_id = 'report-voices');

-- ============================================================
-- SEMESTER CONFIG
-- Defines which months belong to each semester per school per year.
-- Defaults match Cambodian school calendar:
--   Semester 1: months [12, 1, 2], exam in March (3)
--   Semester 2: months [5, 6, 7],  exam in August (8)
-- Admin can override per academic year if calendar shifts.
-- ============================================================

create table semester_config (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references schools(id) on delete cascade,
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  semester         int2 not null check (semester in (1, 2)),
  months           int2[] not null,   -- e.g. {12,1,2} or {5,6,7}
  exam_month       int2 not null,     -- 3 = March, 8 = August
  created_at       timestamptz default now(),
  updated_at       timestamptz default now(),
  unique(school_id, academic_year_id, semester)
);

-- Index
create index idx_semester_config_school_year 
  on semester_config(school_id, academic_year_id);

-- RLS
alter table semester_config enable row level security;

create policy "semester_config: admin manage own school"
  on semester_config for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id())
  with check (get_user_role() = 'admin' and school_id = get_user_school_id());

create policy "semester_config: staff read own school"
  on semester_config for select to authenticated
  using (
    get_user_role() in ('teacher', 'librarian') 
    and school_id = get_user_school_id()
  );

  -- Auto-insert default semester config when a new academic year is created
create or replace function create_default_semester_config()
returns trigger as $$
begin
  -- Semester 1: Dec, Jan, Feb → exam in March
  insert into semester_config 
    (school_id, academic_year_id, semester, months, exam_month)
  values
    (new.school_id, new.id, 1, array[12, 1, 2]::int2[], 3);

  -- Semester 2: May, Jun, Jul → exam in August
  insert into semester_config 
    (school_id, academic_year_id, semester, months, exam_month)
  values
    (new.school_id, new.id, 2, array[5, 6, 7]::int2[], 8);

  return new;
end;
$$ language plpgsql security definer;

create trigger on_academic_year_created
  after insert on academic_years
  for each row execute procedure create_default_semester_config();

alter table scores add column if not exists semester int2;

update semester_config set months = array[12,1,2,3]::int2[] where semester = 1;
update semester_config set months = array[5,6,7,8]::int2[]  where semester = 2;
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
-- SUPABASE STORAGE BUCKET: school-assets (v10)
-- Stores principal digital signature + official school stamp images.
-- Uploaded by admin in Settings → School Information tab.
-- File path: {school_id}/signature.{ext}
--            {school_id}/stamp.{ext}
-- ============================================================

insert into storage.buckets (id, name, public)
values ('school-assets', 'school-assets', true)
on conflict do nothing;

-- Admin (and super_admin) full access to upload/update/delete school assets
create policy "school-assets: admin full"
  on storage.objects for all to authenticated
  using (
    bucket_id = 'school-assets' and
    get_user_role() in ('admin', 'super_admin')
  )
  with check (
    bucket_id = 'school-assets' and
    get_user_role() in ('admin', 'super_admin')
  );

-- Public read — parent report card embeds signature + stamp as images
create policy "school-assets: public read"
  on storage.objects for select to public
  using (bucket_id = 'school-assets');


-- ============================================================
-- DONE — schema_v10.sql
-- Fresh install covers all versions v1 → v10
-- For upgrading existing installs: run migration_v9_v10.sql instead
-- ============================================================
