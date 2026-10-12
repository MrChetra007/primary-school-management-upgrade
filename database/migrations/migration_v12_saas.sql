-- =====================================================================
-- Migration v12 — SaaS billing (KHQR.dev) + plan limits + student fees
-- =====================================================================
-- Turns the multi-tenant school system into a paid SaaS:
--   Basic $30/mo  → up to 200 students (students, attendance, scores,
--                   reports, parent report links, approval flow, fees)
--   Pro   $50/mo  → unlimited students + library, budget, inventory,
--                   honor board, certificates
--
-- Billing uses the KHQR.dev automated flow (see
-- docs/khqrdev_payment_implementation.md), adapted from the `my-saas`
-- reference schema. Tenant table = `schools` (was `restaurants`).
-- No free trial: a school is blocked until its first payment succeeds.
--
-- Run AFTER schema_v11.sql. Safe to run once on an existing v11 database.
-- =====================================================================


-- =====================================================================
-- 1. PLATFORM SETTINGS  (single row — boolean PK trick)
-- =====================================================================

create table if not exists platform_settings (
  id             boolean not null default true primary key check (id),
  merchant_name  text not null default 'Primary School Management',
  merchant_city  text not null default 'Phnom Penh',
  currency       text not null default 'USD' check (currency in ('USD', 'KHR')),
  app_config     jsonb not null default '{}'::jsonb,
  -- app_config example:
  --   { "basic_price_manual": 30, "pro_price_manual": 50,
  --     "sandbox_mode": false, "sandbox_amount": 0.1 }
  updated_at     timestamptz not null default now(),
  updated_by     uuid references users(id)
);

insert into platform_settings (id) values (true) on conflict (id) do nothing;


-- =====================================================================
-- 2. PLANS  (pricing + feature flags + student cap)
-- =====================================================================
-- prices live here so they are editable without a redeploy.
-- `features` is the single source of truth for module gating.
-- =====================================================================

create table if not exists plans (
  id            text primary key,                 -- 'basic' | 'pro'
  display_name  text not null,
  monthly_fee   numeric not null check (monthly_fee >= 0),
  max_students  integer,                          -- null = unlimited
  features      jsonb not null default '{}'::jsonb,
  is_active     boolean not null default true,
  updated_at    timestamptz not null default now()
);

insert into plans (id, display_name, monthly_fee, max_students, features) values
(
  'basic', 'Basic', 30, 200,
  '{
    "students": true,
    "attendance": true,
    "scores": true,
    "reports": true,
    "report_links": true,
    "approval_flow": true,
    "fees": true,
    "library": false,
    "budget": false,
    "inventory": false,
    "honor_board": false,
    "certificates": false
  }'::jsonb
),
(
  'pro', 'Pro', 50, null,
  '{
    "students": true,
    "attendance": true,
    "scores": true,
    "reports": true,
    "report_links": true,
    "approval_flow": true,
    "fees": true,
    "library": true,
    "budget": true,
    "inventory": true,
    "honor_board": true,
    "certificates": true
  }'::jsonb
)
on conflict (id) do update
  set display_name = excluded.display_name,
      monthly_fee  = excluded.monthly_fee,
      max_students = excluded.max_students,
      features     = excluded.features,
      updated_at   = now();


-- =====================================================================
-- 3. SCHOOLS  — plan + subscription expiry
-- =====================================================================
-- plan_expires_at = last CONFIRMED paid-through date.
--   null  → never paid (new school, blocked until first payment).
--   < now → expired (blocked).
-- grace_period_ends_at = optional temporary allowance (e.g. while a
--   proof of payment is under review). null = no grace.
-- =====================================================================

alter table schools
  add column if not exists plan               text not null default 'basic' references plans(id),
  add column if not exists plan_expires_at    timestamptz,
  add column if not exists grace_period_ends_at timestamptz,
  add column if not exists billing_type       text not null default 'manual';

create index if not exists idx_schools_plan_expires_at on schools (plan_expires_at);


-- =====================================================================
-- 4. SUBSCRIPTION INVOICES  (one row per billing cycle, KHQR.dev)
-- =====================================================================
-- Created server-side by the `khqr-payment` edge function (the amount
-- is always computed on the server, never trusted from the client).
-- =====================================================================

