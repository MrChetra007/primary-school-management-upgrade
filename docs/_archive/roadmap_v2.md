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
│   ├── AdminLayout.vue
│   ├── TeacherLayout.vue
│   ├── LibrarianLayout.vue
│   └── ParentLayout.vue
├── lib/
│   └── supabase.js          # Supabase client init
├── router/
│   └── index.js             # Vue Router + route guards
├── stores/
│   ├── auth.js              # Pinia: auth state + role
│   ├── student.js
│   ├── score.js
│   └── attendance.js
├── views/
│   ├── auth/
│   ├── admin/
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

### 🔐 Auth Pages
| Route | Page |
|---|---|
| `/login` | Login (all roles) |
| `/unauthorized` | No access page |

---

### 👨‍💼 Admin Pages `/admin`

> ⚡ **Login Flow:** After login, admin is redirected to `/admin/academic-years` first.
> They must click **"មើល" (View)** on an academic year to enter the system.
> The selected `academic_year_id` is saved to **Pinia store** and used automatically across all pages — no manual selection needed anywhere.

#### 🔑 Entry Point (before dashboard)
| Route | Page |
|---|---|
| `/admin/academic-years` | **First page after login.** Academic year CRUD — create, edit, set active/ended. Click "មើល" to enter that year's context → saves to store → redirects to dashboard |

#### 📊 Main (inside selected academic year context)
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
| `/admin/scores` | Scores (view all classes, filter by class/subject/type) |
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
| `/teacher/attendance` | Mark & view student daily attendance |
| `/teacher/attendance/my` | View own attendance (read only) |
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
| `/parent/student/:id/attendance` | Monthly attendance view |
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
- [ ] Pinia auth store (session, user, role)
- [ ] Pinia academic year store (`academicYearId`, `academicYearName`) — persisted to `localStorage`
- [ ] Route guards (redirect based on role):
  - Admin → `/admin/academic-years` (must select a year first)
  - Teacher → `/teacher/dashboard`
  - Librarian → `/librarian/dashboard`
- [ ] Academic year guard — if admin navigates to any `/admin/*` page without a year selected in store → redirect back to `/admin/academic-years`
- [ ] Layouts per role (AdminLayout, TeacherLayout, LibrarianLayout)
- [ ] Unauthorized page
- [ ] Logout functionality (clear store + session)

---

### 🏫 Phase 3 — Admin Features

#### 3.0 Academic Year Page (Entry Point)
- [ ] List all academic years (name, start/end date, status badge)
- [ ] Create new academic year
- [ ] Edit academic year (name, dates)
- [ ] Set status: active / ended
- [ ] **"មើល" (View) button** → saves `academic_year_id` + `year_name` to Pinia store → redirects to `/admin/dashboard`
- [ ] Show currently selected year as a badge in the top bar on all admin pages
- [ ] "ប្តូរឆ្នាំ" (Switch Year) button in top bar → goes back to academic year page to reselect

#### 3.1 Core Setup
- [ ] School information page (edit + logo upload)
- [ ] Subject CRUD
- [ ] School holidays CRUD (scoped to selected academic year)
- [ ] Teacher CRUD + profile picture (Supabase bucket)
- [ ] Class CRUD (assign teacher, morning/afternoon turn)
- [ ] Student CRUD (all classes)
- [ ] Student detail page (health, growth, vaccinations)

#### 3.3 Attendance
- [ ] Student attendance — view all, filter by class/date
- [ ] Teacher attendance — view & manage all

#### 3.4 Scores
- [ ] View all scores (filter by class, subject, type)
- [ ] Monthly score view & summary
- [ ] Semester score view with calculated averages

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
- [ ] Daily attendance marking (present/absent/late/permission)
- [ ] Monthly attendance view (calendar or table)
- [ ] Own attendance view (read only)

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
