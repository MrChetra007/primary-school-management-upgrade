-- ============================================================
-- Seed data for teacher_phrases
-- ឃ្លាប្រើញឹកញាប់ (Frequently Used Phrases) - Improved for Formal Report Cards
-- ============================================================
-- HOW TO USE:
--   1. Find your school_id:
--        SELECT id FROM schools WHERE name_khmer ILIKE '%your school%';
--   2. Find your teacher_id:
--        SELECT id FROM teachers WHERE full_name ILIKE '%your name%';
--   3. Replace the IDs below and run this SQL in Supabase SQL Editor.
-- ============================================================

do $$
declare
  v_school_id uuid := '00000000-0000-0000-0000-000000000000';  -- ← CHANGE ME
  v_teacher_id uuid := '00000000-0000-0000-0000-000000000000'; -- ← CHANGE ME
begin

-- ============================================================
-- Khmer phrases (Formal feedback for Cambodian report cards)
-- ============================================================

insert into teacher_phrases (school_id, teacher_id, phrase_text, sort_order) values
  -- Positive Academic Feedback (លទ្ធផលសិក្សាល្អ)
  (v_school_id, v_teacher_id, 'សូមអបអរសាទរ! កូនរបស់អ្នកទទួលបានលទ្ធផលល្អប្រសើរ និងគួរជាទីមោទនៈ។', 1),
  (v_school_id, v_teacher_id, 'កូនរបស់អ្នកមានវឌ្ឍនភាពគួរឱ្យកត់សម្គាល់ក្នុងការសិក្សានៅឆមាសនេះ។', 2),
  (v_school_id, v_teacher_id, 'សិស្សមានភាពឈ្លាសវៃ និងចូលរួមយ៉ាងសកម្មក្នុងការងារក្រុមរាល់ម៉ោងសិក្សា។', 3),

  -- Behavior & Attendance (អាកប្បកិរិយា និងវត្តមាន)
  (v_school_id, v_teacher_id, 'កូនរបស់អ្នកមានវត្តមានទៀងទាត់ និងខិតខំប្រឹងប្រែងរៀនសូត្របានល្អ។', 4),
  (v_school_id, v_teacher_id, 'សិស្សមានអាកប្បកិរិយាល្អ សុជីវធម៌ល្អ និងគោរពបទបញ្ជាផ្ទៃក្នុងសាលាបានខ្ជាប់ខ្ជួន។', 5),
  (v_school_id, v_teacher_id, 'កូនរបស់អ្នកចេះជួយទុកធុរៈមិត្តរួមថ្នាក់ និងមានទំនាក់ទំនងល្អជាមួយអ្នកដទៃ។', 6),

  -- Areas for Improvement (ចំណុចត្រូវកែលម្អ)
  (v_school_id, v_teacher_id, 'កូនរបស់អ្នកមានសមត្ថភាពល្អ ប៉ុន្តែត្រូវការការយកចិត្តទុកដាក់បន្ថែមទៀតក្នុងម៉ោងសិក្សា។', 7),
  (v_school_id, v_teacher_id, 'សិស្សត្រូវការការហ្វឹកហាត់ និងយកចិត្តទុកដាក់បន្ថែមលើការគណនា និងដោះស្រាយលំហាត់។', 8),
  (v_school_id, v_teacher_id, 'សូមជំរុញឱ្យកូនក្លាហានក្នុងការសួរសំណួរពេលមានចម្ងល់ ឬមិនយល់មេរៀន។', 9),

  -- Calls to Action for Parents (សំណូមពរដល់អាណាព្យាបាល)
  (v_school_id, v_teacher_id, 'សូមមាតាបិតា ឬអាណាព្យាបាល ជួយតាមដាន និងជំរុញការសិក្សារបស់កូនបន្ថែមនៅផ្ទះ។', 10),
  (v_school_id, v_teacher_id, 'សូមមាតាបិតា ឬអាណាព្យាបាល ជួយពិនិត្យកិច្ចការផ្ទះ និងលើកទឹកចិត្តកូនឱ្យអានសៀវភៅជាប្រចាំ។', 11),
  (v_school_id, v_teacher_id, 'សូមមាតាបិតា ឬអាណាព្យាបាល ជួយដាស់តឿនកូនឱ្យមកសាលារៀនបានទាន់ពេលវេលាជារៀងរាល់ថ្ងៃ។', 12),
  
  -- Closing/Appreciation (ការថ្លែងអំណរគុណ)
  (v_school_id, v_teacher_id, 'សាលារៀនសូមថ្លែងអំណរគុណយ៉ាងជ្រាលជ្រៅចំពោះការសហការល្អពីសំណាក់លោកអ្នក។', 13);

end $$;