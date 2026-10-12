# 🏫 Primary School Management System — Roadmap v11

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
│   ├── auth.js              # Pinia: auth state + role
│   ├── academicYear.js      # Pinia: { academicYearId, yearName } — persisted to localStorage
│   ├── student.js
│   ├── score.js
│   ├── classSubjects.js     # Pinia: subjects per class (fetched from class_subjects table)
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
| `/login` | Login page (all roles) |
| `/unauthorized` | No access page |
| `/admin/academic-years` | **Admin only.** Academic year selector — Layer 1 entry point |

> These pages render on their own with a clean blank background. No `AdminLayout` wrapping them.

---

### 👨‍💼 Admin Pages `/admin`

> **Two-layer system:**
> - **Layer 1** → `/admin/academic-years` — Standalone page, no layout. Admin selects which academic year to work in.
> - **Layer 2** → All other `/admin/*` pages — Use `AdminLayout` (sidebar + topbar). All data is scoped to the selected academic year from the Pinia store.

#### 🔑 Layer 1 — Academic Year Page (Standalone, no layout)
| Route | Page | Notes |
|---|---|---|
| `/admin/academic-years` | Academic year selector | Has **Logout** button top-right. CRUD academic years. Click **"មើល"** → saves `academic_year_id` to Pinia store → navigates to `/admin/dashboard` |

#### 📊 Layer 2 — Inside AdminLayout (sidebar + topbar)
> Topbar shows: **selected year badge** + **"← ប្តូរឆ្នាំ"** back button that returns to `/admin/academic-years`

| Route | Page |
|---|---|
| `/admin/dashboard` | Overview stats scoped to selected academic year (students, teachers, budget, alerts) |
| `/admin/school` | School information (edit name, logo, director) |
| `/admin/subjects` | Subject CRUD |
| `/admin/classes` | Class CRUD (assign teacher, set turn) — scoped to selected year |
| `/admin/teachers` | Teacher profile management — view, edit profiles, assign classes |
| `/admin/students` | All students CRUD (all classes) — scoped to selected year |
| `/admin/students/:id` | Student detail + health + growth + vaccinations |
| `/admin/attendance/students` | Student attendance (view all classes, filter by class/date) |
| `/admin/attendance/teachers` | Teacher attendance (view & manage all) |
| `/admin/scores` | Scores — filter by class + score type + month → renders dynamic subject columns table with auto-calculated average per student |
| `/admin/health` | Student health records overview |
| `/admin/sick-days` | Sick days overview |
| `/admin/holidays` | School holidays CRUD — scoped to selected year |
| `/admin/budget` | Budget transactions (income/expense CRUD) — scoped to selected year |
| `/admin/inventory` | Inventory items CRUD |
| `/admin/library` | Library overview (books + borrows, read-only) |
| `/admin/users` | User management — create, edit, deactivate/reactivate all staff accounts |

---

