-- ============================================================
-- seed_library.sql — Library Dummy Data Seeder
-- Schema: v10 (books + book_borrows)
--
-- PREREQUISITES (run in order):
--   1. schema_v10.sql
--   2. seeder.sql (or equivalent with schools + students)
--
-- WHAT THIS SEEDS:
--   • 18 books across 6 categories (សៀវភៅសិក្សា, អក្សរសាស្ត្រ,
--     វិទ្យាសាស្ត្រ, ប្រវត្តិ, ភាសា, រឿងនិទាន)
--   • 16 borrow records with a mix of returned/borrowed/overdue
--
-- HOW TO RUN:
--   Paste into Supabase SQL Editor and execute.
-- ============================================================

-- ============================================================
-- STEP 1: BOOKS — School 1 (Chaktomuk)
-- ============================================================

insert into books (school_id, title, author, isbn, category, total_copies, available_copies)
select
  '00000000-0000-0000-0000-000000000010'::uuid,
  title,
  author,
  isbn,
  category,
  total_copies,
  available_copies
from (values
  ('ភាសាខ្មែរ ថ្នាក់ទី១',     'ក្រសួងអប់រំ',       '978-99950-0-101-1', 'សៀវភៅសិក្សា',   15, 12),
  ('គណិតវិទ្យា ថ្នាក់ទី១',     'ក្រសួងអប់រំ',       '978-99950-0-102-2', 'សៀវភៅសិក្សា',   15, 13),
  ('ភាសាខ្មែរ ថ្នាក់ទី២',     'ក្រសួងអប់រំ',       '978-99950-0-103-3', 'សៀវភៅសិក្សា',   12, 10),
  ('គណិតវិទ្យា ថ្នាក់ទី២',     'ក្រសួងអប់រំ',       '978-99950-0-104-4', 'សៀវភៅសិក្សា',   12, 11),
  ('វិទ្យាសាស្ត្រ ថ្នាក់ទី៤',    'ក្រសួងអប់រំ',       '978-99950-0-105-5', 'សៀវភៅសិក្សា',   10,  8),
  ('ភាសាអង់គ្លេស ថ្នាក់ទី៤',   'ក្រសួងអប់រំ',       '978-99950-0-106-6', 'សៀវភៅសិក្សា',   10,  7),
  ('រឿងព្រេងខ្មែរ',            'សោម ច័ន្ទរតន៍',      '978-99950-0-107-7', 'អក្សរសាស្ត្រ',   8,   6),
  ('រឿងនិទានកុមារ',             'ណូ សុភា',           '978-99950-0-108-8', 'រឿងនិទាន',      6,   5),
  ('ប្រវត្តិសាស្ត្រខ្មែរ',        'ដួង សុខហៃ',        '978-99950-0-109-9', 'ប្រវត្តិ',       5,   4),
  ('ពិភពវិទ្យាសាស្ត្រកុមារ',     'ចន ឌូ',             '978-99950-0-110-0', 'វិទ្យាសាស្ត្រ',   4,   4),
  ('រៀនគូររូប',                'ម៉ាក សុខឃី',         '978-99950-0-111-1', 'វិទ្យាសាស្ត្រ',   3,   2),
  ('វចនានុក្រមខ្មែរ',             'សម្តេច ជួន ណាត',   '978-99950-0-112-2', 'អក្សរសាស្ត្រ',   2,   1)
) as b(title, author, isbn, category, total_copies, available_copies)
where not exists (
  select 1 from books
  where school_id = '00000000-0000-0000-0000-000000000010'
    and title = b.title
);

-- ============================================================
-- STEP 2: BOOKS — School 2 (Angkor)
-- ============================================================

insert into books (school_id, title, author, isbn, category, total_copies, available_copies)
select
  '00000000-0000-0000-0000-000000000020'::uuid,
  title,
  author,
  isbn,
  category,
  total_copies,
  available_copies
from (values
  ('ភាសាខ្មែរ ថ្នាក់ទី២',     'ក្រសួងអប់រំ',       '978-99950-0-201-1', 'សៀវភៅសិក្សា',   12, 10),
  ('គណិតវិទ្យា ថ្នាក់ទី២',     'ក្រសួងអប់រំ',       '978-99950-0-202-2', 'សៀវភៅសិក្សា',   12, 11),
  ('ភាសាខ្មែរ ថ្នាក់ទី៥',     'ក្រសួងអប់រំ',       '978-99950-0-203-3', 'សៀវភៅសិក្សា',   10,  9),
  ('គណិតវិទ្យា ថ្នាក់ទី៥',     'ក្រសួងអប់រំ',       '978-99950-0-204-4', 'សៀវភៅសិក្សា',   10,  8),
  ('English Grade 5',           'MoEYS',              '978-99950-0-205-5', 'សៀវភៅសិក្សា',   8,   6),
  ('ប្រជុំរឿងនិទានខ្មែរ',      'លឹម ច័ន្ទ',          '978-99950-0-206-6', 'រឿងនិទាន',      5,   4)
) as b(title, author, isbn, category, total_copies, available_copies)
where not exists (
  select 1 from books
  where school_id = '00000000-0000-0000-0000-000000000020'
    and title = b.title
);

-- ============================================================
-- STEP 3: BOOK BORROWS — School 1
-- ============================================================

