-- ============================================================
-- migration_v11_super_admin_rls_fix.sql
-- Fix: Add missing super_admin RLS policies to all tables
-- 
-- Problem: The original schema_v11.sql was missing super_admin
-- policies on 22 out of 27 tables. Only schools, users,
-- school_settings, school_information, and teachers had them.
-- This caused the super admin dashboard to show 0 students
-- (and other incorrect counts) because RLS blocked all queries.
--
-- Run this after schema_v11.sql (fresh install) or on any
-- existing v11 database.
-- ============================================================

-- academic_years
create policy "academic_years: super_admin full"
  on academic_years for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- subjects
create policy "subjects: super_admin full"
  on subjects for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- classes
create policy "classes: super_admin full"
  on classes for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- class_subjects
create policy "class_subjects: super_admin full"
  on class_subjects for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- students
create policy "students: super_admin full"
  on students for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- student_health
create policy "student_health: super_admin full"
  on student_health for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- student_checkups
create policy "student_checkups: super_admin full"
  on student_checkups for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- student_growth
create policy "student_growth: super_admin full"
  on student_growth for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- student_vaccinations
create policy "student_vaccinations: super_admin full"
  on student_vaccinations for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- student_sick_days
create policy "student_sick_days: super_admin full"
  on student_sick_days for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- attendances
create policy "attendances: super_admin full"
  on attendances for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- scores
create policy "scores: super_admin full"
  on scores for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- teacher_attendances
create policy "teacher_attendances: super_admin full"
  on teacher_attendances for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- school_holidays
create policy "school_holidays: super_admin full"
  on school_holidays for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- books
create policy "books: super_admin full"
  on books for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- book_borrows
create policy "book_borrows: super_admin full"
  on book_borrows for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- budget_transactions
create policy "budget_transactions: super_admin full"
  on budget_transactions for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- inventory_items
create policy "inventory_items: super_admin full"
  on inventory_items for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- report_links
create policy "report_links: super_admin full"
  on report_links for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- report_messages
create policy "report_messages: super_admin full"
  on report_messages for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- notifications
create policy "notifications: super_admin full"
  on notifications for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');

-- teacher_phrases
create policy "teacher_phrases: super_admin full"
  on teacher_phrases for all to authenticated
  using (get_user_role() = 'super_admin')
  with check (get_user_role() = 'super_admin');