create table if not exists subscription_invoices (
  id                    uuid primary key default uuid_generate_v4(),
  school_id             uuid not null references schools(id) on delete cascade,
  plan_id               text not null references plans(id),
  period_start          date not null,
  period_end            date not null,
  base_fee              numeric not null default 0,
  total_amount          numeric not null,          -- amount charged (server-computed)
  currency              text not null default 'USD',
  khqrdev_md5           text,                      -- md5 returned by KHQR.dev generate_qr
  khqrdev_tran_id       text,                      -- KHQR.dev transaction id
  khqrdev_checkout_url  text,
  status                text not null default 'pending'
    check (status in ('pending', 'paid', 'expired', 'void')),
  paid_at               timestamptz,
  confirmed_by          uuid references users(id),
  created_at            timestamptz not null default now()
);

create unique index if not exists uq_subscription_invoices_khqrdev_md5
  on subscription_invoices (khqrdev_md5)
  where khqrdev_md5 is not null;

create index if not exists idx_subscription_invoices_school
  on subscription_invoices (school_id, created_at desc);

create index if not exists idx_subscription_invoices_status
  on subscription_invoices (status);


-- =====================================================================
-- 5. HELPER FUNCTIONS  — access + feature gating
-- =====================================================================
-- school_active(): true only while the school's subscription is paid up.
-- has_feature(f): school_active() AND the plan enables the module.
-- Both read via get_user_school_id() (existing v11 helper) and are
-- SECURITY DEFINER so they can read schools/plans regardless of RLS.
-- =====================================================================

create or replace function school_active()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (
      select
        s.status = 'active'
        and (
          (s.plan_expires_at     is not null and now() < s.plan_expires_at)
          or
          (s.grace_period_ends_at is not null and now() < s.grace_period_ends_at)
        )
      from schools s
      where s.id = get_user_school_id()
    ),
    false
  );
$$;

create or replace function has_feature(p_feature text)
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (
      select
        school_active()
        and coalesce((p.features ->> p_feature)::boolean, false)
      from schools s
      join plans p on p.id = s.plan
      where s.id = get_user_school_id()
    ),
    false
  );
$$;


-- =====================================================================
-- 6. STUDENT PLAN LIMIT  (hard cap enforced on insert)
-- =====================================================================
-- Counts non-graduated students in the school's CURRENT active
-- academic year. Graduated / historical-year rows never count.
-- =====================================================================

create or replace function enforce_student_plan_limit()
returns trigger
language plpgsql
security definer
as $$
declare
  v_max   integer;
  v_plan  text;
  v_year  uuid;
  v_count integer;
begin
  select s.plan, p.max_students
    into v_plan, v_max
  from schools s
  join plans p on p.id = s.plan
  where s.id = new.school_id;

  -- unlimited plan (Pro) → allow
  if v_max is null then
    return new;
  end if;

  -- determine the school's active academic year
  select id
    into v_year
  from academic_years
  where school_id = new.school_id
    and status = 'active'
    and deleted_at is null
  order by start_date desc
  limit 1;

  -- imports into a non-active/historical year don't trip the live cap
  if new.academic_year_id is not null
     and v_year is not null
     and new.academic_year_id <> v_year then
    return new;
  end if;

  select count(*)
    into v_count
  from students
  where school_id = new.school_id
    and academic_year_id = coalesce(new.academic_year_id, v_year)
    and is_graduated = false;

  if v_count >= v_max then
    raise exception
      'Plan limit reached: the % plan allows up to % students in the current academic year. Upgrade to Pro for unlimited students.',
      initcap(v_plan), v_max
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists on_student_insert_check_limit on students;
create trigger on_student_insert_check_limit
  before insert on students
  for each row execute procedure enforce_student_plan_limit();


-- =====================================================================
-- 7. STUDENT FEES MODULE  (fee structures → invoices → payments)
-- =====================================================================
-- fee_structures : the billing rule per class (cycle + amount).
-- student_fees   : one invoice row per student per period.
-- fee_payments   : money actually received (staff-recorded).
-- Currency defaults to KHR (school fees), independent of USD subscription.
-- =====================================================================

create table if not exists fee_structures (
  id                uuid primary key default uuid_generate_v4(),
  school_id         uuid not null references schools(id) on delete cascade default get_user_school_id(),
  academic_year_id  uuid not null references academic_years(id) on delete cascade,
  class_id          uuid references classes(id) on delete cascade,
  name              text not null,
  cycle             text not null check (cycle in ('monthly', 'semester', 'yearly')),
  semester          int2 check (semester in (1, 2)),      -- for semester cycle
  amount            numeric(12,2) not null check (amount >= 0),
  currency          text not null default 'KHR' check (currency in ('KHR', 'USD')),
  due_day           int2 check (due_day between 1 and 31), -- monthly: day of month
  is_active         boolean not null default true,
  created_at        timestamptz default now()
);

