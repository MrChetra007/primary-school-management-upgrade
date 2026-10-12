-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- migration_v9_v10.sql — Incremental migration
-- From: schema v9 (roadmap v15)
-- To:   schema v10 (roadmap v16)
-- Run this on existing v9 installs. For fresh installs use schema_v10.sql.
-- ============================================================
--
-- CHANGES IN v10:
--   1. report_links — add status, rejection_note, approved_at, approved_by
--   2. school_information — add signature_url, stamp_url
--   3. notifications table (new)
--   4. teacher_phrases table (new)
--   5. school-assets storage bucket + policies (new)
--   6. RLS update: report_links anon policy scoped to approved only
--   7. DB triggers: notify_admin_on_request, notify_teacher_on_approval
--   8. Indexes for new tables
-- ============================================================


-- ============================================================
-- STEP 1: report_links — add approval columns
-- ============================================================

alter table report_links
  add column if not exists status          text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  add column if not exists rejection_note  text,
  add column if not exists approved_at     timestamptz,
  add column if not exists approved_by     uuid references teachers(id) on delete set null;

-- Backfill: treat all existing links as approved (they were already shared)
update report_links set status = 'approved' where status = 'pending';

comment on column report_links.status is
  'pending = awaiting admin approval, approved = teacher can share, rejected = admin rejected';
comment on column report_links.approved_by is
  'teacher_id of the admin/principal who approved or rejected the link';


-- ============================================================
-- STEP 2: school_information — add signature + stamp columns
-- ============================================================

alter table school_information
  add column if not exists signature_url  text,
  add column if not exists stamp_url      text;

comment on column school_information.signature_url is
  'Principal digital signature image — stored in school-assets bucket';
comment on column school_information.stamp_url is
  'Official school stamp image — stored in school-assets bucket';


-- ============================================================
-- STEP 3: notifications table (new)
-- ============================================================

create table if not exists notifications (
  id                uuid primary key default uuid_generate_v4(),
  school_id         uuid not null references schools(id) on delete cascade,
  recipient_user_id uuid not null references users(id) on delete cascade,
  type              text not null,
  -- type values:
  --   'approval_requested'  → sent to admin when teacher requests approval
  --   'approval_approved'   → sent to teacher when admin approves
  --   'approval_rejected'   → sent to teacher when admin rejects
  payload           jsonb not null default '{}',
  -- payload examples:
  --   { report_link_id, class_name, score_type, month, semester, rejection_note }
  is_read           boolean not null default false,
  created_at        timestamptz default now()
);

comment on table notifications is
  'In-app notifications for admin (approval requests) and teacher (approval outcomes). No push/email — in-app only.';


-- ============================================================
-- STEP 4: teacher_phrases table (new)
-- ============================================================

create table if not exists teacher_phrases (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references schools(id) on delete cascade,
  teacher_id  uuid not null references teachers(id) on delete cascade,
  phrase_text text not null,
  sort_order  int4 not null default 0,
  created_at  timestamptz default now()
);

comment on table teacher_phrases is
  'Personal reusable feedback phrases per teacher. Chips shown below message box in report-replies. Private — not shared across teachers.';


-- ============================================================
-- STEP 5: indexes for new tables + report_links.status
-- ============================================================

create index if not exists idx_notifications_recipient
  on notifications(recipient_user_id, is_read);

create index if not exists idx_notifications_school
  on notifications(school_id);

create index if not exists idx_teacher_phrases_teacher
  on teacher_phrases(teacher_id);

create index if not exists idx_teacher_phrases_school
  on teacher_phrases(school_id);

create index if not exists idx_report_links_status_school
  on report_links(status, school_id);


-- ============================================================
-- STEP 6: Enable RLS on new tables
-- ============================================================

alter table notifications    enable row level security;
alter table teacher_phrases  enable row level security;


-- ============================================================
-- STEP 7: RLS — notifications
-- ============================================================

-- Admin can insert notifications (for teacher recipients)
create policy "notifications: admin insert own school"
  on notifications for insert to authenticated
  with check (
    get_user_role() = 'admin' and school_id = get_user_school_id()
  );

-- Each user reads only their own notifications
create policy "notifications: self read"
  on notifications for select to authenticated
  using (recipient_user_id = auth.uid());

-- Each user can mark their own notifications as read
create policy "notifications: self update is_read"
  on notifications for update to authenticated
  using (recipient_user_id = auth.uid())
  with check (recipient_user_id = auth.uid());

-- Triggers insert notifications as security definer — no extra policy needed for that


-- ============================================================
-- STEP 8: RLS — teacher_phrases
-- ============================================================

