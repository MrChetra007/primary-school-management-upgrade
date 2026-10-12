-- Run this to check, everything should already be there
select
  u.email,
  u.role,
  au.email_confirmed_at is not null as email_confirmed
from public.users u
join auth.users au on au.id = u.id
where u.email in ('admin@gmail.com', 'teacher@gmail.com', 'librarian@gmail.com');
-- ============================================================
-- SEED: Create 3 role accounts for testing
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Enable pgcrypto for password hashing
create extension if not exists pgcrypto;


-- ============================================================
-- STEP 1: Insert into auth.users (Supabase Auth)
-- ============================================================

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values

-- 1. Admin account
(
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'admin@gmail.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"role": "admin"}',
  now(),
  now(),
  '', '', '', ''
),

-- 2. Teacher account
(
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'teacher@gmail.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"role": "teacher"}',
  now(),
  now(),
  '', '', '', ''
),

-- 3. Librarian account
(
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'librarian@gmail.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"role": "librarian"}',
  now(),
  now(),
  '', '', '', ''
);


-- ============================================================
-- STEP 2: Create a teacher profile for the teacher account
-- So teacher RLS queries via teachers table work correctly
-- NOTE: public.users is auto-populated by the trigger — no need to insert manually
-- ============================================================

insert into teachers (id, user_id, full_name, gender, email)
values
(
  gen_random_uuid(),
  (select id from auth.users where email = 'teacher@gmail.com'),
  'គ្រូបង្រៀន សាកល្បង',
  'ប្រុស',
  'teacher@gmail.com'
);


-- ============================================================
-- VERIFY: Check all 3 accounts were created correctly
-- ============================================================

select
  u.email,
  u.role,
  au.email_confirmed_at is not null as email_confirmed
from public.users u
join auth.users au on au.id = u.id
where u.email in ('admin@gmail.com', 'teacher@gmail.com', 'librarian@gmail.com');
