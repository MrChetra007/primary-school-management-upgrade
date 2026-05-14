# 🏫 Primary School Management System — Roadmap v13

> **Stack:** Vue 3 + Vite + Tailwind CSS + Supabase
> **Roles:** Admin/Director · Teacher · Librarian · Parent (anon)

---

## 🧠 Core Design Decisions

### Every User IS a Teacher

In Cambodian schools, all staff members are teachers. The librarian is a teacher who manages the library. The admin/director is a teacher who runs the school. Therefore:

- **Every user account** always has a matching `teachers` row (personal profile)
- The `role` field in `public.users` only controls **what they can access** in the app — not who they are
- There is no such thing as a user without a teacher profile
- `teachers.user_id` is `NOT NULL UNIQUE` — one profile per account, always linked

### User → Teacher Connection

```
auth.users
    ↓ id (cascade delete)
public.users        ← role (admin/teacher/librarian), status (active/inactive)
    ↓ user_id (not null, unique)
teachers            ← full_name, gender, dob, phone, degree, address, profile_url
    ↓ id
classes             ← teacher_id → which teacher owns which class
    ↓ id
students            ← class_id → which class each student belongs to
```

---

## 📁 Project Folder Structure

```
src/
├── assets/                  # Images, icons, fonts
├── components/
│   ├── common/              # Shared UI components (Button, Modal, Table, Badge...)
│   ├── admin/               # Admin-specific components
│   ├── teacher/             # Teacher-specific components
│   ├── librarian/           # Librarian-specific components
│   └── parent/              # Parent portal components
├── composables/             # Reusable logic (useAuth, useScore, useAttendance...)
├── layouts/
│   ├── AdminLayout.vue       # Sidebar + Topbar — used for ALL /admin/* EXCEPT academic-years
│   ├── TeacherLayout.vue
│   ├── LibrarianLayout.vue
│   └── ParentLayout.vue
├── lib/
│   └── supabase.js          # Supabase client init
├── router/
│   └── index.js             # Vue Router + route guards
├── stores/
│   ├── auth.js              # Pinia: auth state, role, school_id
│   ├── academicYear.js      # Pinia: { academicYearId, yearName } — persisted to localStorage
│   ├── school.js            # Pinia: { schoolId, schoolName, schoolCode } — persisted
│   ├── student.js
│   ├── score.js
│   ├── classSubjects.js
│   └── attendance.js
├── views/
│   ├── auth/
│   │   └── LoginView.vue          # Standalone — no layout
│   ├── admin/
│   │   ├── AcademicYearView.vue   # Standalone — no layout (Layer 1)
│   │   ├── DashboardView.vue      # Uses AdminLayout (Layer 2)
│   │   └── ...                    # All other admin views use AdminLayout
│   ├── teacher/
│   ├── librarian/
│   └── parent/
├── utils/
│   ├── scoreCalculator.js   # computeMonthlyAverage, computeSemesterAverage, computeRank
│   ├── formatDate.js
│   └── exportPdf.js         # generateMonthlyScorePDF, generateSemesterScorePDF
├── App.vue
└── main.js
```

---

## 🗺️ Pages by Role

### 🔐 Standalone Pages (NO layout — no sidebar, no topbar)

| Route | Page |
|---|---|
| `/` | Landing page — what is this app, features, schools using it, contact |
| `/login` | Login page (all roles — email + password only, system auto-detects role + school) |
| `/unauthorized` | No access page |
| `/admin/academic-years` | **Admin only.** Academic year selector — Layer 1 entry point |

> These pages render on their own with a clean blank background. No layout wrapping them.

---

### 🦸 Super Admin Pages `/super` (Tra only)
> Accessible only if `role = super_admin`. Same design theme as admin.

| Route | Page |
|---|---|
| `/super/dashboard` | Overview of ALL schools — total schools, students, teachers across platform |
| `/super/schools` | Schools list — create, edit, activate/deactivate schools |
| `/super/schools/new` | Create new school + first admin account (calls Edge Function) |
| `/super/schools/:id` | Individual school detail — info, usage stats, manage first admin |

---

### 👨‍💼 Admin Pages `/admin`

> **Two-layer system:**
>
> - **Layer 1** → `/admin/academic-years` — Standalone page, no layout. Admin selects which academic year to work in.
> - **Layer 2** → All other `/admin/*` pages — Use `AdminLayout` (sidebar + topbar). All data is scoped to the selected academic year from the Pinia store.

