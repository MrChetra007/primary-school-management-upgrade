-- ============================================================
-- Migration v16 — 'private' school type + one-time fee cycle
-- ============================================================
-- 1) Adds 'private' to the school_type enum (generic private school).
--    NOTE: ALTER TYPE ... ADD VALUE commits regardless of the rest of the
--    transaction, and the new value must NOT be referenced in this file.
-- 2) Widens the fee `cycle` check so course-based schools (computer /
--    private) can charge a one-time fee per structure instead of being
--    forced into monthly/semester/yearly.
-- ============================================================

alter type school_type add value if not exists 'private';

alter table fee_structures
  drop constraint if exists fee_structures_cycle_check;
alter table fee_structures
  add constraint fee_structures_cycle_check
  check (cycle in ('monthly', 'semester', 'yearly', 'one_time'));

alter table student_fees
  drop constraint if exists student_fees_cycle_check;
alter table student_fees
  add constraint student_fees_cycle_check
  check (cycle in ('monthly', 'semester', 'yearly', 'one_time'));

-- Verify:
-- select unnest(enum_range(null::school_type)) as school_type;
-- select conname from pg_constraint where conname in ('fee_structures_cycle_check','student_fees_cycle_check');