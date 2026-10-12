-- Migration: Roadmap v10 Identity Enforcements
-- Every user MUST have a teacher profile.

-- 1. Create teacher profiles for any users that don't have one (orphans)
insert into public.teachers (user_id, full_name, email)
select id, 'Staff Member', email
from public.users
where id not in (select user_id from public.teachers)
on conflict (user_id) do nothing;

-- 2. Ensure teachers table has the correct constraints (Roadmap v10)
-- These should already exist if using schema_v5, but we reinforce them here.
alter table public.teachers 
alter column user_id set not null;

-- 3. Add a check to prevent users from being deleted without deleting the teacher (handled by cascade delete in schema)
-- No action needed if 'references users(id) on delete cascade' is active.

-- 4. RLS Policy: Allow all authenticated staff to read all teacher profiles
-- This is necessary so they can see names in lists, class assignments, etc.
drop policy if exists "teachers: staff read all" on public.teachers;
create policy "teachers: staff read all"
  on public.teachers for select to authenticated
  using (true);

-- 5. RLS Policy: Allow users to update their own teacher profile
drop policy if exists "teachers: self update" on public.teachers;
create policy "teachers: self update"
  on public.teachers for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 6. PARENT PORTAL ACCESS (Roadmap v10)
-- Allow anon to search students by name and dob
drop policy if exists "students: anon search" on public.students;
create policy "students: anon search"
  on public.students for select to anon
  using (true);

-- Allow anon to read scores for a specific student
drop policy if exists "scores: anon read" on public.scores;
create policy "scores: anon read"
  on public.scores for select to anon
  using (true);

-- Allow anon to read attendance for a specific student
drop policy if exists "student_attendances: anon read" on public.student_attendances;
create policy "student_attendances: anon read"
  on public.student_attendances for select to anon
  using (true);

-- Allow anon to read health/growth/vaccinations for a specific student
drop policy if exists "student_growth: anon read" on public.student_growth;
create policy "student_growth: anon read"
  on public.student_growth for select to anon
  using (true);

drop policy if exists "student_vaccinations: anon read" on public.student_vaccinations;
create policy "student_vaccinations: anon read"
  on public.student_vaccinations for select to anon
  using (true);

drop policy if exists "student_sick_days: anon read" on public.student_sick_days;
create policy "student_sick_days: anon read"
  on public.student_sick_days for select to anon
  using (true);