#### 🔑 Layer 1 — Academic Year Page (Standalone, no layout)

| Route                   | Page                   | Notes                                                                                                                                                                                                  |
| ----------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/admin/academic-years` | Academic year selector | Has **Logout** button top-right. CRUD academic years. Click **"មើល"** → saves `academic_year_id` to Pinia store → navigates to `/admin/dashboard`. Has **Student Rollup** button per year (see below). |

#### 📊 Layer 2 — Inside AdminLayout (sidebar + topbar)

> Topbar shows: **selected year badge** + **"← ប្តូរឆ្នាំ"** back button that returns to `/admin/academic-years`

| Route                        | Page                                                                     |
| ---------------------------- | ------------------------------------------------------------------------ |
| `/admin/dashboard`           | Overview stats scoped to selected academic year                          |
| `/admin/school`              | School information (edit name, logo, director)                           |
| `/admin/subjects`            | Subject CRUD                                                             |
| `/admin/classes`             | Class CRUD (assign teacher, set turn, assign subjects per class)         |
| `/admin/teachers`            | Teacher profile management                                               |
| `/admin/students`            | All students CRUD — scoped to selected year                              |
| `/admin/students/:id`        | Student detail + health + growth + vaccinations                          |
| `/admin/attendance/students` | Student attendance (view all classes, filter by class/date)              |
| `/admin/attendance/teachers` | Teacher attendance (view & manage all)                                   |
| `/admin/scores`              | Scores — filter by class + score type + month                            |
| `/admin/health`              | Student health records overview                                          |
| `/admin/sick-days`           | Sick days overview                                                       |
| `/admin/holidays`            | School holidays CRUD — scoped to selected year                           |
| `/admin/budget`              | Budget transactions (income/expense CRUD)                                |
| `/admin/inventory`           | Inventory items CRUD                                                     |
| `/admin/library`             | Library overview (books + borrows, read-only)                            |
| `/admin/users`               | User management — create, edit, deactivate/reactivate all staff accounts |

---

### 👩‍🏫 Teacher Pages `/teacher`

| Route                              | Page                                                   |
| ---------------------------------- | ------------------------------------------------------ |
| `/teacher/dashboard`               | Class overview                                         |
| `/teacher/students`                | Their class students list                              |
| `/teacher/students/:id`            | Student detail                                         |
| `/teacher/attendance`              | Mark daily student attendance                          |
| `/teacher/attendance/monthly`      | Monthly student attendance — calendar view             |
| `/teacher/attendance/my`           | Own attendance — monthly calendar view                 |
| `/teacher/scores`                  | Score management — select Monthly or Semester mode     |
| `/teacher/scores/monthly`          | Monthly score entry                                    |
| `/teacher/scores/semester`         | Semester score entry                                   |
| `/teacher/scores/ranking`          | Score ranking — monthly/semester ranked list + stats   |
| `/teacher/scores/certificates`     | Certificate design — generate Top 5 award certificates |
| `/teacher/sick-days`               | Add & manage student sick days                         |
| `/teacher/growth`                  | Add & view student growth                              |
| `/teacher/vaccinations`            | View student vaccinations                              |
| `/teacher/holidays`                | View school holidays (read only)                       |
| `/teacher/reports`                 | Print class attendance & score reports                 |

---

### 📚 Librarian Pages `/librarian`

| Route                  | Page                  |
| ---------------------- | --------------------- |
| `/librarian/dashboard` | Books overview        |
| `/librarian/books`     | Book CRUD             |
| `/librarian/borrows`   | Issue & return books  |
| `/librarian/overdue`   | Overdue tracking list |

---

### 👨‍👩‍👧 Parent Portal `/parent`

| Route                              | Page                             |
| ---------------------------------- | -------------------------------- |
| `/parent`                          | Search form (student name + DOB) |
| `/parent/student/:id`              | Student overview dashboard       |
| `/parent/student/:id/attendance`   | Monthly attendance               |
| `/parent/student/:id/scores`       | Monthly & semester scores        |
| `/parent/student/:id/health`       | Health profile + checkups        |
| `/parent/student/:id/growth`       | Growth chart                     |
| `/parent/student/:id/vaccinations` | Vaccination records              |
| `/parent/student/:id/sick-days`    | Sick day history                 |

---

## 📊 Score Calculation Logic

### Monthly Score

```
Teacher enters: subject1, subject2, subject3... (per student, for that month)
monthly_average = sum(all subject scores) / count(subjects)
rank            = order by monthly_average DESC within class
```

### Semester Score

```
Step 1 — Semester exam (teacher enters):
  subject1, subject2, subject3...
  semester_exam_average = sum(semester exam subjects) / count(subjects)

