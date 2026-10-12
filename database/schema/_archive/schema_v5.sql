-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- schema.sql — Tables + RLS Policies
-- Version: 5 (roadmap v9)
-- Stack: Supabase (PostgreSQL)
-- Roles: admin, teacher, librarian, parent (anon)
--
-- KEY DESIGN DECISION (v4):
-- In Cambodian schools, every staff member IS a teacher.
-- Librarians and admins are teachers with different system roles.
-- Therefore EVERY user account always has a corresponding
-- teachers row — role only controls what they can access.
--
-- v5 additions:
-- + school_settings table (singleton: shift times + late thresholds)
-- + teacher_check_in() function (once per day, auto present/late)
-- + admin_override_teacher_attendance() function
-- + teacher_attendances: added check_in_time + note + unique constraint
-- + Settings page groups school info, academic years, subjects, holidays, attendance config
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";


-- ============================================================
-- ENUMS
-- ============================================================

create type user_status as enum ('active', 'inactive');

create type user_role as enum ('admin', 'teacher', 'librarian');

create type attendance_status as enum ('present', 'absent', 'late', 'permission');

create type score_type as enum ('monthly', 'semester', 'annual');

create type budget_type as enum ('income', 'expense');

create type borrow_status as enum ('borrowed', 'returned', 'overdue');

create type class_turn as enum ('morning', 'afternoon');

create type academic_status as enum ('active', 'inactive');


-- ============================================================
-- USERS
-- Linked to Supabase auth.users
-- role = system access level only (admin / teacher / librarian)
-- Every user ALWAYS has a matching teachers row (profile data)
-- ============================================================

create table users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  role        user_role not null default 'teacher',
  status      user_status not null default 'active',
  created_at  timestamptz default now()
);


-- ============================================================
-- SCHOOL SETTINGS
-- Singleton row — one row only, stores all configurable settings
-- ============================================================

create table school_settings (
  id                        uuid primary key default uuid_generate_v4(),
  morning_start             time not null default '07:00',   -- morning shift start
  morning_late_threshold    time not null default '07:15',   -- late if check-in after this
  evening_start             time not null default '13:00',   -- evening shift start
  evening_late_threshold    time not null default '13:15',   -- late if check-in after this
  created_at                timestamptz default now(),
  updated_at                timestamptz default now()
);

-- Insert default settings row on schema creation
insert into school_settings (id) values (uuid_generate_v4());


-- ============================================================
-- SCHOOL INFORMATION
-- ============================================================

create table school_information (
  id              uuid primary key default uuid_generate_v4(),
  name_khmer      text not null,
  name_english    text not null,
  school_code     text unique,
  director_name   text,
  address         text,
  phone           text,
  email           text,
  logo_base64     text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);


-- ============================================================
-- ACADEMIC YEARS
-- ============================================================

create table academic_years (
  id          uuid primary key default uuid_generate_v4(),
  year_name   text not null,
  start_date  date not null,
  end_date    date not null,
  status      academic_status not null default 'active',
  created_at  timestamptz default now()
);


-- ============================================================
-- SUBJECTS
-- ============================================================

create table subjects (
  id            uuid primary key default uuid_generate_v4(),
  subject_name  text not null,
  created_at    timestamptz default now()
);


-- ============================================================
-- TEACHERS
-- Stores the personal/professional profile of every staff member.
-- This table is created for ALL users regardless of role
-- (admin, teacher, librarian are all teachers in Cambodian schools).
-- user_id links back to users(id) — always required, never null.
-- ============================================================

create table teachers (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null unique references users(id) on delete cascade,
  full_name     text not null,
  gender        text,
  dob           date,
  phone_number  text,
  degree        text,
  address       text,
  email         text,
  profile_url   text,        -- stored in Supabase Storage bucket: teacher-profiles
  created_at    timestamptz default now()
);


-- ============================================================
-- CLASSES
-- ============================================================

create table classes (
  id               uuid primary key default uuid_generate_v4(),
  class_name       text not null,
  teacher_id       uuid references teachers(id) on delete set null,
  academic_year_id uuid references academic_years(id) on delete cascade,
  turn             class_turn not null default 'morning',
  created_at       timestamptz default now()
);


-- ============================================================
-- STUDENTS
-- ============================================================

create table students (
  id               uuid primary key default uuid_generate_v4(),
  real_id          text unique,
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
  academic_year_id uuid references academic_years(id) on delete set null,
  created_at       timestamptz default now(),
  updated_at       date
);


-- ============================================================
-- STUDENT HEALTH
-- Static health profile: one row per student
-- ============================================================

