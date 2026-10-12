-- ============================================================
-- MIGRATION: v4 → v5
-- Primary School Management System
-- Run this on your existing Supabase project (after schema_v4)
-- ============================================================


-- ============================================================
-- 1. NEW TABLE: school_settings
-- Singleton row — stores shift times + late thresholds
-- ============================================================

create table school_settings (
  id                     uuid primary key default uuid_generate_v4(),
  morning_start          time not null default '07:00',
  morning_late_threshold time not null default '07:15',
  evening_start          time not null default '13:00',
  evening_late_threshold time not null default '13:15',
  created_at             timestamptz default now(),
  updated_at             timestamptz default now()
);

-- Insert the default singleton row
insert into school_settings (id) values (uuid_generate_v4());

-- Enable RLS
alter table school_settings enable row level security;

-- RLS policies
create policy "school_settings: admin full"
  on school_settings for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

create policy "school_settings: staff read"
  on school_settings for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ============================================================
-- 2. ALTER TABLE: teacher_attendances
-- Add check_in_time, note, and unique constraint
-- ============================================================

alter table teacher_attendances
  add column check_in_time timestamptz,
  add column note          text;

-- Unique constraint: one check-in per teacher per day
alter table teacher_attendances
  add constraint teacher_attendances_teacher_id_date_key
  unique (teacher_id, date);


-- ============================================================
-- 3. UPDATE RLS: teacher_attendances
-- Replace old "teacher manage self" with read-only policy
-- Check-in must go through teacher_check_in() function only
-- ============================================================

drop policy if exists "teacher_attendances: teacher manage self"
  on teacher_attendances;

create policy "teacher_attendances: teacher read self"
  on teacher_attendances for select to authenticated
  using (
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- Note: teacher direct insert is now blocked
-- All check-ins must go through teacher_check_in() (security definer)


-- ============================================================
-- 4. NEW FUNCTION: teacher_check_in
-- Teacher calls this once per day — auto calculates present/late
-- based on their class turn + school_settings thresholds
-- ============================================================

create or replace function teacher_check_in()
returns json as $$
declare
  v_teacher_id uuid;
  v_settings   record;
  v_now        timestamptz := now();
  v_today      date        := current_date;
  v_time_now   time        := v_now::time;
  v_turn       class_turn;
  v_threshold  time;
  v_status     attendance_status;
  v_existing   record;
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

  -- Get teacher class turn (morning/afternoon) from their assigned class
  select c.turn into v_turn
  from classes c
  where c.teacher_id = v_teacher_id
  limit 1;

  -- Default to morning if no class assigned yet
  v_turn := coalesce(v_turn, 'morning');

  -- Get configured late thresholds
  select * into v_settings from school_settings limit 1;

  if v_turn = 'morning' then
    v_threshold := v_settings.morning_late_threshold;
  else
    v_threshold := v_settings.evening_late_threshold;
  end if;

  -- Auto calculate status
  if v_time_now > v_threshold then
    v_status := 'late';
  else
    v_status := 'present';
  end if;

  -- Record the check-in
  insert into teacher_attendances (teacher_id, date, check_in_time, status)
  values (v_teacher_id, v_today, v_now, v_status);

  return json_build_object(
    'status',        v_status,
    'check_in_time', v_now,
    'turn',          v_turn,
    'threshold',     v_threshold
  );
end;
$$ language plpgsql security definer;


-- ============================================================
-- 5. NEW FUNCTION: admin_override_teacher_attendance
-- Admin manually sets or overrides any teacher's attendance
-- Uses upsert — works whether record exists or not
-- ============================================================

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

  insert into teacher_attendances (teacher_id, date, status, note)
  values (p_teacher_id, p_date, p_status, p_note)
  on conflict (teacher_id, date)
  do update set
    status = excluded.status,
    note   = excluded.note;
end;
$$ language plpgsql security definer;


-- ============================================================
-- VERIFY: Check everything applied correctly
-- ============================================================

select
  'school_settings'      as item,
  count(*)::text         as result
from school_settings

union all

select
  'teacher_attendances columns',
  string_agg(column_name, ', ' order by ordinal_position)
from information_schema.columns
where table_name = 'teacher_attendances'
  and table_schema = 'public'

union all

select
  'teacher_check_in function',
  case when exists (
    select 1 from pg_proc where proname = 'teacher_check_in'
  ) then 'EXISTS ✓' else 'MISSING ✗' end

union all

select
  'admin_override_teacher_attendance function',
  case when exists (
    select 1 from pg_proc where proname = 'admin_override_teacher_attendance'
  ) then 'EXISTS ✓' else 'MISSING ✗' end;


-- ============================================================
-- DONE — Migration v4 → v5 complete
-- ============================================================