create index if not exists idx_fee_structures_school
  on fee_structures (school_id, academic_year_id, class_id);

create table if not exists student_fees (
  id                uuid primary key default uuid_generate_v4(),
  school_id         uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_id        uuid not null references students(id) on delete cascade,
  fee_structure_id  uuid not null references fee_structures(id) on delete cascade,
  academic_year_id  uuid not null references academic_years(id) on delete cascade,
  cycle             text not null check (cycle in ('monthly', 'semester', 'yearly')),
  month             int2 check (month between 1 and 12),
  semester          int2 check (semester in (1, 2)),
  amount_due        numeric(12,2) not null default 0,
  amount_paid       numeric(12,2) not null default 0,
  currency          text not null default 'KHR' check (currency in ('KHR', 'USD')),
  due_date          date,
  status            text not null default 'due'
    check (status in ('due', 'partial', 'paid', 'overdue', 'waived')),
  created_at        timestamptz default now()
);

-- one invoice per student/structure/period (null-safe on month+semester)
create unique index if not exists uq_student_fees_period
  on student_fees (student_id, fee_structure_id, coalesce(month, 0), coalesce(semester, 0));

create index if not exists idx_student_fees_school
  on student_fees (school_id, status, due_date);

create index if not exists idx_student_fees_student
  on student_fees (student_id);

create table if not exists fee_payments (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references schools(id) on delete cascade default get_user_school_id(),
  student_fee_id  uuid not null references student_fees(id) on delete cascade,
  amount          numeric(12,2) not null check (amount > 0),
  currency        text not null default 'KHR' check (currency in ('KHR', 'USD')),
  method          text not null default 'cash'
    check (method in ('cash', 'bank', 'khqr', 'wing', 'other')),
  reference_no    text,
  receipt_no      text,
  note            text,
  paid_at         timestamptz not null default now(),
  recorded_by     uuid references users(id) on delete set null,
  created_at      timestamptz default now()
);

create index if not exists idx_fee_payments_school
  on fee_payments (school_id, paid_at desc);

create index if not exists idx_fee_payments_fee
  on fee_payments (student_fee_id);

-- keep student_fees.amount_paid + status in sync with payments
create or replace function sync_student_fee_paid()
returns trigger
language plpgsql
as $$
declare
  v_fee_id uuid;
  v_paid   numeric;
  v_due    numeric;
  v_due_dt date;
  v_status text;
begin
  v_fee_id := coalesce(new.student_fee_id, old.student_fee_id);

  select coalesce(sum(amount), 0) into v_paid
  from fee_payments where student_fee_id = v_fee_id;

  select amount_due, due_date, status
    into v_due, v_due_dt, v_status
  from student_fees where id = v_fee_id;

  -- never overwrite an explicit waiver
  if v_status = 'waived' then
    update student_fees set amount_paid = v_paid where id = v_fee_id;
    return null;
  end if;

  update student_fees
  set amount_paid = v_paid,
      status = case
        when v_paid <= 0 and v_due_dt is not null and v_due_dt < current_date then 'overdue'
        when v_paid <= 0 then 'due'
        when v_paid < v_due then 'partial'
        else 'paid'
      end
  where id = v_fee_id;

  return null;
end;
$$;

drop trigger if exists on_fee_payment_change on fee_payments;
create trigger on_fee_payment_change
  after insert or update or delete on fee_payments
  for each row execute procedure sync_student_fee_paid();


-- =====================================================================
-- 8. RLS — NEW TABLES
-- =====================================================================

alter table platform_settings   enable row level security;
alter table plans               enable row level security;
alter table subscription_invoices enable row level security;
alter table fee_structures      enable row level security;
alter table student_fees        enable row level security;
alter table fee_payments        enable row level security;

-- platform_settings: super admin only (prices via Super Admin Settings)
drop policy if exists "platform_settings: super_admin full" on platform_settings;
create policy "platform_settings: super_admin full"
  on platform_settings for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- plans: everyone authenticated can read (to show pricing); super admin writes
drop policy if exists "plans: read all" on plans;
create policy "plans: read all"
  on plans for select to authenticated
  using (true);

