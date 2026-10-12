-- =====================================================================
-- Migration v15 — School-level scoring + weekly schedule defaults
-- =====================================================================
-- Run AFTER migration_v14_plan_limits_read_write.sql.
--
-- Adds school-wide DEFAULTS (set in Settings) that new classes inherit:
--   * default_scoring_mode      → 'subject_scores' | 'simple_result'
--   * default_weekly_schedule   → {"days": ["mon",...], "start": "HH:MM", "end": "HH:MM"}
--
-- Classes keep their own scoring_mode / schedule columns (per-class
-- override); these values only pre-fill the class form.
-- =====================================================================

alter table school_settings
  add column if not exists default_scoring_mode scoring_mode
    not null default 'subject_scores',
  add column if not exists default_weekly_schedule jsonb
    not null default '{"days": [], "start": "", "end": ""}'::jsonb;


-- =====================================================================
-- VERIFY (run manually)
-- =====================================================================
-- select school_id, default_scoring_mode, default_weekly_schedule
-- from school_settings;
-- =====================================================================
