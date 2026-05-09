-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- schema.sql — Tables + RLS Policies
-- Version: 7 (roadmap v12)
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
--
-- v6 additions:
-- + class_subjects junction table (subjects per class, not global)
-- + Solves Grade 1-3 (no English) vs Grade 4-6 (has English) problem
-- + Score entry now fetches subjects via class_subjects, not all subjects
--
-- v7 additions:
-- + students.is_graduated (boolean) — marks Grade 6 graduates
-- + khmer_to_int() helper — converts Khmer numerals to integer
-- + int_to_khmer() helper — converts integer to Khmer numerals
-- + extract_grade_from_class_name() — parses grade from "ថ្នាក់ទី១ក"
-- + perform_student_rollup(old_year_id, new_year_id) — promotes all
--   students to next grade class in new academic year, graduates Grade 6
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
  morning_start             time not null default '07:00',
  morning_late_threshold    time not null default '07:15',
  evening_start             time not null default '13:00',
  evening_late_threshold    time not null default '13:15',
  created_at                timestamptz default now(),
  updated_at                timestamptz default now()
);

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
-- This table is created for ALL users regardless of role.
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
  profile_url   text,
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
-- CLASS SUBJECTS
-- Junction table linking subjects to specific classes.
-- Allows different classes to have different subject sets.
-- e.g. Grade 1-3 no English, Grade 4-6 has English.
-- ============================================================

create table class_subjects (
  id         uuid primary key default uuid_generate_v4(),
  class_id   uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  created_at timestamptz default now(),
  unique(class_id, subject_id)
);


-- ============================================================
-- STUDENTS
-- v7: added is_graduated — set true for Grade 6 after rollup
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
  is_graduated     boolean not null default false,       -- v7: true after Grade 6 rollup
  academic_year_id uuid references academic_years(id) on delete set null,
  created_at       timestamptz default now(),
  updated_at       date
);


-- ============================================================
-- STUDENT HEALTH
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
  notes      text,
  created_at timestamptz default now()
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
  check_in_time  timestamptz,
  status         attendance_status not null default 'present',
  note           text,
  created_at     timestamptz default now(),
  unique(teacher_id, date)
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
-- ============================================================

create or replace function get_user_role()
returns user_role as $$
  select role from users where id = auth.uid();
$$ language sql security definer stable;


-- ============================================================
-- HELPER: Khmer numeral → integer
-- ============================================================

create or replace function khmer_to_int(p_khmer text)
returns int as $$
declare
  v_result text := p_khmer;
begin
  v_result := replace(v_result, '០', '0');
  v_result := replace(v_result, '១', '1');
  v_result := replace(v_result, '២', '2');
  v_result := replace(v_result, '៣', '3');
  v_result := replace(v_result, '៤', '4');
  v_result := replace(v_result, '៥', '5');
  v_result := replace(v_result, '៦', '6');
  v_result := replace(v_result, '៧', '7');
  v_result := replace(v_result, '៨', '8');
  v_result := replace(v_result, '៩', '9');
  return v_result::int;
end;
$$ language plpgsql immutable;


-- ============================================================
-- HELPER: integer → Khmer numeral
-- ============================================================

create or replace function int_to_khmer(p_int int)
returns text as $$
declare
  v_result text := p_int::text;
begin
  v_result := replace(v_result, '0', '០');
  v_result := replace(v_result, '1', '១');
  v_result := replace(v_result, '2', '២');
  v_result := replace(v_result, '3', '៣');
  v_result := replace(v_result, '4', '៤');
  v_result := replace(v_result, '5', '៥');
  v_result := replace(v_result, '6', '៦');
  v_result := replace(v_result, '7', '៧');
  v_result := replace(v_result, '8', '៨');
  v_result := replace(v_result, '9', '៩');
  return v_result;
end;
$$ language plpgsql immutable;


-- ============================================================
-- HELPER: extract grade number from class_name
-- "ថ្នាក់ទី១ក" → 1 | "ថ្នាក់ទី៦ខ" → 6
-- ============================================================

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
    else
      exit;
    end if;
  end loop;

  if v_digits = '' then return null; end if;
  return khmer_to_int(v_digits);
end;
$$ language plpgsql immutable;


-- ============================================================
-- FUNCTION: perform_student_rollup
--
-- Promotes all students from old_year → new_year classes.
-- Matches classes by grade number parsed from class_name.
--
-- Matching rules:
--   Count match  → pair by alphabetical order (២ក→៣ក, ២ខ→៣ខ)
--   1 new class  → merge all old-grade students into it
--   Count mismatch → merge all into first new class (admin can fix)
--   Grade 6      → is_graduated = true, class_id = null
--
-- Returns: jsonb summary with per-grade results
-- ============================================================