insert into book_borrows (school_id, book_id, student_id, borrow_date, due_date, return_date, status)
select
  '00000000-0000-0000-0000-000000000010'::uuid,
  b.id,
  s.id,
  borrow_date::date,
  due_date::date,
  return_date::date,
  status::borrow_status
from (values
  -- Returned borrows
  ('រឿងព្រេងខ្មែរ',       'S1-001', '2025-03-01', '2025-03-15', '2025-03-14', 'returned'),
  ('រឿងនិទានកុមារ',        'S1-002', '2025-03-05', '2025-03-19', '2025-03-18', 'returned'),
  ('ភាសាខ្មែរ ថ្នាក់ទី១',    'S1-003', '2025-03-10', '2025-03-24', '2025-03-22', 'returned'),
  ('គណិតវិទ្យា ថ្នាក់ទី១',     'S1-004', '2025-04-01', '2025-04-15', '2025-04-14', 'returned'),
  ('ប្រវត្តិសាស្ត្រខ្មែរ',     'S1-005', '2025-04-05', '2025-04-19', '2025-04-18', 'returned'),
  ('រឿងនិទានកុមារ',        'S1-005', '2025-05-01', '2025-05-15', '2025-05-12', 'returned'),
  ('វចនានុក្រមខ្មែរ',       'S1-006', '2025-05-05', '2025-05-19', '2025-05-20', 'returned'),
  -- Currently borrowed
  ('ភាសាខ្មែរ ថ្នាក់ទី១',    'S1-001', '2025-06-01', '2025-06-15', null,       'borrowed'),
  ('រឿងព្រេងខ្មែរ',       'S1-004', '2025-06-02', '2025-06-16', null,       'borrowed'),
  ('រៀនគូររូប',             'S1-002', '2025-06-03', '2025-06-17', null,       'borrowed'),
  -- Overdue
  ('ពិភពវិទ្យាសាស្ត្រកុមារ',  'S1-003', '2025-05-10', '2025-05-24', null,       'overdue'),
  ('ប្រវត្តិសាស្ត្រខ្មែរ',     'S1-006', '2025-05-15', '2025-05-29', null,       'overdue')
) as r(book_title, student_real_id, borrow_date, due_date, return_date, status)
join books b on b.school_id = '00000000-0000-0000-0000-000000000010' and b.title = r.book_title
join students s on s.school_id = '00000000-0000-0000-0000-000000000010' and s.real_id = r.student_real_id
where not exists (
  select 1 from book_borrows bb
  where bb.school_id = '00000000-0000-0000-0000-000000000010'
    and bb.book_id = b.id
    and bb.student_id = s.id
    and bb.borrow_date = r.borrow_date::date
);

-- ============================================================
-- STEP 4: BOOK BORROWS — School 2 (Angkor)
-- ============================================================

insert into book_borrows (school_id, book_id, student_id, borrow_date, due_date, return_date, status)
select
  '00000000-0000-0000-0000-000000000020'::uuid,
  b.id,
  s.id,
  borrow_date::date,
  due_date::date,
  return_date::date,
  status::borrow_status
from (values
  ('ប្រជុំរឿងនិទានខ្មែរ', 'S2-001', '2025-03-15', '2025-03-29', '2025-03-28', 'returned'),
  ('គណិតវិទ្យា ថ្នាក់ទី២',     'S2-002', '2025-04-01', '2025-04-15', '2025-04-15', 'returned'),
  ('English Grade 5',          'S2-004', '2025-04-10', '2025-04-24', '2025-04-22', 'returned'),
  ('ប្រជុំរឿងនិទានខ្មែរ',  'S2-003', '2025-05-01', '2025-05-15', null,       'borrowed'),
  ('English Grade 5',          'S2-005', '2025-05-05', '2025-05-19', null,       'borrowed'),
  ('ភាសាខ្មែរ ថ្នាក់ទី២',    'S2-001', '2025-05-10', '2025-05-24', null,       'borrowed'),
  ('ភាសាខ្មែរ ថ្នាក់ទី៥',    'S2-101', '2025-06-01', '2025-06-15', null,       'borrowed'),
  ('គណិតវិទ្យា ថ្នាក់ទី៥',     'S2-102', '2025-06-02', '2025-06-16', null,       'borrowed'),
  ('ភាសាខ្មែរ ថ្នាក់ទី២',    'S2-003', '2025-04-20', '2025-05-04', null,       'overdue'),
  ('English Grade 5',          'S2-104', '2025-04-25', '2025-05-09', null,       'overdue')
) as r(book_title, student_real_id, borrow_date, due_date, return_date, status)
join books b on b.school_id = '00000000-0000-0000-0000-000000000020' and b.title = r.book_title
join students s on s.school_id = '00000000-0000-0000-0000-000000000020' and s.real_id = r.student_real_id
where not exists (
  select 1 from book_borrows bb
  where bb.school_id = '00000000-0000-0000-0000-000000000020'
    and bb.book_id = b.id
    and bb.student_id = s.id
    and bb.borrow_date = r.borrow_date::date
);

-- ============================================================
-- VERIFY
-- ============================================================

select 'books' as table_name, school_id, count(*) as total
from books
where school_id in (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000020'
)
group by school_id
union all
select 'book_borrows' as table_name, school_id, count(*) as total
from book_borrows
where school_id in (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000020'
)
group by school_id
order by table_name, school_id;
