-- ============================================================
-- MIGRATION: v5 → v6
-- Primary School Management System
-- Run this on your existing Supabase project (after schema_v5)
--
-- Change: Add class_subjects junction table
-- Reason: Different grades have different subjects
--         (Grade 1-3 no English, Grade 4-6 has English)
--         Subjects are now assigned per class, not global
-- ============================================================


-- ============================================================
-- 1. NEW TABLE: class_subjects
-- Junction table linking subjects to specific classes
-- ============================================================

create table class_subjects (
  id         uuid primary key default uuid_generate_v4(),
  class_id   uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  created_at timestamptz default now(),
  unique(class_id, subject_id)    -- no duplicate subject per class
);

-- Enable RLS
alter table class_subjects enable row level security;


-- ============================================================
-- 2. RLS POLICIES: class_subjects
-- ============================================================

-- Admin full access
create policy "class_subjects: admin full"
  on class_subjects for all to authenticated
  using (get_user_role() = 'admin')
  with check (get_user_role() = 'admin');

-- Teacher can read subjects for their own class only
create policy "class_subjects: teacher read own class"
  on class_subjects for select to authenticated
  using (
    get_user_role() = 'teacher' and
    class_id in (
      select id from classes
      where teacher_id = (select id from teachers where user_id = auth.uid())
    )
  );

-- Librarian read
create policy "class_subjects: librarian read"
  on class_subjects for select to authenticated
  using (get_user_role() = 'librarian');


-- ============================================================
-- 3. SEED: Assign subjects to existing classes
-- Based on seed_data.sql classes:
--   Grade 1 (ថ្នាក់ទី១ក, ១ខ) → no English
--   Grade 2 (ថ្នាក់ទី២ក, ២ខ) → no English
--   Grade 3 (ថ្នាក់ទី៣ក)     → no English
-- Adjust if you have Grade 4-6 classes
-- ============================================================

-- Subjects without English (Grade 1-3):
-- ភាសាខ្មែរ, គណិតវិទ្យា, វិទ្យាសាស្ត្រ, សិក្សាសង្គម, សិល្បៈ, អប់រំកាយ

insert into class_subjects (class_id, subject_id)
select c.id, s.id
from classes c
cross join subjects s
where s.subject_name != 'ភាសាអង់គ្លេស'  -- exclude English for all existing classes
on conflict do nothing;

-- ============================================================
-- NOTE: For Grade 4-6 classes, run this to add English:
--
-- insert into class_subjects (class_id, subject_id)
-- select c.id, s.id
-- from classes c
-- cross join subjects s
-- where c.class_name like 'ថ្នាក់ទី៤%'   -- adjust grade name pattern
--   or  c.class_name like 'ថ្នាក់ទី៥%'
--   or  c.class_name like 'ថ្នាក់ទី៦%'
-- and s.subject_name = 'ភាសាអង់គ្លេស'
-- on conflict do nothing;
-- ============================================================


-- ============================================================
-- VERIFY: Check everything applied correctly
-- ============================================================

-- 1. Count rows in class_subjects
select 'class_subjects rows' as item, count(*)::text as result
from class_subjects;

-- 2. Count RLS policies
select 'class_subjects RLS policies' as item, count(*)::text as result
from pg_policies
where tablename = 'class_subjects';

-- 3. Show each class with its assigned subjects
select
  c.class_name,
  string_agg(s.subject_name, ', ' order by s.subject_name) as subjects
from class_subjects cs
join classes c on c.id = cs.class_id
join subjects s on s.id = cs.subject_id
group by c.class_name
order by c.class_name;


-- ============================================================
-- DONE — Migration v5 → v6 complete
-- ============================================================