drop policy if exists "plans: super_admin write" on plans;
create policy "plans: super_admin write"
  on plans for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- subscription_invoices: super admin full; school admin reads own
drop policy if exists "subscription_invoices: super_admin full" on subscription_invoices;
create policy "subscription_invoices: super_admin full"
  on subscription_invoices for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

drop policy if exists "subscription_invoices: admin read own school" on subscription_invoices;
create policy "subscription_invoices: admin read own school"
  on subscription_invoices for select to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id());

-- fee_structures
drop policy if exists "fee_structures: super_admin full" on fee_structures;
create policy "fee_structures: super_admin full"
  on fee_structures for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

drop policy if exists "fee_structures: admin manage own school" on fee_structures;
create policy "fee_structures: admin manage own school"
  on fee_structures for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('fees'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('fees'));

-- student_fees
drop policy if exists "student_fees: super_admin full" on student_fees;
create policy "student_fees: super_admin full"
  on student_fees for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

drop policy if exists "student_fees: admin manage own school" on student_fees;
create policy "student_fees: admin manage own school"
  on student_fees for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('fees'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('fees'));

-- fee_payments
drop policy if exists "fee_payments: super_admin full" on fee_payments;
create policy "fee_payments: super_admin full"
  on fee_payments for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

drop policy if exists "fee_payments: admin manage own school" on fee_payments;
create policy "fee_payments: admin manage own school"
  on fee_payments for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('fees'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('fees'));


-- =====================================================================
-- 9. RLS — HARD-BLOCK CORE MODULES WHEN SUBSCRIPTION IS INACTIVE
-- =====================================================================
-- Recreate every core "<table>: admin manage own school" policy so an
-- admin of an unpaid/expired school cannot read or write anything.
-- Uses a loop so the guard can never drift between tables.
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'users', 'school_settings', 'school_information', 'academic_years',
    'subjects', 'teachers', 'classes', 'class_subjects', 'students',
    'student_health', 'student_checkups', 'student_growth',
    'student_vaccinations', 'student_sick_days', 'attendances', 'scores',
    'teacher_attendances', 'school_holidays', 'semester_config'
  ]
  loop
    execute format('drop policy if exists %I on public.%I',
                   t || ': admin manage own school', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using (get_user_role() = %L and school_id = get_user_school_id() and school_active()) '
      || 'with check (get_user_role() = %L and school_id = get_user_school_id() and school_active())',
      t || ': admin manage own school', t, 'admin', 'admin'
    );
  end loop;
end $$;


-- =====================================================================
-- 10. RLS — PRO-ONLY MODULES (library, budget, inventory)
-- =====================================================================
-- Blocked entirely on the Basic plan (and when inactive).
-- =====================================================================

-- books
drop policy if exists "books: admin manage own school" on books;
create policy "books: admin manage own school"
  on books for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('library'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

drop policy if exists "books: librarian manage own school" on books;
create policy "books: librarian manage own school"
  on books for all to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and school_active() and has_feature('library'))
  with check (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

-- book_borrows
drop policy if exists "book_borrows: admin manage own school" on book_borrows;
create policy "book_borrows: admin manage own school"
  on book_borrows for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('library'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

drop policy if exists "book_borrows: librarian manage own school" on book_borrows;
create policy "book_borrows: librarian manage own school"
  on book_borrows for all to authenticated
  using (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and school_active() and has_feature('library'))
  with check (get_user_role() = 'librarian' and school_id = get_user_school_id()
         and school_active() and has_feature('library'));

-- budget_transactions
drop policy if exists "budget_transactions: admin manage own school" on budget_transactions;
create policy "budget_transactions: admin manage own school"
  on budget_transactions for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('budget'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('budget'));

-- inventory_items
drop policy if exists "inventory_items: admin manage own school" on inventory_items;
create policy "inventory_items: admin manage own school"
  on inventory_items for all to authenticated
  using (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('inventory'))
  with check (get_user_role() = 'admin' and school_id = get_user_school_id()
         and school_active() and has_feature('inventory'));


-- =====================================================================
-- VERIFY (run manually)
-- =====================================================================
-- select id, display_name, monthly_fee, max_students from plans;
--   basic: 30, 200 | pro: 50, null
-- select id, plan, plan_expires_at, billing_type from schools;
-- select school_active(), has_feature('fees'), has_feature('library'); -- as an admin
-- =====================================================================
