-- ============================================================
-- MIGRATION: v6 → v7
-- Feature: Student Rollup (promote students to next academic year)
-- Run this on your existing Supabase project
-- Safe to run on live data — only adds, never drops
-- ============================================================


-- ============================================================
-- 1. ADD is_graduated COLUMN TO students
-- ============================================================

alter table students
  add column if not exists is_graduated boolean not null default false;


-- ============================================================
-- 2. HELPER: Khmer numeral → integer
-- ============================================================

create or replace function khmer_to_int(p_khmer text)
returns int as $$
declare
  v_result text := p_khmer;
begin
  v_result := replace(v_result, '០', '0');
  v_result := replace(v_result, '១', '1');
  v_result := replace(v_result, '២', '2');
  v_result := replace(v_result, '៣', '3');
  v_result := replace(v_result, '៤', '4');
  v_result := replace(v_result, '៥', '5');
  v_result := replace(v_result, '៦', '6');
  v_result := replace(v_result, '៧', '7');
  v_result := replace(v_result, '៨', '8');
  v_result := replace(v_result, '៩', '9');
  return v_result::int;
end;
$$ language plpgsql immutable;


-- ============================================================
-- 3. HELPER: integer → Khmer numeral
-- ============================================================

create or replace function int_to_khmer(p_int int)
returns text as $$
declare
  v_result text := p_int::text;
begin
  v_result := replace(v_result, '0', '០');
  v_result := replace(v_result, '1', '១');
  v_result := replace(v_result, '2', '២');
  v_result := replace(v_result, '3', '៣');
  v_result := replace(v_result, '4', '៤');
  v_result := replace(v_result, '5', '៥');
  v_result := replace(v_result, '6', '៦');
  v_result := replace(v_result, '7', '៧');
  v_result := replace(v_result, '8', '៨');
  v_result := replace(v_result, '9', '៩');
  return v_result;
end;
$$ language plpgsql immutable;


-- ============================================================
-- 4. HELPER: extract grade number from class_name
-- Pattern: "ថ្នាក់ទី១ក" → 1
--          "ថ្នាក់ទី១២ក" → 12 (handles multi-digit just in case)
-- Strips "ថ្នាក់ទី" prefix, then reads all leading Khmer digits
-- ============================================================

create or replace function extract_grade_from_class_name(p_class_name text)
returns int as $$
declare
  v_stripped text;
  v_digits   text := '';
  v_char     text;
  v_i        int;
  v_khmer_digits text := '០១២៣៤៥៦៧៨៩';
begin
  -- Remove prefix "ថ្នាក់ទី"
  v_stripped := replace(p_class_name, 'ថ្នាក់ទី', '');

  -- Walk characters and collect leading Khmer digit chars
  for v_i in 1..char_length(v_stripped) loop
    v_char := substring(v_stripped from v_i for 1);
    if strpos(v_khmer_digits, v_char) > 0 then
      v_digits := v_digits || v_char;
    else
      exit; -- stop at first non-digit (e.g. ក, ខ, ...)
    end if;
  end loop;

  if v_digits = '' then
    return null;
  end if;

  return khmer_to_int(v_digits);
end;
$$ language plpgsql immutable;


-- ============================================================
-- 5. MAIN FUNCTION: perform_student_rollup
--
-- Logic:
--   For each grade 1–5 in old_year:
--     Get old classes (grade N, old year)
--     Get new classes (grade N+1, new year)
--
--     Case A — counts match (e.g. 2 old → 2 new):
--       Pair by alphabetical order: ២ក→៣ក, ២ខ→៣ខ
--       Move students from each old class → matched new class
--
--     Case B — only 1 new class (regardless of old count):
--       Move ALL students from all old grade-N classes → that 1 new class
--
--     Case C — 0 new classes for that grade:
--       Skip (no target available — admin must handle manually)
--
--   For grade 6 in old_year:
--     Set is_graduated = true, class_id = null
--     Update academic_year_id = new_year_id
--
--   All students updated: academic_year_id = new_year_id
--
-- Returns: summary JSON with counts per grade
-- ============================================================

