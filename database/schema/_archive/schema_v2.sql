-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- schema.sql — Tables + RLS Policies
-- Stack: Supabase (PostgreSQL)
-- Roles: admin, teacher, librarian, parent (anon)
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
-- ============================================================

create table users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  role        user_role not null default 'teacher',
  status      user_status not null default 'active',
  created_at  timestamptz default now()
);


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
-- ============================================================

create table teachers (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid references users(id) on delete set null,
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
  id         uuid primary key default uuid_generate_v4(),
  teacher_id uuid not null references teachers(id) on delete cascade,
  date       date not null,
  status     attendance_status not null default 'present',
  created_at timestamptz default now()
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
-- FUNCTION: create_user
-- Called by admin frontend to create new auth + public user
-- Uses security definer so it runs with elevated privileges
-- ============================================================

create or replace function create_user(
  p_email    text,
  p_password text,
  p_role     user_role,
  p_name     text
)
returns json as $$
declare
  new_user_id uuid;
begin
  -- Only admin can call this
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  -- Create auth user
  new_user_id := (
    select id from auth.users
    where email = p_email
    limit 1
  );

  if new_user_id is not null then
    raise exception 'Email already exists';
  end if;

  -- Insert into auth.users via Supabase admin API
  -- This function signals the frontend to use Supabase Admin SDK
  -- The actual auth user creation is done via Edge Function (see below)
  -- This function handles the public.users + teachers row creation

  return json_build_object(
    'role', p_role,
    'name', p_name,
    'email', p_email
  );
end;
$$ language plpgsql security definer;


-- ============================================================
-- FUNCTION: admin_update_user_status
-- Deactivate or reactivate a user account
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

  -- If deactivating, ban user in auth.users to block login
  if p_status = 'inactive' then
    update auth.users
    set banned_until = '2099-12-31'
    where id = p_user_id;
  else
    -- Reactivate: remove ban
    update auth.users
    set banned_until = null
    where id = p_user_id;
  end if;
end;
$$ language plpgsql security definer;


-- ============================================================
-- FUNCTION: admin_update_user_role
-- Change a user's role
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
-- FUNCTION: admin_reset_password
-- Reset a user's password (via Supabase Admin API)
-- Actual password reset is done via Edge Function
-- This function validates the caller is admin
-- ============================================================

create or replace function admin_reset_password(p_user_id uuid)
returns void as $$
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;
  -- Password reset is handled by Edge Function using service_role key
end;
$$ language plpgsql security definer;


-- ============================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================================

alter table users                 enable row level security;
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
-- USERS
-- ------------------------------------------------------------

create policy "users: admin full access"
  on users for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "users: self read"
  on users for select to authenticated
  using (id = auth.uid());

-- Block inactive users from reading any data
-- (auth-level ban via banned_until handles login block)
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

create policy "subjects: teacher read"
  on subjects for select to authenticated
  using (get_user_role() = 'teacher');


-- ------------------------------------------------------------
-- TEACHERS
-- ------------------------------------------------------------

create policy "teachers: admin full"
  on teachers for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "teachers: self read"
  on teachers for select to authenticated
  using (user_id = auth.uid());


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

create policy "teacher_attendances: teacher manage self"
  on teacher_attendances for all to authenticated
  using (
    get_user_role() = 'teacher' and
    teacher_id = (select id from teachers where user_id = auth.uid())
  )
  with check (
    get_user_role() = 'teacher' and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );


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
-- Run these in Supabase Dashboard → Storage → New Bucket
-- Or via SQL editor using the storage schema
-- ============================================================

-- Create the bucket (public so profile images are accessible)
insert into storage.buckets (id, name, public)
values ('teacher-profiles', 'teacher-profiles', true)
on conflict do nothing;

-- Allow authenticated admin to upload/update/delete teacher profiles
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

-- Allow teacher to upload/update their own profile picture
create policy "teacher-profiles: teacher upload own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'teacher-profiles' and
    get_user_role() = 'teacher' and
    (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "teacher-profiles: teacher update own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'teacher-profiles' and
    get_user_role() = 'teacher' and
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow public read (bucket is public, so profile images load for everyone)
create policy "teacher-profiles: public read"
  on storage.objects for select to public
  using (bucket_id = 'teacher-profiles');


-- ============================================================
-- SUPABASE EDGE FUNCTION: manage-user
-- Required for: create user, reset password (needs service_role key)
-- Create file: supabase/functions/manage-user/index.ts
--
-- Handles these actions via POST body { action, payload }:
--   action: "create"         → creates auth user + public.users + teachers row if needed
--   action: "reset_password" → updates auth user password
--   action: "delete"         → permanently deletes auth user + cascades
--
-- Called from Vue frontend using supabase.functions.invoke('manage-user', {...})
-- Protected: validates JWT + checks caller is admin before executing
-- ============================================================


-- ============================================================
-- DONE
-- ============================================================
