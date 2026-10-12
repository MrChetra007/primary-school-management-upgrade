-- ============================================================
-- PRIMARY SCHOOL MANAGEMENT SYSTEM
-- migration_v11_realtime_fix.sql — Realtime notification fix
-- Fixes the report link approval notification flow between
-- teachers and admins. Run on existing v11 installs.
-- ============================================================
--
-- PROBLEMS FIXED:
--   1. notifications table missing from supabase_realtime publication
--      → Realtime WebSocket never broadcasts INSERT events
--   2. notifications table missing REPLICA IDENTITY FULL
--      → payload.new arrives with only partial columns
--   3. Re-submit (rejected → pending) creates no admin notification
--      → notify_admin_on_request() is AFTER INSERT only
--      → notify_teacher_on_approval() ignores 'pending' status
--
-- ============================================================


-- ============================================================
-- STEP 1: Enable Realtime for the notifications table
-- Without this, postgres_changes subscriptions never fire.
-- ============================================================

alter publication supabase_realtime add table public.notifications;

-- Ensure the full row is sent in the WAL payload
alter table public.notifications replica identity full;


-- ============================================================
-- STEP 2: Trigger — notify admin when teacher re-submits
-- Fires after UPDATE when status changes from 'rejected' to 'pending'.
-- Uses WHEN clause to avoid invoking the function unnecessarily.
-- ============================================================

create or replace function notify_admin_on_resubmit()
returns trigger as $$
declare
  v_admin_user  record;
  v_class_name  text;
begin
  select class_name into v_class_name
  from classes where id = new.class_id;

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

drop trigger if exists on_report_link_resubmitted on report_links;

create trigger on_report_link_resubmitted
  after update of status on report_links
  for each row
  when (old.status = 'rejected' and new.status = 'pending')
  execute procedure notify_admin_on_resubmit();


-- ============================================================
-- VERIFICATION
-- Run these queries to confirm everything is set up correctly:
--
--   1. SELECT * FROM pg_publication_tables
--      WHERE pubname = 'supabase_realtime' AND tablename = 'notifications';
--      → should return one row
--
--   2. SELECT relreplicaidentity FROM pg_class
--      WHERE relname = 'notifications';
--      → relreplicaidentity = 2 means FULL
--
--   3. SELECT tgname FROM pg_trigger
--      WHERE tgname = 'on_report_link_resubmitted';
--      → should return one row
--
-- ============================================================
