-- ============================================================
-- MISSING ANON RLS POLICIES (v9 parent portal fix)
-- Parent queries use !inner joins and foreign key relationships
-- that require anon SELECT access on these tables.
-- ============================================================

-- classes: anon read via report link
-- Needed for: ReportDropdownView, ReportCardView !inner joins
create policy "classes: anon read via report link"
  on classes for select to anon
  using (
    id in (select class_id from report_links)
  );

-- subjects: anon read via report link
-- Needed for: ReportCardView scores query with subjects(subject_name)
create policy "subjects: anon read via report link"
  on subjects for select to anon
  using (
    id in (
      select cs.subject_id from class_subjects cs
      join report_links rl on rl.class_id = cs.class_id
    )
  );
