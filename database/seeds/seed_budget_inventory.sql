-- ============================================================
-- Dummy Data Seeder: budget_transactions + inventory_items
-- Uses subqueries to resolve school_id / academic_year_id so
-- it works regardless of the actual UUIDs in your database.
-- Run from Supabase SQL editor.
-- ============================================================

-- ── BUDGET TRANSACTIONS ────────────────────────────────────

-- Income
insert into budget_transactions (school_id, academic_year_id, type, date, description, category, amount, note)
select
  s.id,
  ay.id,
  'income',
  d::date,
  descr,
  cat,
  amt,
  n
from (values
  ('2026-01-10', 'Government Grant — Q1',        'Government Funding',  15000000, 'Monthly operational support from MoEYS'),
  ('2026-02-05', 'School Fee Collection — Jan',   'Tuition & Fees',      3200000,  'Paid by 320 students @ 10,000 Riel'),
  ('2026-03-01', 'NGO Donation — Room to Read',   'Donations',           8500000,  'Library improvement grant'),
  ('2026-04-12', 'School Fee Collection — Apr',   'Tuition & Fees',      3100000,  'Partial payments received'),
  ('2026-05-08', 'Government Grant — Q2',         'Government Funding',  15000000, 'Monthly operational support from MoEYS'),
  ('2026-06-15', 'Graduation Ceremony Sponsorship','Events & Sponsorship',2000000,  'Local business sponsorship for grade 6 event'),
  ('2026-07-01', 'School Fee Collection — Jul',   'Tuition & Fees',      3250000,  'New semester fee collection'),
  ('2026-07-20', 'Book Fair Revenue',             'Events & Sponsorship',1200000,  'Second-hand book sale to parents')
) t(d, descr, cat, amt, n)
cross join schools s
cross join academic_years ay
where ay.year_name = (select max(year_name) from academic_years)
limit 8;

-- Expense
insert into budget_transactions (school_id, academic_year_id, type, date, description, category, amount, note)
select
  s.id,
  ay.id,
  'expense',
  d::date,
  descr,
  cat,
  amt,
  n
from (values
  ('2026-01-15', 'Teacher Salaries — Jan',     'Salaries',          9200000,  'Paid to 12 teachers + 1 admin'),
  ('2026-01-22', 'Office Supplies Purchase',   'Supplies',          780000,   'Paper, pens, printer ink, staples'),
  ('2026-02-10', 'Electricity Bill — Jan',     'Utilities',         450000,   'Electricite du Cambodge'),
  ('2026-02-18', 'Water Supply — Jan',         'Utilities',         120000,   'Water authority payment'),
  ('2026-03-05', 'Teacher Salaries — Mar',     'Salaries',          9200000,  'Monthly payroll'),
  ('2026-03-20', 'School Maintenance — Roof',  'Maintenance',       2400000,  'Classroom B roof leak repair'),
  ('2026-04-02', 'Internet & Phone',           'Utilities',         320000,   'Monthly ISP + school phone line'),
  ('2026-04-25', 'Sports Equipment',           'Supplies',          950000,   'Volleyball net, balls, jump ropes'),
  ('2026-05-12', 'Teacher Salaries — May',     'Salaries',          9200000,  'Monthly payroll'),
  ('2026-05-28', 'Library Books Purchase',     'Education Materials',1800000,  'Khmer storybooks + reference books'),
  ('2026-06-08', 'Electricity Bill — May',     'Utilities',         510000,   'Higher usage due to hot season fans'),
  ('2026-06-25', 'Cleaning Supplies',          'Supplies',          340000,   'Soap, buckets, brooms, disinfectant'),
  ('2026-07-03', 'Teacher Salaries — Jul',     'Salaries',          9600000,  'Includes overtime for exam grading'),
  ('2026-07-18', 'Graduation Ceremony Costs',  'Events & Activities',1500000,  'Certificates, refreshments, decorations')
) t(d, descr, cat, amt, n)
cross join schools s
cross join academic_years ay
where ay.year_name = (select max(year_name) from academic_years)
limit 14;

-- ── INVENTORY ITEMS ────────────────────────────────────────

insert into inventory_items (school_id, name, category, quantity, min_stock, location, condition, description)
select
  s.id,
  name,
  cat,
  qty,
  min_stk,
  loc,
  cond,
  descr
from (values
  ('Whiteboard (Large)',    'Classroom Equipment',  12, 2,  'Classrooms A1–A6',  'Good',       'Magnetic whiteboard 240×120cm'),
  ('Whiteboard Markers',    'Supplies',              48, 10, 'Store Room',         'New',        'Assorted colors, box of 12'),
  ('Student Desk (2-seat)', 'Furniture',             80, 5,  'Classrooms',         'Fair',       'Wooden double desk, some scratches'),
  ('Teacher Desk',          'Furniture',             10, 1,  'Staff Room',         'Good',       'With drawer and lock'),
  ('Plastic Chair',         'Furniture',            160, 10, 'Classrooms + Hall',  'Good',       'Stackable blue chairs'),
  ('Chalkboard',            'Classroom Equipment',    6, 1,  'Classrooms B1–B3',   'Worn',       'Traditional green chalkboard'),
  ('Chalk Box (50 pcs)',    'Supplies',              12, 5,  'Store Room',         'New',        'White chalk for chalkboards'),
  ('Laptop (Teacher Use)',  'Electronics',           10, 1,  'Staff Room',         'Good',       'Dell Latitude, Windows 11'),
  ('Printer (Laser)',       'Electronics',            2, 1,  'Office',             'Fair',       'HP LaserJet, needs toner soon'),
  ('Projector',             'Electronics',            4, 1,  'Store Room',         'Good',       'Epson LCD projector with remote'),
  ('Water Filter',          'Facilities',             6, 1,  'Each floor',         'Good',       'Ceramic filter, 20L capacity'),
  ('First Aid Kit',         'Health & Safety',        5, 2,  'Office + Classrooms', 'Good',      'Basic medical supplies box'),
  ('Fire Extinguisher',     'Health & Safety',        4, 1,  'Hallways',           'Good',       'ABC dry powder, 6kg'),
  ('Volleyball Set',        'Sports',                 2, 1,  'Sports Shed',        'Fair',       'Net + ball + pump'),
  ('Soccer Ball',           'Sports',                 6, 2,  'Sports Shed',        'Worn',       'Size 4, used'),
  ('Library Bookshelf',     'Furniture',              4, 1,  'Library',            'Good',       'Steel frame, 5 shelves'),
  ('Dictionary (Khmer)',    'Education Materials',    15, 3,  'Library',            'Good',       'Chuon Nath dictionary'),
  ('Dictionary (English)',  'Education Materials',    10, 2,  'Library',            'Good',       'Oxford paperback'),
  ('Desk Lamp',             'Electronics',             8, 2,  'Staff Room',         'Good',       'LED desk lamp, USB powered'),
  ('Broom & Dustpan Set',   'Cleaning',               15, 5,  'Cleaning Closet',    'Good',       'Bamboo broom + plastic dustpan')
) t(name, cat, qty, min_stk, loc, cond, descr)
cross join schools s
limit 20;
