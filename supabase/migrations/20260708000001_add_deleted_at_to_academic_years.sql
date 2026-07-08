-- Add soft-delete support to academic_years
alter table academic_years
  add column deleted_at timestamptz default null;

-- Allow filtering out soft-deleted years in existing queries
create index if not exists idx_academic_years_deleted_at
  on academic_years (deleted_at);
