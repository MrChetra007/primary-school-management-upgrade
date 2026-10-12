# 🏫 Primary School Management System — Roadmap

> **Stack:** Vue 3 + Vite + Tailwind CSS + Supabase  
> **Roles:** Admin/Director · Teacher · Librarian · Parent (anon)

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
│   ├── scoreCalculator.js   # Monthly & semester score logic
│   ├── formatDate.js
│   └── exportPdf.js
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
| `/admin/teachers` | Teacher CRUD + profile picture upload |
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
| `/admin/reports` | Reports & print (attendance, scores, budget) |

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
| `/teacher/scores` | Score management — enter monthly & semester scores |
| `/teacher/scores/monthly` | Enter monthly exam scores per subject |
| `/teacher/scores/semester` | Enter semester exam scores + view calculated semester avg |
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
| `/parent/student/:id/attendance` | Monthly attendance — color-coded calendar view + summary (present/absent/late/permission counts + rate %) |
| `/parent/student/:id/scores` | Monthly & semester scores per subject |
| `/parent/student/:id/health` | Health profile + checkups |
| `/parent/student/:id/growth` | Growth chart (height/weight) |
| `/parent/student/:id/vaccinations` | Vaccination records |
| `/parent/student/:id/sick-days` | Sick day history |

---

## 📊 Score Calculation Logic

### Monthly Score
```
Enter: subject1, subject2, subject3... (for that month)
monthly_average = sum(all subjects) / count(subjects)
```

### Semester Score
```
Step 1 — Monthly part:
  monthly_average = (Month1_avg + Month2_avg + Month3_avg) / 3

Step 2 — Semester exam:
  Enter: subject1, subject2... (separate exam session)
  semester_exam_average = sum(all subjects) / count(subjects)

Step 3 — Final semester average:
  semester_average = (monthly_average + semester_exam_average) / 2
```

> Teacher manually selects score type: **Monthly** or **Semester** when entering scores.

---

## 🚀 Development Phases

---

### ✅ Phase 0 — Database
- [x] Write `schema.sql` (all tables + enums)
- [x] Write RLS policies per role
- [x] Setup Supabase storage bucket `teacher-profiles`
- [ ] Run schema on Supabase project
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
- [ ] Subject CRUD
- [ ] School holidays CRUD (scoped to selected academic year)
- [ ] Teacher CRUD + profile picture (Supabase bucket)
- [ ] Class CRUD (assign teacher, morning/afternoon turn)
- [ ] Student CRUD (all classes)
- [ ] Student detail page (health, growth, vaccinations)

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
- [ ] Filter bar at top of page:
  - **ថ្នាក់** (Class) — dropdown, select one class
  - **ប្រភេទ** (Type) — dropdown: Monthly / Semester
  - **ខែ / វគ្គ** (Month / Semester) — dropdown changes based on type selected
- [ ] Score table — **dynamic columns** based on subjects in DB:
  ```
  ល.រ | ឈ្មោះសិស្ស | [Subject1] | [Subject2] | ... | មធ្យមភ្វរ
  ```
  - Subject columns **fetched dynamically** from `subjects` table (not hardcoded)
  - Last column **មធ្យមភ្វរ** (Average) is auto-calculated on the frontend
  - Rows = all students in selected class
  - Scores fetched from `scores` table filtered by `class_id` + `score_type` + month
  - Empty cell shown as `—` if no score entered yet for that subject
- [ ] Table is **read-only** for admin (no editing inline)
- [ ] **Export / Print** button → print or PDF of that class score table

#### 3.5 Finance & Inventory
- [ ] Budget transactions CRUD (income/expense)
- [ ] Inventory items CRUD (with low stock alert)

#### 3.6 Library Overview
- [ ] Read-only view of books & borrows

#### 3.7 Reports
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
  - 🟢 present · 🔴 absent · 🟡 late · 🔵 permission · ⬜ Sunday / holiday (Cambodia school = Mon–Sat)
- [ ] Attendance rate % auto-calculated per student for the month
- [ ] **Printable monthly attendance grid** (all students × all days):
  ```
  ឈ្មោះសិស្ស | ១ | ២ | ៣ | ... | ៣១ | សរុបមក | អវត្តមាន | យឺត | ច្បាប់
  ```
  - School holidays and **Sundays** shown as shaded columns automatically (Cambodia school days = Monday–Saturday)
  - Print / export as PDF

**Teacher's Own Attendance:**
- [ ] **Monthly calendar view** — color-coded days for their own attendance record (read only)
- [ ] **Printable monthly attendance grid** for all teachers in school:
  ```
  ឈ្មោះគ្រូ | ១ | ២ | ៣ | ... | ៣១ | សរុបមក | អវត្តមាន | យឺត
  ```

#### 4.3 Score Management
- [ ] Select score type (Monthly or Semester)
- [ ] Monthly: enter subject scores per student → auto calculate monthly_average
- [ ] Semester: enter semester exam scores → system shows semester_average
- [ ] View score history per student

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
- Score calculations happen in `src/utils/scoreCalculator.js` on the frontend
- All file uploads go to Supabase Storage, only URLs saved in DB
- Always filter teacher queries by their assigned class (enforced by RLS)