Step 2 — Monthly averages (auto-pulled from DB, read-only):
  Month1_avg, Month2_avg, Month3_avg
  monthly_average = (Month1_avg + Month2_avg + Month3_avg) / 3

Step 3 — Final semester average:
  semester_average = (monthly_average + semester_exam_average) / 2

Step 4 — Rank:
  rank = order by semester_average DESC within class
```

### Rank Rules

- Ranked **within class only**
- Ties get the **same rank** (1,1,3...)
- Calculated on the **frontend** in `scoreCalculator.js` — not stored in DB

---

## 🔄 Student Rollup Logic (v7)

At the start of a new academic year, the admin runs **Student Rollup** to promote all students to their next grade class automatically.

### How it works

```
Grade 1 → Grade 2
Grade 2 → Grade 3
Grade 3 → Grade 4
Grade 4 → Grade 5
Grade 5 → Grade 6
Grade 6 → Graduated (is_graduated = true, class_id = null)
```

### Class Matching Rules

The system parses the grade number from class names using the pattern `ថ្នាក់ទី{Khmer digit(s)}{letter}`:

| Old year classes | New year classes | Action                                              |
| ---------------- | ---------------- | --------------------------------------------------- |
| ២ក, ២ខ           | ៣ក, ៣ខ           | **Paired by order** — ២ក→៣ក, ២ខ→៣ខ                  |
| ២ក, ២ខ           | ៣ក only          | **Merged** — all students into ៣ក                   |
| ២ក, ២ខ, ២គ       | ៣ក, ៣ខ           | **Merged** — all into ៣ក (admin reassigns manually) |
| ២ក               | (none)           | **Skipped** — no matching next-grade class found    |

### Grade 6 Students

- `is_graduated` set to `true`
- `class_id` set to `null`
- `academic_year_id` updated to new year
- Historical data (scores, attendance, health) remains linked via `student_id`

### DB Function

```sql
select perform_student_rollup(old_year_id, new_year_id);
-- Returns jsonb summary:
-- { success, total_promoted, total_graduated, details: [...per grade] }
```

### UI Flow (on `/admin/academic-years`)

1. Admin creates new academic year + creates next year's classes
2. Admin clicks **"បញ្ជូនសិស្សទៅឆ្នាំថ្មី"** (Student Rollup) on the old year card
3. Modal opens showing:
   - Source year → Target year selector
   - Preview table: per-grade mapping (old classes → new classes, student count, action)
   - Warning for any skipped or mismatched grades
4. Admin confirms → `perform_student_rollup()` called → results shown (X promoted, X graduated)
5. Admin can then manually reassign any students that ended up in wrong class

### What rolls over

- ✅ Student basic info (name, DOB, gender, parents, address — unchanged)
- ✅ All historical data stays linked (health, vaccinations, scores, attendance — via `student_id`)
- ✅ `class_id` + `academic_year_id` updated to new year
- ❌ No data is duplicated or copied

### Schema changes (v6 → v7)

```sql
-- New column
alter table students add column is_graduated boolean not null default false;

-- New helper functions
khmer_to_int(text) → int
int_to_khmer(int) → text
extract_grade_from_class_name(text) → int

