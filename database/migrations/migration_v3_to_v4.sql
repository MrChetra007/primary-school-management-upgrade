-- ============================================================
-- MIGRATION: schema v3 → schema v4 (roadmap v7)
-- Run this on your existing database to apply changes
-- Safe to run on a live Supabase project
-- ============================================================
-- Summary of changes:
--   1. teachers.user_id changed to NOT NULL UNIQUE
--      (every user always has exactly one teacher profile)
--   2. teachers: self update policy updated to allow any role
--      (not just 'teacher' role — admin/librarian can update too)
--   3. subjects: librarian read policy added
--   4. Removed old create_user() DB function (replaced by Edge Function)
-- ============================================================


-- ============================================================
-- 1. BACKFILL: ensure no orphan teachers rows before constraints
-- (skip if your DB is empty / freshly seeded)
-- ============================================================

-- Optional: check for teachers rows with null user_id
-- SELECT * FROM teachers WHERE user_id IS NULL;
-- Delete or fix them before proceeding.


-- ============================================================
-- 2. ALTER teachers.user_id → NOT NULL + UNIQUE
-- ============================================================

-- Drop existing FK constraint first, then re-add with NOT NULL
alter table teachers
  alter column user_id set not null;

-- Add unique constraint (one profile per user account)
alter table teachers
  drop constraint if exists teachers_user_id_key;

alter table teachers
  add constraint teachers_user_id_key unique (user_id);

-- Change ON DELETE behavior: cascade delete profile when user is deleted
alter table teachers
  drop constraint if exists teachers_user_id_fkey;

alter table teachers
  add constraint teachers_user_id_fkey
  foreign key (user_id) references users(id) on delete cascade;


-- ============================================================
-- 3. UPDATE RLS POLICIES on teachers table
-- ============================================================

-- Drop old teacher-only self-read policy
drop policy if exists "teachers: self read" on teachers;

-- Add: all staff can read all teacher profiles
drop policy if exists "teachers: all staff read" on teachers;
create policy "teachers: all staff read"
  on teachers for select to authenticated
  using (get_user_role() in ('admin', 'teacher', 'librarian'));

-- Add: any staff can update their own profile (not just teacher role)
drop policy if exists "teachers: self update" on teachers;
create policy "teachers: self update"
  on teachers for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- ============================================================
-- 4. UPDATE RLS POLICIES on subjects table
-- Add librarian read access (was missing before)
-- ============================================================

drop policy if exists "subjects: teacher read" on subjects;
create policy "subjects: staff read"
  on subjects for select to authenticated
  using (get_user_role() in ('teacher', 'librarian'));


-- ============================================================
-- 5. UPDATE storage policies for teacher-profiles bucket
-- Allow ALL staff roles to upload/update their own photo
-- (previously only allowed 'teacher' role)
-- ============================================================

drop policy if exists "teacher-profiles: teacher upload own" on storage.objects;
drop policy if exists "teacher-profiles: teacher update own" on storage.objects;

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


-- ============================================================
-- 6. DROP old create_user() DB function
-- This is now fully handled by the manage-user Edge Function
-- ============================================================

drop function if exists create_user(text, text, user_role, text);
drop function if exists admin_reset_password(uuid);


-- ============================================================
-- DONE
-- ============================================================