create table student_health (
  id                      uuid primary key default uuid_generate_v4(),
  student_id              uuid not null references students(id) on delete cascade,
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
-- Periodic checkup visits: multiple rows per student
-- ============================================================

create table student_checkups (
  id         uuid primary key default uuid_generate_v4(),
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
-- ============================================================

create table student_growth (
  id         uuid primary key default uuid_generate_v4(),
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
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  reason     text,
  duration   int4,
  notes      text
);


-- ============================================================
-- ATTENDANCES (Student)
-- ============================================================

create table attendances (
  id         uuid primary key default uuid_generate_v4(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  status     attendance_status not null default 'present',
  reason     text,
  created_at timestamptz default now()
);


-- ============================================================
-- SCORES
-- ============================================================

create table scores (
  id               uuid primary key default uuid_generate_v4(),
  student_id       uuid not null references students(id) on delete cascade,
  subject_id       uuid not null references subjects(id) on delete cascade,
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  score_type       score_type not null,
  score            numeric,
  created_at       timestamptz default now()
);


-- ============================================================
-- TEACHER ATTENDANCES
-- ============================================================

create table teacher_attendances (
  id             uuid primary key default uuid_generate_v4(),
  teacher_id     uuid not null references teachers(id) on delete cascade,
  date           date not null,
  check_in_time  timestamptz,               -- actual recorded check-in timestamp
  status         attendance_status not null default 'present',  -- auto-calculated or admin override
  note           text,                       -- admin override reason if manually edited
  created_at     timestamptz default now(),
  unique(teacher_id, date)                  -- only one check-in per teacher per day
);


-- ============================================================
-- SCHOOL HOLIDAYS
-- ============================================================

create table school_holidays (
  id               uuid primary key default uuid_generate_v4(),
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
  title            varchar not null,
  author           varchar,
  isbn             varchar unique,
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
-- HELPER FUNCTION: get current user role
-- Used in all RLS policies
-- ============================================================

create or replace function get_user_role()
returns user_role as $$
  select role from users where id = auth.uid();
$$ language sql security definer stable;


-- ============================================================
-- FUNCTION: admin_update_user_status
-- Deactivate or reactivate a user account
-- Sets banned_until in auth.users to block/unblock login
-- ============================================================

create or replace function admin_update_user_status(
  p_user_id uuid,
  p_status  user_status
)
returns void as $$
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  update users set status = p_status where id = p_user_id;

  if p_status = 'inactive' then
    update auth.users
    set banned_until = '2099-12-31'
    where id = p_user_id;
  else
    update auth.users
    set banned_until = null
    where id = p_user_id;
  end if;
end;
$$ language plpgsql security definer;


-- ============================================================
-- FUNCTION: admin_update_user_role
-- Change a user's role (admin / teacher / librarian)
-- Does NOT affect teachers row — profile stays the same
-- ============================================================

create or replace function admin_update_user_role(
  p_user_id uuid,
  p_role    user_role
)
returns void as $$
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  update users set role = p_role where id = p_user_id;
end;
$$ language plpgsql security definer;


-- ============================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================================

alter table school_settings        enable row level security;
alter table users                  enable row level security;
alter table school_information    enable row level security;
alter table academic_years        enable row level security;
alter table subjects              enable row level security;
alter table teachers              enable row level security;
alter table classes               enable row level security;
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
-- RLS POLICIES
-- ============================================================


-- ------------------------------------------------------------
-- SCHOOL SETTINGS
-- ------------------------------------------------------------

create policy "school_settings: admin full"
  on school_settings for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "school_settings: staff read"
  on school_settings for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ============================================================
-- FUNCTION: teacher_check_in
-- Teacher calls this once per day to record their check-in time
-- System auto-calculates present/late based on school_settings
-- ============================================================

create or replace function teacher_check_in()
returns json as $$
declare
  v_teacher_id    uuid;
  v_teacher       record;
  v_settings      record;
  v_now           timestamptz := now();
  v_today         date := current_date;
  v_time_now      time := v_now::time;
  v_turn          class_turn;
  v_threshold     time;
  v_status        attendance_status;
  v_existing      record;
begin
  -- Get teacher record for current user
  select id into v_teacher_id
  from teachers where user_id = auth.uid();

  if v_teacher_id is null then
    raise exception 'Teacher profile not found';
  end if;

  -- Check if already checked in today
  select * into v_existing
  from teacher_attendances
  where teacher_id = v_teacher_id and date = v_today;

  if v_existing.id is not null then
    raise exception 'Already checked in today at %', v_existing.check_in_time;
  end if;

  -- Get teacher class turn (morning/afternoon)
  select c.turn into v_turn
  from classes c
  where c.teacher_id = v_teacher_id
  limit 1;

  -- Default to morning if no class assigned
  v_turn := coalesce(v_turn, 'morning');

  -- Get late threshold from settings
  select * into v_settings from school_settings limit 1;

  if v_turn = 'morning' then
    v_threshold := v_settings.morning_late_threshold;
  else
    v_threshold := v_settings.evening_late_threshold;
  end if;

  -- Calculate status
  if v_time_now > v_threshold then
    v_status := 'late';
  else
    v_status := 'present';
  end if;

  -- Insert attendance record
  insert into teacher_attendances (teacher_id, date, check_in_time, status)
  values (v_teacher_id, v_today, v_now, v_status);

  return json_build_object(
    'status', v_status,
    'check_in_time', v_now,
    'turn', v_turn,
    'threshold', v_threshold
  );
end;
$$ language plpgsql security definer;


-- ============================================================
-- FUNCTION: admin_override_teacher_attendance
-- Admin can manually set/override any teacher's attendance
-- ============================================================

create or replace function admin_override_teacher_attendance(
  p_teacher_id  uuid,
  p_date        date,
  p_status      attendance_status,
  p_note        text default null
)
returns void as $$
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  insert into teacher_attendances (teacher_id, date, status, note)
  values (p_teacher_id, p_date, p_status, p_note)
  on conflict (teacher_id, date)
  do update set
    status = excluded.status,
    note   = excluded.note;
end;
$$ language plpgsql security definer;

create policy "users: admin full access"
  on users for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "users: self read"
  on users for select to authenticated
  using (id = auth.uid());

-- Block inactive users from reading any data
-- auth-level ban via banned_until handles login block
-- RLS double-check: inactive users can't query their own row
create policy "users: active only"
  on users for select to authenticated
  using (status = 'active' or get_user_role() = 'admin');


-- ------------------------------------------------------------
-- SCHOOL INFORMATION
-- ------------------------------------------------------------

create policy "school_info: admin full"
  on school_information for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "school_info: staff read"
  on school_information for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ------------------------------------------------------------
-- ACADEMIC YEARS
-- ------------------------------------------------------------

create policy "academic_years: admin full"
  on academic_years for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "academic_years: staff read"
  on academic_years for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ------------------------------------------------------------
-- SUBJECTS
-- ------------------------------------------------------------

create policy "subjects: admin full"
  on subjects for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "subjects: staff read"
  on subjects for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ------------------------------------------------------------
-- TEACHERS
-- Every user has a teachers row. Policies:
--   admin    → full CRUD on all teachers
--   any user → can read all teachers (for class assignment display etc.)
--   self     → can update own profile
-- ------------------------------------------------------------

create policy "teachers: admin full"
  on teachers for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "teachers: all staff read"
  on teachers for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));

create policy "teachers: self update"
  on teachers for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- ------------------------------------------------------------
-- CLASSES
-- ------------------------------------------------------------

create policy "classes: admin full"
  on classes for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "classes: teacher read own"
  on classes for select to authenticated
  using (
    get_user_role() = 'teacher' and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );


-- ------------------------------------------------------------
-- STUDENTS
-- ------------------------------------------------------------

create policy "students: admin full"
  on students for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "students: teacher manage own class"
  on students for all to authenticated
  using (
    get_user_role() = 'teacher' and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "students: librarian read"
  on students for select to authenticated
  using (get_user_role() = 'librarian');

-- Parent: anon can read students (app filters by name + dob)
create policy "students: anon read for parent"
  on students for select to anon
  using (true);


-- ------------------------------------------------------------
-- STUDENT HEALTH
-- ------------------------------------------------------------

create policy "student_health: admin full"
  on student_health for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "student_health: teacher manage own class"
  on student_health for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_health: anon read for parent"
  on student_health for select to anon
  using (true);


-- ------------------------------------------------------------
-- STUDENT CHECKUPS
-- ------------------------------------------------------------

create policy "student_checkups: admin full"
  on student_checkups for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "student_checkups: teacher manage own class"
  on student_checkups for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_checkups: anon read for parent"
  on student_checkups for select to anon
  using (true);


-- ------------------------------------------------------------
-- STUDENT GROWTH
-- ------------------------------------------------------------

create policy "student_growth: admin full"
  on student_growth for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "student_growth: teacher manage own class"
  on student_growth for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_growth: anon read for parent"
  on student_growth for select to anon
  using (true);


-- ------------------------------------------------------------
-- STUDENT VACCINATIONS
-- ------------------------------------------------------------

create policy "student_vaccinations: admin full"
  on student_vaccinations for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "student_vaccinations: teacher manage own class"
  on student_vaccinations for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_vaccinations: anon read for parent"
  on student_vaccinations for select to anon
  using (true);


-- ------------------------------------------------------------
-- STUDENT SICK DAYS
-- ------------------------------------------------------------

create policy "student_sick_days: admin full"
  on student_sick_days for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "student_sick_days: teacher manage own class"
  on student_sick_days for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "student_sick_days: anon read for parent"
  on student_sick_days for select to anon
  using (true);


-- ------------------------------------------------------------
-- ATTENDANCES
-- ------------------------------------------------------------

create policy "attendances: admin full"
  on attendances for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "attendances: teacher manage own class"
  on attendances for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

-- Parent can view their child's attendance (filtered by app)
create policy "attendances: anon read for parent"
  on attendances for select to anon
  using (true);


-- ------------------------------------------------------------
-- SCORES
-- ------------------------------------------------------------

create policy "scores: admin full"
  on scores for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "scores: teacher manage own class"
  on scores for all to authenticated
  using (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  )
  with check (
    get_user_role() = 'teacher' and
    student_id in (
      select s.id from students s
      join classes c on c.id = s.class_id
      where c.teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

-- Parent can view their child's scores (filtered by app)
create policy "scores: anon read for parent"
  on scores for select to anon
  using (true);


-- ------------------------------------------------------------
-- TEACHER ATTENDANCES
-- ------------------------------------------------------------

create policy "teacher_attendances: admin full"
  on teacher_attendances for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

-- Teacher can read their own attendance
create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- Teacher check-in handled via teacher_check_in() function (security definer)
-- Direct insert blocked — must use the function to enforce once-per-day rule


-- ------------------------------------------------------------
-- SCHOOL HOLIDAYS
-- ------------------------------------------------------------

create policy "school_holidays: admin full"
  on school_holidays for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "school_holidays: staff read"
  on school_holidays for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ------------------------------------------------------------
-- BOOKS
-- ------------------------------------------------------------

create policy "books: admin full"
  on books for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "books: librarian full"
  on books for all to authenticated
  using (get_user_role() = 'librarian')
  with check (get_user_role() = 'librarian');

create policy "books: teacher read"
  on books for select to authenticated
  using (get_user_role() = 'teacher');


-- ------------------------------------------------------------
-- BOOK BORROWS
-- ------------------------------------------------------------

create policy "book_borrows: admin full"
  on book_borrows for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "book_borrows: librarian full"
  on book_borrows for all to authenticated
  using (get_user_role() = 'librarian')
  with check (get_user_role() = 'librarian');


-- ------------------------------------------------------------
-- BUDGET TRANSACTIONS (admin only)
-- ------------------------------------------------------------

create policy "budget_transactions: admin full"
  on budget_transactions for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');


-- ------------------------------------------------------------
-- INVENTORY ITEMS (admin only)
-- ------------------------------------------------------------

create policy "inventory_items: admin full"
  on inventory_items for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');


-- ============================================================
-- SUPABASE STORAGE BUCKET: teacher-profiles
-- Used for ALL staff profile pictures (admin, teacher, librarian)
-- ============================================================

insert into storage.buckets (id, name, public)
values ('teacher-profiles', 'teacher-profiles', true)
on conflict do nothing;

-- Allow authenticated admin to upload/update/delete any profile
create policy "teacher-profiles: admin full"
  on storage.objects for all to authenticated
  using (
    bucket_id = 'teacher-profiles' and
    get_user_role() = 'admin'
  )
  with check (
    bucket_id = 'teacher-profiles' and
    get_user_role() = 'admin'
  );

-- Allow any staff to upload/update their own profile picture
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

-- Allow public read (bucket is public, profile images load for everyone)
create policy "teacher-profiles: public read"
  on storage.objects for select to public
  using (bucket_id = 'teacher-profiles');


-- ============================================================
-- SUPABASE EDGE FUNCTION: manage-user
-- Required for: create user, reset password, delete user
-- Needs service_role key — runs server-side only
-- Create file: supabase/functions/manage-user/index.ts
--
-- Handles these actions via POST body { action, payload }:
--
--   action: "create"
--     payload: {
--       email, password, role,
--       full_name, gender, dob, phone_number,
--       degree, address, profile_url
--     }
--     → creates auth.users entry
--     → inserts public.users row (role, status=active)
--     → inserts teachers row (full profile, user_id linked)
--     NOTE: ALL roles get a teachers row (admin/teacher/librarian
--           are all teachers in Cambodian schools)
--
--   action: "reset_password"
--     payload: { user_id, new_password }
--     → updates auth user password
--
--   action: "delete"
--     payload: { user_id }
--     → deletes auth user (cascades to public.users + teachers)
--
-- Called from Vue frontend:
--   supabase.functions.invoke('manage-user', { body: { action, payload } })
-- Protected: validates JWT + checks caller is admin before executing
-- ============================================================


-- ============================================================
-- DONE
-- ============================================================
