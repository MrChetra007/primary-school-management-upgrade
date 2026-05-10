-- ============================================================
-- SEEDER: Super Admin User
-- Creates: sozin@gmail.com / password123
-- Role: super_admin (platform-level, no school_id)
-- ============================================================
-- HOW TO RUN:
--   Option A (Supabase Dashboard):
--     SQL Editor → paste → Run
--   Option B (Supabase CLI):
--     supabase db execute --file seed_super_admin.sql
-- ============================================================

do $$
declare
  v_user_id uuid;
begin

  -- --------------------------------------------------------
  -- 1. Create the auth user (Supabase auth.users)
  --    crypt() hashes the password using bcrypt.
  --    raw_user_meta_data tells handle_new_user() trigger
  --    to set role = 'super_admin' and school_id = null.
  -- --------------------------------------------------------
  -- Skip if user already exists
  if exists (select 1 from auth.users where email = 'sozin@gmail.com') then
    raise notice 'User sozin@gmail.com already exists — skipping.';
    return;
  end if;

  v_user_id := gen_random_uuid();

  insert into auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    raw_user_meta_data,
    raw_app_meta_data,
    is_super_admin,
    role,
    aud,
    created_at,
    updated_at
  )
  values (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'sozin@gmail.com',
    crypt('password123', gen_salt('bf')),
    now(),                              -- auto-confirm email
    '',                                 -- confirmation_token (not needed, already confirmed)
    '',                                 -- recovery_token
    '',                                 -- email_change_token_new
    '',                                 -- email_change
    jsonb_build_object(
      'role',      'super_admin',
      'school_id', ''                   -- empty string → handle_new_user sets null
    ),
    '{"provider": "email", "providers": ["email"]}',
    false,
    'authenticated',
    'authenticated',
    now(),
    now()
  );

  -- --------------------------------------------------------
  -- 2. The handle_new_user() trigger fires automatically
  --    and inserts into public.users with:
  --      role      = 'super_admin'
  --      school_id = null
  --
  --    If for any reason the trigger didn't fire (e.g. you
  --    inserted directly), this upsert acts as a safety net.
  -- --------------------------------------------------------
  insert into public.users (id, email, role, school_id)
  values (v_user_id, 'sozin@gmail.com', 'super_admin', null)
  on conflict (id) do update
    set role = 'super_admin',
        school_id = null;

  raise notice 'super_admin created: sozin@gmail.com (id: %)', v_user_id;

end $$;

-- ============================================================
-- VERIFY: run this after to confirm the user was created
-- ============================================================
-- select u.id, u.email, u.role, u.school_id, u.status
-- from public.users u
-- where u.email = 'sozin@gmail.com';
-- password: password123