-- Teacher manages only their own phrases
create policy "teacher_phrases: teacher manage own"
  on teacher_phrases for all to authenticated
  using (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  )
  with check (
    get_user_role() = 'teacher' and
    school_id = get_user_school_id() and
    teacher_id = (select id from teachers where user_id = auth.uid())
  );

-- Admin can read all phrases in their school (e.g. for support/audit)
create policy "teacher_phrases: admin read own school"
  on teacher_phrases for select to authenticated
  using (
    get_user_role() = 'admin' and school_id = get_user_school_id()
  );


-- ============================================================
-- STEP 9: RLS — report_links anon policy update
-- Drop old open anon policy, replace with approved-only
-- ============================================================

drop policy if exists "report_links: anon read by id" on report_links;

create policy "report_links: anon read approved only"
  on report_links for select to anon
  using (status = 'approved');

-- Authenticated teachers/admins keep full access via existing policy
-- "report_links: teacher manage own class" — no change needed


-- ============================================================
-- STEP 10: DB trigger — notify admin when teacher requests approval
-- Fires after INSERT on report_links (status defaults to 'pending')
-- Finds all admin users in the same school and creates a notification row for each.
-- ============================================================

create or replace function notify_admin_on_request()
returns trigger as $$
declare
  v_admin_user  record;
  v_class_name  text;
begin
  -- Only fire when a new pending link is created
  if new.status != 'pending' then
    return new;
  end if;

  select class_name into v_class_name
  from classes where id = new.class_id;

  -- Insert one notification per admin in the school
  for v_admin_user in
    select id from users
    where school_id = new.school_id and role = 'admin' and status = 'active'
  loop
    insert into notifications (
      school_id,
      recipient_user_id,
      type,
      payload
    ) values (
      new.school_id,
      v_admin_user.id,
      'approval_requested',
      jsonb_build_object(
        'report_link_id', new.id,
        'class_name',     coalesce(v_class_name, ''),
        'score_type',     new.score_type,
        'month',          new.month,
        'semester',       new.semester
      )
    );
  end loop;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_report_link_created on report_links;

create trigger on_report_link_created
  after insert on report_links
  for each row execute procedure notify_admin_on_request();


-- ============================================================
-- STEP 11: DB trigger — notify teacher when admin approves/rejects
-- Fires after UPDATE on report_links when status changes.
-- Finds the teacher who created the link and notifies them.
-- ============================================================

create or replace function notify_teacher_on_approval()
returns trigger as $$
declare
  v_teacher_user_id uuid;
  v_class_name      text;
  v_notif_type      text;
begin
  -- Only fire when status actually changed to approved or rejected
  if old.status = new.status then
    return new;
  end if;

  if new.status not in ('approved', 'rejected') then
    return new;
  end if;

  -- Look up the user_id of the teacher who created the link
  select user_id into v_teacher_user_id
  from teachers where id = new.created_by;

  if v_teacher_user_id is null then
    return new;
  end if;

  select class_name into v_class_name
  from classes where id = new.class_id;

  v_notif_type := case
    when new.status = 'approved' then 'approval_approved'
    else 'approval_rejected'
  end;

  insert into notifications (
    school_id,
    recipient_user_id,
    type,
    payload
  ) values (
    new.school_id,
    v_teacher_user_id,
    v_notif_type,
    jsonb_build_object(
      'report_link_id',  new.id,
      'class_name',      coalesce(v_class_name, ''),
      'score_type',      new.score_type,
      'month',           new.month,
      'semester',        new.semester,
      'rejection_note',  new.rejection_note
    )
  );

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_report_link_status_changed on report_links;

create trigger on_report_link_status_changed
  after update of status on report_links
  for each row execute procedure notify_teacher_on_approval();


-- ============================================================
-- STEP 12: school-assets storage bucket (new)
-- Stores principal signature image + school stamp image.
-- Public read — images are embedded in parent report card PDF.
-- Admin only write.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('school-assets', 'school-assets', true)
on conflict do nothing;

-- Admin (and super_admin) can upload/update/delete school assets
create policy "school-assets: admin full"
  on storage.objects for all to authenticated
  using (
    bucket_id = 'school-assets' and
    get_user_role() in ('admin', 'super_admin')
  )
  with check (
    bucket_id = 'school-assets' and
    get_user_role() in ('admin', 'super_admin')
  );

-- Public read — anyone with the URL (e.g. parent report card) can load the image
create policy "school-assets: public read"
  on storage.objects for select to public
  using (bucket_id = 'school-assets');


-- ============================================================
-- DONE — migration_v9_v10.sql
-- Safe to run multiple times (uses IF NOT EXISTS + IF EXISTS guards)
-- After running: verify with SELECT * FROM notifications LIMIT 1;
--                        SELECT * FROM teacher_phrases LIMIT 1;
--                        SELECT status FROM report_links LIMIT 5;
-- ============================================================
