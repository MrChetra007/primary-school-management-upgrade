-- Change perform_student_rollup from UPDATE (move) to INSERT (copy)
-- so old academic year retains its student records for history.
-- Also auto-creates target classes in the new year if missing.

-- Helper: convert integer to Khmer digits
create or replace function int_to_khmer(p_num int)
returns text as $$
declare
  v_digits text := '០១២៣៤៥៦៧៨៩';
  v_result text := '';
begin
  if p_num = 0 then return '០'; end if;
  while p_num > 0 loop
    v_result := substring(v_digits from (p_num % 10) + 1 for 1) || v_result;
    p_num := p_num / 10;
  end loop;
  return v_result;
end;
$$ language plpgsql immutable;

-- Helper: given a class name like "ថ្នាក់ទី១ក", return "ថ្នាក់ទី២ក"
-- Returns null if grade >= 6 or can't parse
create or replace function generate_next_grade_class_name(p_class_name text)
returns text as $$
declare
  v_prefix  text := 'ថ្នាក់ទី';
  v_rest    text;
  v_digits  text := '';
  v_char    text;
  v_i       int;
  v_grade   int;
  v_suffix  text := '';
begin
  v_rest := ltrim(p_class_name, ' ');
  if strpos(v_rest, v_prefix) = 1 then
    v_rest := substring(v_rest from length(v_prefix) + 1);
  end if;
  for v_i in 1..length(v_rest) loop
    v_char := substring(v_rest from v_i for 1);
    if strpos('០១២៣៤៥៦៧៨៩', v_char) > 0 then
      v_digits := v_digits || v_char;
    else
      v_suffix := substring(v_rest from v_i);
      exit;
    end if;
  end loop;
  v_grade := khmer_to_int(v_digits);
  if v_grade is null or v_grade >= 6 then return null; end if;
  return v_prefix || int_to_khmer(v_grade + 1) || v_suffix;
end;
$$ language plpgsql immutable;

create or replace function perform_student_rollup(
  p_old_year_id uuid,
  p_new_year_id uuid
)
returns jsonb as $$
declare
  v_school_id    uuid := get_user_school_id();
  v_grade        int;
  v_old_classes  uuid[];
  v_new_classes  uuid[];
  v_old_count    int;
  v_new_count    int;
  v_copied       int;
  v_total_copied int := 0;
  v_graduated    int := 0;
  v_summary      jsonb := '[]'::jsonb;
  v_i            int;
  v_new_name     text;
  v_new_id       uuid;
  v_old_name     text;
begin
  if get_user_role() != 'admin' then
    raise exception 'Permission denied: admin only';
  end if;

  if p_old_year_id = p_new_year_id then
    raise exception 'Old and new academic year must be different';
  end if;

  for v_grade in 1..5 loop
    select array_agg(id order by class_name) into v_old_classes
    from classes
    where academic_year_id = p_old_year_id and school_id = v_school_id
      and extract_grade_from_class_name(class_name) = v_grade;

    v_old_count := coalesce(array_length(v_old_classes, 1), 0);
    if v_old_count = 0 then continue; end if;

    select array_agg(id order by class_name) into v_new_classes
    from classes
    where academic_year_id = p_new_year_id and school_id = v_school_id
      and extract_grade_from_class_name(class_name) = v_grade + 1;

    v_new_count := coalesce(array_length(v_new_classes, 1), 0);

    -- Auto-create missing target classes
    if v_new_count = 0 then
      v_new_classes := '{}'::uuid[];
      for v_i in 1..v_old_count loop
        select class_name into v_old_name from classes where id = v_old_classes[v_i];
        v_new_name := generate_next_grade_class_name(v_old_name);
        if v_new_name is not null then
          insert into classes (class_name, turn, academic_year_id, school_id)
          values (v_new_name, 'morning', p_new_year_id, v_school_id)
          returning id into v_new_id;
          v_new_classes := array_append(v_new_classes, v_new_id);
        end if;
      end loop;
      v_new_count := coalesce(array_length(v_new_classes, 1), 0);
    end if;

    if v_new_count = 0 then
      v_summary := v_summary || jsonb_build_object(
        'grade', v_grade, 'action', 'skipped', 'students_affected', 0
      );
      continue;
    end if;

    v_copied := 0;

    if v_new_count = v_old_count then
      for v_i in 1..v_old_count loop
        insert into students (school_id, real_id, full_name, gender, dob, address, phone_number, father_name, father_job, mother_name, mother_job, class_id, is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
        select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number, s.father_name, s.father_job, s.mother_name, s.mother_job, v_new_classes[v_i], s.is_scholarship, s.is_disability, false, p_new_year_id, now()
        from students s
        where s.class_id = v_old_classes[v_i]
          and s.is_graduated = false and s.school_id = v_school_id;
        get diagnostics v_copied = row_count;
      end loop;
    else
      insert into students (school_id, real_id, full_name, gender, dob, address, phone_number, father_name, father_job, mother_name, mother_job, class_id, is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
      select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number, s.father_name, s.father_job, s.mother_name, s.mother_job, v_new_classes[1], s.is_scholarship, s.is_disability, false, p_new_year_id, now()
      from students s
      where s.class_id = any(v_old_classes)
        and s.is_graduated = false and s.school_id = v_school_id;
      get diagnostics v_copied = row_count;
    end if;

    v_total_copied := v_total_copied + v_copied;
    v_summary := v_summary || jsonb_build_object(
      'grade', v_grade,
      'action', case when v_new_count = v_old_count then 'paired' else 'merged' end,
      'students_moved', v_copied
    );
  end loop;

  -- Grade 6 → copy with is_graduated = true
  select array_agg(id) into v_old_classes
  from classes
  where academic_year_id = p_old_year_id and school_id = v_school_id
    and extract_grade_from_class_name(class_name) = 6;

  if v_old_classes is not null then
    insert into students (school_id, real_id, full_name, gender, dob, address, phone_number, father_name, father_job, mother_name, mother_job, class_id, is_scholarship, is_disability, is_graduated, academic_year_id, updated_at)
    select s.school_id, s.real_id, s.full_name, s.gender, s.dob, s.address, s.phone_number, s.father_name, s.father_job, s.mother_name, s.mother_job, null, s.is_scholarship, s.is_disability, true, p_new_year_id, now()
    from students s
    where s.class_id = any(v_old_classes)
      and s.is_graduated = false and s.school_id = v_school_id;
    get diagnostics v_graduated = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'total_promoted', v_total_copied,
    'total_graduated', v_graduated,
    'details', v_summary
  );
end;
$$ language plpgsql security definer;