create or replace function perform_student_rollup(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb as $$
declare
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

  if not exists (select 1 from academic_years where id = p_old_year_id) then
    raise exception 'Old academic year not found';
  end if;
  if not exists (select 1 from academic_years where id = p_new_year_id) then
    raise exception 'New academic year not found';
  end if;
  if p_old_year_id = p_new_year_id then
    raise exception 'Old and new academic year must be different';
  end if;

  -- Grades 1–5: promote to next grade
  for v_grade in 1..5 loop

    select array_agg(id order by class_name)
    into v_old_classes
    from classes
    where academic_year_id = p_old_year_id
      and extract_grade_from_class_name(class_name) = v_grade;

    v_old_count := coalesce(array_length(v_old_classes, 1), 0);
    if v_old_count = 0 then continue; end if;

    select array_agg(id order by class_name)
    into v_new_classes
    from classes
    where academic_year_id = p_new_year_id
      and extract_grade_from_class_name(class_name) = v_grade + 1;

    v_new_count := coalesce(array_length(v_new_classes, 1), 0);

    if v_new_count = 0 then
      v_summary := v_summary || jsonb_build_object(
        'grade', v_grade, 'action', 'skipped',
        'reason', 'no grade ' || (v_grade + 1) || ' classes in new year',
        'students_moved', 0
      );
      continue;
    end if;

    v_moved := 0;

    if v_new_count = v_old_count then
      -- Pair by order
      for v_i in 1..v_old_count loop
        update students
        set class_id = v_new_classes[v_i], academic_year_id = p_new_year_id
        where class_id = v_old_classes[v_i] and is_graduated = false;
        get diagnostics v_moved = v_moved + row_count;
      end loop;
    else
      -- Merge all into first new class
      update students
      set class_id = v_new_classes[1], academic_year_id = p_new_year_id
      where class_id = any(v_old_classes) and is_graduated = false;
      get diagnostics v_moved = row_count;
    end if;

    v_total_moved := v_total_moved + v_moved;

    v_summary := v_summary || jsonb_build_object(
      'grade', v_grade,
      'action', case when v_new_count = v_old_count then 'paired' else 'merged' end,
      'old_classes', v_old_count,
      'new_classes', v_new_count,
      'students_moved', v_moved
    );

  end loop;

  -- Grade 6: graduate
  select array_agg(id)
  into v_old_classes
  from classes
  where academic_year_id = p_old_year_id
    and extract_grade_from_class_name(class_name) = 6;

  if v_old_classes is not null then
    update students
    set is_graduated = true, class_id = null, academic_year_id = p_new_year_id
    where class_id = any(v_old_classes) and is_graduated = false;
    get diagnostics v_graduated = row_count;
  end if;

  v_summary := v_summary || jsonb_build_object(
    'grade', 6, 'action', 'graduated', 'students_graduated', v_graduated
  );

  return jsonb_build_object(
    'success',         true,
    'old_year_id',     p_old_year_id,
    'new_year_id',     p_new_year_id,
    'total_promoted',  v_total_moved,
    'total_graduated', v_graduated,
    'details',         v_summary
  );
end;
$$ language plpgsql security definer;


-- ============================================================
-- FUNCTION: admin_update_user_status
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
    update auth.users set banned_until = '2099-12-31' where id = p_user_id;
  else
    update auth.users set banned_until = null where id = p_user_id;
  end if;
end;
$$ language plpgsql security definer;


-- ============================================================
-- FUNCTION: admin_update_user_role
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
alter table school_information     enable row level security;
alter table academic_years         enable row level security;
alter table subjects               enable row level security;
alter table teachers               enable row level security;
alter table classes                enable row level security;
alter table class_subjects         enable row level security;
alter table students               enable row level security;
alter table student_health         enable row level security;
alter table student_checkups       enable row level security;
alter table student_growth         enable row level security;
alter table student_vaccinations   enable row level security;
alter table student_sick_days      enable row level security;
alter table attendances            enable row level security;
alter table scores                 enable row level security;
alter table teacher_attendances    enable row level security;
alter table school_holidays        enable row level security;
alter table books                  enable row level security;
alter table book_borrows           enable row level security;
alter table budget_transactions    enable row level security;
alter table inventory_items        enable row level security;


-- ============================================================
-- RLS POLICIES
-- ============================================================

-- SCHOOL SETTINGS
create policy "school_settings: admin full"
  on school_settings for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "school_settings: staff read"
  on school_settings for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));

-- USERS
create policy "users: admin full"
  on users for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "users: self read"
  on users for select to authenticated
  using (id = auth.uid());

-- SCHOOL INFORMATION
create policy "school_information: admin full"
  on school_information for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "school_information: staff read"
  on school_information for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));

create policy "school_information: anon read"
  on school_information for select to anon using (true);