create or replace function perform_student_rollup(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb as $$
declare
  v_grade         int;
  v_old_classes   uuid[];
  v_new_classes   uuid[];
  v_old_count     int;
  v_new_count     int;
  v_moved         int;
  v_total_moved   int := 0;
  v_graduated     int := 0;
  v_skipped       int := 0;
  v_summary       jsonb := '[]'::jsonb;
  v_grade_summary jsonb;
  v_i             int;
begin
  -- Caller must be admin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  -- Validate years exist
  if not exists (select 1 from academic_years where id = p_old_year_id) then
    raise exception 'Old academic year not found';
  end if;
  if not exists (select 1 from academic_years where id = p_new_year_id) then
    raise exception 'New academic year not found';
  end if;
  if p_old_year_id = p_new_year_id then
    raise exception 'Old and new academic year must be different';
  end if;

  -- --------------------------------------------------------
  -- Process grades 1 through 5 (promote to next grade)
  -- --------------------------------------------------------
  for v_grade in 1..5 loop

    -- Get old classes for this grade in old year, ordered by name
    select array_agg(id order by class_name)
    into v_old_classes
    from classes
    where academic_year_id = p_old_year_id
      and extract_grade_from_class_name(class_name) = v_grade;

    v_old_count := coalesce(array_length(v_old_classes, 1), 0);

    if v_old_count = 0 then
      continue; -- no classes for this grade in old year, skip
    end if;

    -- Get new classes for grade+1 in new year, ordered by name
    select array_agg(id order by class_name)
    into v_new_classes
    from classes
    where academic_year_id = p_new_year_id
      and extract_grade_from_class_name(class_name) = v_grade + 1;

    v_new_count := coalesce(array_length(v_new_classes, 1), 0);

    -- Case C: no new classes available for this grade → skip
    if v_new_count = 0 then
      v_skipped := v_skipped + v_old_count;

      v_grade_summary := jsonb_build_object(
        'grade', v_grade,
        'action', 'skipped',
        'reason', 'no grade ' || (v_grade + 1) || ' classes found in new year',
        'students_affected', 0
      );
      v_summary := v_summary || v_grade_summary;
      continue;
    end if;

    v_moved := 0;

    -- Case A: counts match → pair by order
    if v_new_count = v_old_count then
      for v_i in 1..v_old_count loop
        update students
        set
          class_id         = v_new_classes[v_i],
          academic_year_id = p_new_year_id
        where
          class_id         = v_old_classes[v_i]
          and is_graduated = false;

        v_moved := v_moved + (select count(*) from students
                              where class_id = v_new_classes[v_i]
                                and academic_year_id = p_new_year_id);
      end loop;

    -- Case B: only 1 new class → merge all into it
    elsif v_new_count = 1 then
      update students
      set
        class_id         = v_new_classes[1],
        academic_year_id = p_new_year_id
      where
        class_id         = any(v_old_classes)
        and is_graduated = false;

      get diagnostics v_moved = row_count;

    -- Case D: mismatched counts (e.g. 3 old → 2 new) → merge all into first new class
    -- Admin can manually reassign from there
    else
      update students
      set
        class_id         = v_new_classes[1],
        academic_year_id = p_new_year_id
      where
        class_id         = any(v_old_classes)
        and is_graduated = false;

      get diagnostics v_moved = row_count;
    end if;

    v_total_moved := v_total_moved + v_moved;

    v_grade_summary := jsonb_build_object(
      'grade', v_grade,
      'action',
        case
          when v_new_count = v_old_count then 'paired'
          when v_new_count = 1          then 'merged'
          else                               'merged_mismatch'
        end,
      'old_classes', v_old_count,
      'new_classes', v_new_count,
      'students_moved', v_moved
    );
    v_summary := v_summary || v_grade_summary;

  end loop;

  -- --------------------------------------------------------
  -- Process grade 6 → graduate
  -- --------------------------------------------------------
  select array_agg(id)
  into v_old_classes
  from classes
  where academic_year_id = p_old_year_id
    and extract_grade_from_class_name(class_name) = 6;

  if v_old_classes is not null then
    update students
    set
      is_graduated     = true,
      class_id         = null,
      academic_year_id = p_new_year_id
    where
      class_id         = any(v_old_classes)
      and is_graduated = false;

    get diagnostics v_graduated = row_count;
  end if;

  v_summary := v_summary || jsonb_build_object(
    'grade', 6,
    'action', 'graduated',
    'students_graduated', v_graduated
  );

  -- --------------------------------------------------------
  -- Final summary
  -- --------------------------------------------------------
  return jsonb_build_object(
    'success',          true,
    'old_year_id',      p_old_year_id,
    'new_year_id',      p_new_year_id,
    'total_promoted',   v_total_moved,
    'total_graduated',  v_graduated,
    'details',          v_summary
  );

end;
$$ language plpgsql security definer;


-- ============================================================
-- 6. HELPER FUNCTION: clone_classes_structure
--
-- Copies all class definitions (name, turn) from old_year → new_year.
-- Does NOT copy students or teacher assignments (since teachers might change).
-- ============================================================

create or replace function clone_classes_structure(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns int as $$
declare
  v_count int;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  insert into classes (class_name, turn, academic_year_id)
  select class_name, turn, p_new_year_id
  from classes
  where academic_year_id = p_old_year_id
  on conflict do nothing; -- avoid duplicates if already partially set up

  get diagnostics v_count = row_count;
  return v_count;
end;
$$ language plpgsql security definer;


-- ============================================================
-- 7. RLS: only admin can call rollup (enforced inside function too)
-- ============================================================


-- ============================================================
-- MIGRATION COMPLETE
-- New additions:
--   + students.is_graduated (boolean, default false)
--   + function khmer_to_int(text) → int
--   + function int_to_khmer(int) → text
--   + function extract_grade_from_class_name(text) → int
--   + function perform_student_rollup(uuid, uuid) → jsonb
-- ============================================================
