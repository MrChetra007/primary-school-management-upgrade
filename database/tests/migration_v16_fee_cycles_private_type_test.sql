-- =====================================================================
-- Migration v16 tests — 'private' school type + one-time fee cycle
-- =====================================================================
-- Run on staging after migration_v16_fee_cycles_private_type.sql.
-- Every row must read PASS. The DO block RAISES on a critical failure.
-- =====================================================================

-- 1. school_type enum now includes 'private' --------------------------
select 'school_type enum includes private' as test,
       case
         when 'private' = any(enum_range(null::school_type)) then 'PASS' else 'FAIL'
       end as result;

-- 2. 'private' is usable as a value (committed) ------------------------
select 'private castable to school_type' as test,
       case when ('private'::school_type)::text = 'private' then 'PASS' else 'FAIL'
       end as result;

-- 3. fee_structures.cycle allows one_time -------------------------------
select 'fee_structures.cycle accepts one_time' as test,
       case
         when exists (
           select 1
           from pg_constraint c
           where c.conname = 'fee_structures_cycle_check'
             and pg_get_constraintdef(c.oid) like '%one_time%'
         ) then 'PASS' else 'FAIL'
       end as result;

-- 4. student_fees.cycle allows one_time ---------------------------------
select 'student_fees.cycle accepts one_time' as test,
       case
         when exists (
           select 1
           from pg_constraint c
           where c.conname = 'student_fees_cycle_check'
             and pg_get_constraintdef(c.oid) like '%one_time%'
         ) then 'PASS' else 'FAIL'
       end as result;

-- 5. Critical: BOTH constraints exist with one_time --------------------
do $$
declare
  v_ok boolean;
begin
  select
    exists (
      select 1 from pg_constraint c
      where c.conname = 'fee_structures_cycle_check'
        and pg_get_constraintdef(c.oid) like '%one_time%'
    )
    and exists (
      select 1 from pg_constraint c
      where c.conname = 'student_fees_cycle_check'
        and pg_get_constraintdef(c.oid) like '%one_time%'
    )
  into v_ok;

  if not v_ok then
    raise exception 'FAIL: one_time cycle constraints missing';
  end if;
end $$;