-- Main rollup function
perform_student_rollup(old_year_id uuid, new_year_id uuid) → jsonb
```

---

## 🚀 Development Phases

---

### ✅ Phase 0 — Database

- [x] Write `schema.sql` (all tables + enums)
- [x] Write RLS policies per role
- [x] Setup Supabase storage bucket `teacher-profiles`
- [x] Add `user_status` enum + `users.status` column
- [x] Refactor `teachers.user_id` to `NOT NULL UNIQUE`
- [x] Add `class_subjects` junction table (v6)
- [x] Add `is_graduated` to students + rollup function (v7)
- [x] Run `migrate_v6_to_v7.sql` on Supabase project
- [ ] Run `migration_v7_v8.sql` — multi-tenant (school_id on all tables + indexes + new RLS)

---

### ✅ Phase 1 — Project Setup

- [x] Init Vite + Vue 3
- [x] Tailwind CSS
- [x] Supabase client
- [x] Folder structure
- [x] Edge Function `manage-user` (updated to accept school_id)

---

### ✅ Phase 2 — Auth & Role Routing

- [x] Login page (email + password — system auto-detects role + school)
- [x] Pinia `auth` store (session, user, role, school_id)
- [x] Pinia `academicYear` store
- [x] Pinia `school` store (schoolId, schoolName — persisted to localStorage)
- [x] Vue Router + route guards:
  - `super_admin` → `/super/dashboard`
  - `admin` → `/admin/academic-years`
  - `teacher` → `/teacher/dashboard`
  - `librarian` → `/librarian/dashboard`
- [x] AdminLayout topbar (year badge + back button)
- [x] Inactive user check
- [x] Logout → clears auth + academicYear + school stores

---

### ✅ Phase 3 — Admin Features

- [x] Academic Year page (Layer 1 standalone)
- [x] School information
- [x] Subject CRUD
- [x] Class CRUD + subject assignment per class
- [x] Student CRUD + student detail
- [x] Teacher profile management
- [x] Student attendance (view + printable grid)
- [x] Teacher attendance (view + manage)
- [x] Scores (view + filter + PDF)
- [x] Finance & inventory
- [x] Library overview
- [x] User management (create/edit/deactivate/delete via Edge Function)
- [ ] **Student Rollup UI** — rollup modal on Academic Years page (v7)

---

### ✅ Phase 4 — Teacher Features

- [x] Dashboard
- [x] Class & students management
- [x] Student attendance (bulk mark + monthly calendar + printable grid)
- [x] Teacher own attendance (monthly calendar view)
- [x] Monthly score entry (dynamic subjects + average + rank + PDF)
- [x] Semester score entry (monthly averages pulled + semester calc + PDF)
- [x] Health & wellness (sick days, growth, vaccinations)
- [x] Reports

---

### ✅ Phase 5 — Librarian Features

- [x] Dashboard
- [x] Book CRUD
- [x] Issue & return books
- [x] Overdue list

---

### ✅ Phase 6 — Parent Portal

- [x] Search page (name + DOB)
- [x] Student overview dashboard
- [x] Attendance tab (monthly calendar)
- [x] Scores tab (monthly & semester)
- [x] Health tab
- [x] Growth chart
- [x] Vaccinations tab
- [x] Sick days tab
- [x] Mobile responsive + Khmer language

---

### ✅ Phase 7 — Student Rollup (v7) ← DONE

- [x] Run `migrate_v6_to_v7.sql` on Supabase
- [x] Build rollup modal on `/admin/academic-years`
- [x] Test with real data at Battambang school
- [x] Handle edge case: students already rolled up

---

### 🔧 Phase 8 — Stabilize & Polish ← CURRENT

- [ ] Complete team testing at Battambang school
- [ ] Fix bugs from real user feedback
- [ ] Teacher training
- [ ] Loading states & skeleton loaders
- [ ] Empty states
- [ ] Toast notifications
- [ ] Confirm dialogs
- [ ] Form validation
- [ ] Mobile/tablet responsive polish
- [ ] Deploy to Vercel + monitor via Supabase dashboard

---

### 🚀 Phase 9 — Multi-Tenant Architecture (v8) ← NEXT BIG MOVE

#### 9.0 Database Migration
- [ ] Run `migration_v7_v8.sql` on Supabase:
  - Adds `super_admin` to `user_role` enum
  - Creates `schools` table
  - Adds `school_id` to ALL tables + backfills existing data to default school
  - Makes `school_id` NOT NULL on critical tables
  - Creates 25+ performance indexes
  - Adds `get_user_school_id()` helper function
  - Updates all RLS policies to scope by `school_id`
  - Updates `teacher_check_in()` + `perform_student_rollup()` to be school-aware
  - Adds `super_admin_create_school()` function

#### 9.1 Landing Page (`/`)
- [ ] Clean public page — no login required
- [ ] School name + logo + hero description
- [ ] Key features list (Khmer language, attendance, scores, parent portal)
- [ ] Schools currently using it (count or logos)
- [ ] Contact section (for schools interested in joining)
- [ ] Login button → `/login`

#### 9.2 Login Update
- [ ] Remove any school selector — just email + password
- [ ] After login: system reads `school_id` from `public.users`
- [ ] Saves to Pinia `school` store → all queries auto-scoped
- [ ] Route based on role as before

#### 9.3 Super Admin Dashboard (`/super`) — Tra only
- [ ] Route guard: only `super_admin` role can access `/super/*`
- [ ] `/super/dashboard`:
  - Total schools active/inactive
  - Total students across all schools
  - Total teachers across all schools
  - Recently added schools
- [ ] `/super/schools` — Schools list:
  - School name, code, province, district, status badge, student count
  - Activate / Deactivate toggle
  - View detail button
- [ ] `/super/schools/new` — Create school form:
  - School name (Khmer + English)
  - School code (e.g. `BTB-001`)
  - Province + District
  - First admin: full name, email, password
  - Submit → calls `super_admin_create_school()` DB function + Edge Function `manage-user` to create auth user
- [ ] `/super/schools/:id` — School detail:
  - School info
  - Usage stats (students, teachers, classes)
  - List of admin accounts for that school
  - Deactivate school button

#### 9.4 Update Edge Function `manage-user`
- [ ] Add `school_id` to create payload:
  ```json
  {
    "action": "create",
    "payload": {
      "email", "password", "role", "full_name",
      "school_id"
    }
  }
  ```
- [ ] When super_admin creates → can pass any `school_id`
- [ ] When admin creates → Edge Function enforces `school_id = caller's school_id`

#### 9.5 Update All Queries in Frontend
- [ ] Every Supabase query already scoped by RLS automatically ✅
- [ ] But double-check: remove any manual `school_id` filters that were hardcoded
- [ ] Parent portal: add school selector or school code param to search page
  ```
  /parent?school=BTB-001
  → pre-selects school
  → name + DOB search within that school only
  ```

#### 9.6 Update Pinia Stores
- [ ] `auth.js` — store `school_id` from `public.users` after login
- [ ] `school.js` — store `{ schoolId, schoolName, schoolCode }` persisted to localStorage
- [ ] All stores clear on logout

#### 9.7 Test Multi-Tenant
- [ ] Create 2 test schools via `/super/schools/new`
- [ ] Create admin/teacher accounts for each
- [ ] Verify school A cannot see school B data
- [ ] Verify parent portal scoped correctly by school
- [ ] Test super admin sees all schools

---Potential partnerships: MoEYS, UNICEF Cambodia, World Bank, Room to Read, Aide et Action.

---

## 📌 Notes

- Supabase anon key is safe to expose in frontend (RLS protects data)
- Parent portal uses Supabase anon role — no login required
- Score calculations happen on the frontend (`scoreCalculator.js`) — DB stores raw scores only
- Rank computed within class only — ties share rank, next rank skips (1,1,3...)
- **Student rollup parses grade from class name** — requires consistent `ថ្នាក់ទី{Khmer digit}{letter}` naming
- Rollup updates `class_id` + `academic_year_id` in-place — no data duplication
- Grade 6 graduates: `is_graduated = true`, `class_id = null`
- **Subjects are per-class** — fetched from `class_subjects`, not global `subjects`
- Grade 1-3 no English · Grade 4-6 includes English
- All file uploads → Supabase Storage, only URLs in DB
- **Every user has a teachers profile** — role only controls access, not identity
- **Multi-tenant (v8):** every query auto-scoped by `school_id` via RLS — no manual filtering needed in frontend
- **Super admin** (Tra only) — bypasses all school RLS, sees all data across all schools
- `get_user_school_id()` helper function used in all RLS policies for school scoping
- `super_admin_create_school()` auto-creates `school_settings` + `school_information` rows for new school
- `manage-user` Edge Function now requires `school_id` in payload for user creation
- **Parent portal** — pass `?school=BTB-001` URL param to scope search to correct school
- 25+ indexes added in v8 migration for multi-tenant performance at scale
- Cambodia school days = **Monday to Saturday** — Sundays off by default
- `manage-user` Edge Function always creates 3 rows: `auth.users` + `public.users` + `teachers`