### 👩‍🏫 Teacher Pages `/teacher`
| Route | Page |
|---|---|
| `/teacher/dashboard` | Class overview (total students, today's attendance, alerts) |
| `/teacher/students` | Their class students list (view, add, edit) |
| `/teacher/students/:id` | Student detail (health, growth, vaccinations, sick days) |
| `/teacher/attendance` | Mark daily student attendance — bulk mark all present + change exceptions |
| `/teacher/attendance/monthly` | Monthly student attendance — calendar view per student + printable grid |
| `/teacher/attendance/my` | Own attendance — monthly calendar view (read only) + printable all-teachers grid |
| `/teacher/scores` | Score management — select Monthly or Semester mode |
| `/teacher/scores/monthly` | Monthly score entry — list view with dynamic subject columns, average, rank. Enter → save → edit → print PDF |
| `/teacher/scores/semester` | Semester score entry — list view with semester exam subjects + pulled monthly averages + auto-calculated semester average. Enter → save → edit → print PDF |
| `/teacher/sick-days` | Add & manage student sick days |
| `/teacher/growth` | Add & view student growth (height/weight) |
| `/teacher/vaccinations` | View student vaccinations |
| `/teacher/holidays` | View school holidays (read only) |
| `/teacher/reports` | Print class attendance & score reports |

---

### 📚 Librarian Pages `/librarian`
| Route | Page |
|---|---|
| `/librarian/dashboard` | Books overview (total, borrowed, overdue alerts) |
| `/librarian/books` | Book CRUD (add, edit, delete) |
| `/librarian/borrows` | Issue & return books (search student) |
| `/librarian/overdue` | Overdue tracking list |

---

### 👨‍👩‍👧 Parent Portal `/parent`
| Route | Page |
|---|---|
| `/parent` | Search form (student name + DOB) |
| `/parent/student/:id` | Student overview dashboard |
| `/parent/student/:id/attendance` | Monthly attendance — color-coded calendar view + summary |
| `/parent/student/:id/scores` | Monthly & semester scores per subject |
| `/parent/student/:id/health` | Health profile + checkups |
| `/parent/student/:id/growth` | Growth chart (height/weight) |
| `/parent/student/:id/vaccinations` | Vaccination records |
| `/parent/student/:id/sick-days` | Sick day history |

---

## 📊 Score Calculation Logic

### Monthly Score
```
Teacher enters: subject1, subject2, subject3... (per student, for that month)

monthly_average = sum(all subject scores) / count(subjects)
rank            = order by monthly_average DESC within class (1st, 2nd, 3rd...)
```

### Semester Score
```
Step 1 — Semester exam (teacher enters):
  subject1, subject2, subject3...
  semester_exam_average = sum(semester exam subjects) / count(subjects)

Step 2 — Monthly averages (auto-pulled from DB, read-only):
  Month1_avg = existing monthly score average for month 1
  Month2_avg = existing monthly score average for month 2
  Month3_avg = existing monthly score average for month 3
  monthly_average = (Month1_avg + Month2_avg + Month3_avg) / 3

Step 3 — Final semester average (auto-calculated):
  semester_average = (monthly_average + semester_exam_average) / 2

Step 4 — Rank:
  rank = order by semester_average DESC within class
```

### Rank Rules
- Ranked **within class only** (not across all classes)
- Ties get the **same rank** (e.g. two students at 90.0 both get rank 1, next student gets rank 3)
- Calculated on the **frontend** in `scoreCalculator.js` — not stored in DB

### All calculations happen on the frontend (`src/utils/scoreCalculator.js`)
- DB only stores raw subject scores
- Averages, monthly averages, semester averages, ranks — all computed in JS
- PDF generation uses the computed values

> Teacher manually selects: **class + month + type (Monthly/Semester)** when entering scores.

---

## 🚀 Development Phases

---

### ✅ Phase 0 — Database
- [x] Write `schema.sql` (all tables + enums)
- [x] Write RLS policies per role
- [x] Setup Supabase storage bucket `teacher-profiles`
- [x] Add `user_status` enum + `users.status` column (migration v2→v3)
- [x] Refactor `teachers.user_id` to `NOT NULL UNIQUE` — every user always has a teacher profile (schema v4)
- [x] Update `manage-user` Edge Function spec to always create teachers row for all roles
- [ ] Run schema v4 on Supabase project
- [ ] Seed test data (1 academic year, 2 classes, 5 students, 3 teachers)

---

### 🔧 Phase 1 — Project Setup
- [ ] Init Vite + Vue 3 project
- [ ] Install & configure Tailwind CSS
- [ ] Install dependencies:
  - `@supabase/supabase-js`
  - `pinia` (state management)
  - `vue-router`
  - `vee-validate` + `yup` (form validation)
  - `@vueuse/core` (utilities)
  - `chart.js` + `vue-chartjs` (for growth charts)
  - `jspdf` + `html2canvas` (for print/export)
- [ ] Setup Supabase client (`src/lib/supabase.js`)
- [ ] Setup Supabase Edge Function `manage-user` (create/reset/delete — always creates teachers row)
- [ ] Setup `.env` file (Supabase URL + anon key)
- [ ] Setup folder structure as above

---

### 🔐 Phase 2 — Auth & Role Routing
- [ ] Login page (email + password via Supabase Auth)
- [ ] Pinia `auth` store (session, user, role)
- [ ] Pinia `academicYear` store (`academicYearId`, `yearName`) — persisted to `localStorage`
- [ ] Vue Router structure:
  ```
  /login                    → no layout (standalone)
  /unauthorized             → no layout (standalone)
  /admin/academic-years     → no layout (standalone) ← Layer 1
  /admin/*                  → AdminLayout            ← Layer 2
  /teacher/*                → TeacherLayout
  /librarian/*              → LibrarianLayout
  /parent/*                 → ParentLayout
  ```
- [ ] Route guards:
  - Not logged in → `/login`
  - Admin logged in → `/admin/academic-years` (Layer 1 always first)
  - Teacher logged in → `/teacher/dashboard`
  - Librarian logged in → `/librarian/dashboard`
- [ ] Academic year guard — admin tries to access any `/admin/*` (except academic-years) without `academicYearId` in store → redirect to `/admin/academic-years`
- [ ] `AdminLayout` topbar:
  - Show selected year name as badge
  - Show **"← ប្តូរឆ្នាំ"** button → clears `academicYear` store → goes to `/admin/academic-years`
  - Show **Logout** button
- [ ] `AcademicYearView` (standalone):
  - Show **Logout** button top-right only (no sidebar, no topbar)
- [ ] Logout → clears both `auth` store and `academicYear` store → redirect to `/login`
- [ ] Inactive user check — if user logs in but `status = inactive` → show error "គណនីត្រូវបានផ្អាក" and sign out immediately

---

### 🏫 Phase 3 — Admin Features

#### 3.0 Academic Year Page — Layer 1 (Standalone, no layout)
- [ ] Clean full-page design — no sidebar, no topbar
- [ ] School logo + name at top center
- [ ] **Logout** button top-right corner
- [ ] List all academic years as cards (name, start/end date, status badge)
- [ ] Create new academic year (modal form)
- [ ] Edit academic year (modal form)
- [ ] Set status: **active** / **ended** toggle
- [ ] **"មើល" button** on each card → saves `{ academicYearId, yearName }` to Pinia store → navigates to `/admin/dashboard`
- [ ] If `academicYear` store already has a value (returning from dashboard) → show currently active year highlighted

#### 3.1 Core Setup
- [ ] School information page (edit + logo upload)
- [ ] Subject CRUD (global subject pool — add/edit/delete subjects)
- [ ] School holidays CRUD (scoped to selected academic year)
- [ ] Class CRUD:
  - Create / edit class (name, assign teacher, morning/afternoon turn)
  - **Assign subjects to class** — multi-select from global subjects pool → saves to `class_subjects`
  - Example: Grade 1A → select [ខ្មែរ, គណិត, វិទ្យា, សង្គម, សិល្បៈ, កាយ] (no English)
  - Example: Grade 4A → select [ខ្មែរ, គណិត, វិទ្យា, សង្គម, សិល្បៈ, កាយ, អង់គ្លេស]
  - Subjects shown as checkboxes or tag selector
- [ ] Student CRUD (all classes)
- [ ] Student detail page (health, growth, vaccinations)

#### 3.2 Teacher Profile Management (`/admin/teachers`)
- [ ] List all teachers (all roles — admin, teacher, librarian all appear here)
- [ ] Shows: profile picture, name, role badge, gender, phone, degree
- [ ] **Edit profile** modal — update any teacher's personal info + profile picture
- [ ] Profile picture upload to Supabase `teacher-profiles` bucket
- [ ] View which class each teacher is assigned to (from `classes` table)
- [ ] **Note:** Teacher accounts are created from `/admin/users`, not here. This page is for profile data only.

#### 3.3 Attendance (Admin — View Only)

**Student Attendance:**
- [ ] Filter by class + month
- [ ] View monthly attendance grid (all students × all days) — color coded
- [ ] Printable monthly attendance grid:
  ```
  ឈ្មោះសិស្ស | ១ | ២ | ៣ | ... | ៣១ | សរុបមក | អវត្តមាន | យឺត | ច្បាប់
  ```
- [ ] Attendance rate % per student (present days / total school days)

**Teacher Attendance:**
- [ ] View all teachers attendance filtered by month
- [ ] Calendar view per teacher — color-coded days (🟢 present 🔴 absent 🟡 late 🔵 permission)
- [ ] Printable monthly attendance grid for all teachers

#### 3.4 Scores (Admin — View Only)
- [ ] Filter bar: Class → Type (Monthly/Semester) → Month/Semester
- [ ] Dynamic subject columns fetched from `class_subjects` table (per selected class — not global)
- [ ] Auto-calculated average column per student
- [ ] Rank column — ranked within class by average
- [ ] Empty scores shown as `—`
- [ ] Read-only for admin
- [ ] Export / Print to PDF

#### 3.5 Finance & Inventory
- [ ] Budget transactions CRUD (income/expense)
- [ ] Inventory items CRUD (with low stock alert)

#### 3.6 Library Overview
- [ ] Read-only view of books & borrows

#### 3.7 User Management (`/admin/users`)

> **Key principle:** Every user created here — regardless of role — always gets a full teacher profile. Because in Cambodian schools, everyone is a teacher.

- [ ] Page with **3 tabs**: Admin | Teacher | Librarian
- [ ] Each tab shows a table of users with: profile picture, name, email, role badge, status badge (🟢 active / 🔴 inactive), actions
- [ ] **Create user** modal — single form for all roles:
  - **Step 1 — Pick role:** Admin / Teacher / Librarian (role selector at top)
  - **Step 2 — Full form (same for ALL roles):**
    - Personal: Full name, Gender, Date of birth, Phone number, Degree, Address
    - Account: Email, Password
    - Profile picture upload (optional)
  - Submit → calls Edge Function `manage-user` with `action: "create"`:
    1. Creates `auth.users` entry
    2. Inserts `public.users` row (role, status=active)
    3. Inserts `teachers` row (full profile, `user_id` linked)
- [ ] **Edit profile** → opens same form pre-filled (updates `teachers` row)
- [ ] **Edit role** → dropdown to change role (admin/teacher/librarian) → calls `admin_update_user_role()` DB function — does NOT affect teachers profile
- [ ] **Reset password** → admin enters new password → calls Edge Function `manage-user` with `action: "reset_password"`
- [ ] **Deactivate** → calls `admin_update_user_status()`:
  - Sets `status = inactive` in `public.users`
  - Sets `banned_until = '2099-12-31'` in `auth.users` → blocks login immediately
- [ ] **Reactivate** → removes ban → sets `status = active`, clears `banned_until`
- [ ] **Delete** → calls Edge Function `manage-user` with `action: "delete"` → cascades to `public.users` + `teachers`

#### 3.8 Reports
- [ ] Print student attendance report (by class/month)
- [ ] Print score report (by class/semester)
- [ ] Print budget report

---

### 👩‍🏫 Phase 4 — Teacher Features

#### 4.1 Class & Students
- [ ] Dashboard (class stats, today's attendance summary)
- [ ] Class student list (add, edit students in own class)
- [ ] Student detail (health, growth, vaccinations, sick days)

#### 4.2 Attendance

**Student Attendance:**
- [ ] **Bulk mark** — "គូសទាំងអស់ថាមានវត្តមាន" (Mark all present) button → then teacher only changes the exceptions
- [ ] Daily attendance marking per student (present / absent / late / permission)
- [ ] **Monthly calendar view per student** — color-coded calendar:
  - 🟢 present · 🔴 absent · 🟡 late · 🔵 permission · ⬜ Sunday / holiday
- [ ] Attendance rate % auto-calculated per student for the month
- [ ] **Printable monthly attendance grid** (all students × all days)

**Teacher's Own Attendance:**
- [ ] **Monthly calendar view** — color-coded days for their own attendance (read only)
- [ ] **Printable monthly attendance grid** for all teachers in school

#### 4.3 Score Management

**Score Entry Page — Select Mode first:**
- [ ] Teacher selects: **ថ្នាក់** (class) + **ខែ** (month) + **ប្រភេទ** (Monthly or Semester)
- [ ] → navigates to the correct score entry view below

---

**📝 Monthly Score View (`/teacher/scores/monthly`)**

Table columns (dynamic):
```
ល.រ | ឈ្មោះសិស្ស | [Subject1] | [Subject2] | ... | មធ្យម | លំដាប់
```
- Subject columns fetched dynamically from `class_subjects` for the selected class (not global subjects)
- Grade 1-3 → no English column · Grade 4-6 → English included
- **មធ្យម** (Average) = sum of all subjects / count — auto-calculated on frontend
- **លំដាប់** (Rank) = ranked within the class by average (1st, 2nd, 3rd...) — auto-calculated
- Each subject cell is an **editable input** (number, 0–100)
- Empty = blank input (not `—`) so teacher can click and type
- [ ] **រក្សាទុក (Save)** button — upserts all scores for that class + month in one call
- [ ] After save: show success toast, inputs remain editable (teacher can continue editing)
- [ ] Teacher can come back anytime — existing scores pre-filled in inputs
- [ ] **បោះពុម្ព PDF (Print PDF)** button — generates clean printable PDF:
  ```
  Header: School name + Class + Month + Academic Year
  Table:  ល.រ | ឈ្មោះ | Subject1 | Subject2 | ... | មធ្យម | លំដាប់
  Footer: Teacher signature line
  ```

---

**📋 Semester Score View (`/teacher/scores/semester`)**

Table columns (dynamic):
```
ល.រ | ឈ្មោះ | [Subj1] | [Subj2] | ... | សមសេត_ប្រឡង | មធ្យម១ | មធ្យម២ | មធ្យម៣ | មធ្យមខែ | មធ្យមសមសេត | លំដាប់
```

Column breakdown:
- **[Subject columns]** → editable inputs for semester exam scores (entered by teacher)
- **សមសេត_ប្រឡង** (Semester Exam Average) = avg of semester exam subjects — auto-calculated
- **មធ្យម១ / មធ្យម២ / មធ្យម៣** = pulled automatically from existing monthly scores in DB (read-only, shown in gray)
- **មធ្យមខែ** (Monthly Average) = (M1 + M2 + M3) / 3 — auto-calculated
- **មធ្យមសមសេត** (Semester Average) = (monthly_average + semester_exam_average) / 2 — auto-calculated
- **លំដាប់** (Rank) = ranked by semester_average within class — auto-calculated
- [ ] If monthly scores for M1/M2/M3 don't exist yet → show `—` with warning "គ្មានពិន្ទុខែ" (no monthly score)
- [ ] **រក្សាទុក (Save)** → upserts semester exam scores only (monthly averages are read-only)
- [ ] Teacher can come back anytime — existing scores pre-filled
- [ ] **បោះពុម្ព PDF (Print PDF)** button — generates clean printable PDF:
  ```
  Header: School name + Class + Semester + Academic Year
  Table:  ល.រ | ឈ្មោះ | Subjects... | សមសេត_ប្រឡង | មធ្យម១|២|៣ | មធ្យមខែ | មធ្យមសមសេត | លំដាប់
  Footer: Teacher signature line
  ```

#### 4.4 Health & Wellness
- [ ] Add & manage student sick days
- [ ] Add & view student growth records
- [ ] View student vaccinations

#### 4.5 Reports
- [ ] Print class attendance sheet
- [ ] Print class score report

---

### 📚 Phase 5 — Librarian Features
- [ ] Dashboard (total books, borrowed, overdue count)
- [ ] Book CRUD (title, author, ISBN, category, copies)
- [ ] Issue book (search student, set due date)
- [ ] Return book (update status, available_copies)
- [ ] Overdue list with days overdue

---

### 👨‍👩‍👧 Phase 6 — Parent Portal
- [ ] Search page (student name + DOB form)
- [ ] Student found → show overview dashboard
- [ ] Attendance tab (monthly calendar view)
- [ ] Scores tab (monthly & semester per subject)
- [ ] Health tab (health profile + checkups)
- [ ] Growth tab (height/weight chart over time)
- [ ] Vaccinations tab
- [ ] Sick days tab
- [ ] Mobile responsive (parents likely on phone)
- [ ] Khmer language support on parent portal

---

### 🎨 Phase 7 — Polish & Deployment
- [ ] Loading states & skeleton loaders
- [ ] Empty states (no data illustrations)
- [ ] Toast notifications (success/error)
- [ ] Confirm dialogs (delete actions)
- [ ] Form validation on all forms
- [ ] Responsive design (mobile/tablet)
- [ ] Khmer font support (Hanuman or Noto Sans Khmer)
- [ ] Dark/light mode (optional)
- [ ] Final testing per role
- [ ] Deploy to Vercel / Netlify
- [ ] Connect custom domain (if any)

---

## 📌 Notes
- Supabase anon key is safe to expose in frontend (RLS protects data)
- Parent portal uses Supabase anon role — no login required
- Score calculations happen in `src/utils/scoreCalculator.js` on the frontend — DB stores raw scores only
- Rank is computed within class only — ties share same rank, next rank skips (1,1,3...)
- Monthly averages for semester view are pulled from existing DB records (read-only in semester view)
- PDF generation uses `jspdf` + `html2canvas` — includes school name, class, month/semester, teacher signature line
- **Subjects are per-class** — fetched from `class_subjects` junction table, not global `subjects` table
- Grade 1-3 classes have no English subject · Grade 4-6 classes include English
- Admin assigns subjects to each class when creating/editing a class
- All file uploads go to Supabase Storage, only URLs saved in DB
- Always filter teacher queries by their assigned class (enforced by RLS)
- **Every user has a teachers profile** — role only controls app access, not identity
- `manage-user` Edge Function always creates 3 rows: `auth.users` + `public.users` + `teachers`
- Changing a user's role does NOT affect their `teachers` profile data