-- ACADEMIC YEARS
create policy "academic_years: admin full"
  on academic_years for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "academic_years: staff read"
  on academic_years for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));

-- SUBJECTS
create policy "subjects: admin full"
  on subjects for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "subjects: staff read"
  on subjects for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));

-- TEACHERS
create policy "teachers: admin full"
  on teachers for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "teachers: self read"
  on teachers for select to authenticated
  using (user_id = auth.uid());

create policy "teachers: self update"
  on teachers for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- CLASSES
create policy "classes: admin full"
  on classes for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "classes: teacher read own"
  on classes for select to authenticated
  using (
    get_user_role() = 'teacher' and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- CLASS SUBJECTS
create policy "class_subjects: admin full"
  on class_subjects for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "class_subjects: teacher read own class"
  on class_subjects for select to authenticated
  using (
    get_user_role() = 'teacher' and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

create policy "class_subjects: librarian read"
  on class_subjects for select to authenticated
  using (get_user_role() = 'librarian');

-- STUDENTS
create policy "students: admin full"
  on students for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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

create policy "students: anon read for parent"
  on students for select to anon using (true);

-- STUDENT HEALTH
create policy "student_health: admin full"
  on student_health for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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
  on student_health for select to anon using (true);

-- STUDENT CHECKUPS
create policy "student_checkups: admin full"
  on student_checkups for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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
  on student_checkups for select to anon using (true);

-- STUDENT GROWTH
create policy "student_growth: admin full"
  on student_growth for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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
  on student_growth for select to anon using (true);

-- STUDENT VACCINATIONS
create policy "student_vaccinations: admin full"
  on student_vaccinations for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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
  on student_vaccinations for select to anon using (true);

-- STUDENT SICK DAYS
create policy "student_sick_days: admin full"
  on student_sick_days for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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
  on student_sick_days for select to anon using (true);

-- ATTENDANCES
create policy "attendances: admin full"
  on attendances for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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

create policy "attendances: anon read for parent"
  on attendances for select to anon using (true);

-- SCORES
create policy "scores: admin full"
  on scores for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

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

create policy "scores: anon read for parent"
  on scores for select to anon using (true);

-- TEACHER ATTENDANCES
create policy "teacher_attendances: admin full"
  on teacher_attendances for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (teacher_id = (select id from teachers where user_id = auth.uid()));

-- SCHOOL HOLIDAYS
create policy "school_holidays: admin full"
  on school_holidays for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "school_holidays: staff read"
  on school_holidays for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));

-- BOOKS
create policy "books: admin full"
  on books for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "books: librarian full"
  on books for all to authenticated
  using (get_user_role() = 'librarian') with check (get_user_role() = 'librarian');

create policy "books: teacher read"
  on books for select to authenticated
  using (get_user_role() = 'teacher');

-- BOOK BORROWS
create policy "book_borrows: admin full"
  on book_borrows for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

create policy "book_borrows: librarian full"
  on book_borrows for all to authenticated
  using (get_user_role() = 'librarian') with check (get_user_role() = 'librarian');

-- BUDGET TRANSACTIONS
create policy "budget_transactions: admin full"
  on budget_transactions for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');

-- INVENTORY ITEMS
create policy "inventory_items: admin full"
  on inventory_items for all to authenticated
  using (get_user_role() = 'admin') with check (get_user_role() = 'admin');


-- ============================================================
-- SUPABASE STORAGE BUCKET: teacher-profiles
-- ============================================================

insert into storage.buckets (id, name, public)
values ('teacher-profiles', 'teacher-profiles', true)
on conflict do nothing;

create policy "teacher-profiles: admin full"
  on storage.objects for all to authenticated
  using (bucket_id = 'teacher-profiles' and get_user_role() = 'admin')
  with check (bucket_id = 'teacher-profiles' and get_user_role() = 'admin');

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

  -- 6. HELPER FUNCTION: clone_classes_structure
--
-- Copies all class definitions (name, turn) from old_year → new_year.
-- Does NOT copy students or teacher assignments (since teachers might change).
-- ============================================================

create or replace function clone_classes_structure(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns int as $$
declare
  v_count int;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  insert into classes (class_name, turn, academic_year_id)
  select class_name, turn, p_new_year_id
  from classes
  where academic_year_id = p_old_year_id
  on conflict do nothing; -- avoid duplicates if already partially set up

  get diagnostics v_count = row_count;
  return v_count;
end;
$$ language plpgsql security definer;



-- ============================================================
-- SUPABASE EDGE FUNCTION: manage-user
-- Handles: create / reset_password / delete
-- Always creates 3 rows: auth.users + public.users + teachers
-- Called from Vue: supabase.functions.invoke('manage-user', ...)
-- Protected: validates JWT + checks caller is admin
-- ============================================================


-- ============================================================
-- DONE
-- ============================================================
