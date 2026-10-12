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
| Route | Page |
|---|---|
| `/admin/dashboard` | Overview stats (students, teachers, budget, alerts) |
| `/admin/school` | School information (edit name, logo, director) |
| `/admin/academic-years` | Academic year CRUD |
| `/admin/subjects` | Subject CRUD |
| `/admin/classes` | Class CRUD (assign teacher, set turn) |
| `/admin/teachers` | Teacher CRUD + profile picture upload |
| `/admin/students` | All students CRUD (all classes) |
| `/admin/students/:id` | Student detail + health + growth + vaccinations |
| `/admin/attendance/students` | Student attendance (view all classes, filter by class/date) |
| `/admin/attendance/teachers` | Teacher attendance (view & manage all) |
| `/admin/scores` | Scores (view all classes, filter by class/subject/type) |
| `/admin/health` | Student health records overview |
| `/admin/sick-days` | Sick days overview |
| `/admin/holidays` | School holidays CRUD |
| `/admin/budget` | Budget transactions (income/expense CRUD) |
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
- [x] Run schema on Supabase project
- [x] Seed test data (1 academic year, 2 classes, 5 students, 3 teachers)

---

### ✅ Phase 1 — Project Setup
- [x] Init Vite + Vue 3 project
- [x] Install & configure Tailwind CSS
- [x] Install dependencies:
  - `@supabase/supabase-js`
  - `pinia` (state management)
  - `vue-router`
  - `vee-validate` + `yup` (form validation)
  - `@vueuse/core` (utilities)
  - `chart.js` + `vue-chartjs` (for growth charts)
  - `jspdf` + `html2canvas` (for print/export)
- [x] Setup Supabase client (`src/lib/supabase.js`)
- [x] Setup `.env` file (Supabase URL + anon key)
- [x] Setup folder structure as above

---

### ✅ Phase 2 — Auth & Role Routing
- [x] Login page (email + password via Supabase Auth)
- [x] Pinia auth store (session, user, role)
- [x] Route guards (redirect based on role)
- [x] Layouts per role (AdminLayout, TeacherLayout, LibrarianLayout)
- [x] Unauthorized page
- [x] Auto redirect after login based on role
- [x] Logout functionality

---

### ✅ Phase 3 — Admin Features

#### 3.1 Core Setup
- [x] School information page (edit + logo upload)
- [x] Academic year CRUD
- [x] Subject CRUD
- [x] School holidays CRUD

#### 3.2 People Management
- [x] Teacher CRUD + profile picture (Supabase bucket)
- [x] Class CRUD (assign teacher, morning/afternoon turn)
- [x] Student CRUD (all classes)
- [x] Student detail page (health, growth, vaccinations)

#### 3.3 Attendance
- [x] Student attendance — view all, filter by class/date
- [x] Teacher attendance — view & manage all

#### 3.4 Scores
- [x] View all scores (filter by class, subject, type)
- [x] Monthly score view & summary
- [x] Semester score view with calculated averages

#### 3.5 Finance & Inventory
- [x] Budget transactions CRUD (income/expense)
- [x] Inventory items CRUD (with low stock alert)

#### 3.6 Library Overview
- [x] Read-only view of books & borrows

#### 3.7 Reports
- [x] Print student attendance report (by class/month)
- [x] Print score report (by class/semester)
- [x] Print budget report

---

### ✅ Phase 4 — Teacher Features

#### 4.1 Class & Students
- [x] Dashboard (class stats, today's attendance summary)
- [x] Class student list (add, edit students in own class)
- [x] Student detail (health, growth, vaccinations, sick days)

#### 4.2 Attendance
- [x] Daily attendance marking (present/absent/late/permission)
- [x] Monthly attendance view (calendar or table)
- [x] Own attendance view (read only)

#### 4.3 Score Management
- [x] Select score type (Monthly or Semester)
- [x] Monthly: enter subject scores per student → auto calculate monthly_average
- [x] Semester: enter semester exam scores → system shows semester_average
- [x] View score history per student

#### 4.4 Health & Wellness
- [x] Add & manage student sick days
- [x] Add & view student growth records
- [x] View student vaccinations

#### 4.5 Reports
- [x] Print class attendance sheet
- [x] Print class score report

---

### ✅ Phase 5 — Librarian Features
- [x] Dashboard (total books, borrowed, overdue count)
- [x] Book CRUD (title, author, ISBN, category, copies)
- [x] Issue book (search student, set due date)
- [x] Return book (update status, available_copies)
- [x] Overdue list with days overdue

---

### ✅ Phase 6 — Parent Portal
- [x] Search page (student name + DOB form)
- [x] Student found → show overview dashboard
- [x] Attendance tab (monthly calendar view)
- [x] Scores tab (monthly & semester per subject)
- [x] Health tab (health profile + checkups)
- [x] Growth tab (height/weight chart over time)
- [x] Vaccinations tab
- [x] Sick days tab
- [x] Mobile responsive (parents likely on phone)
- [x] Khmer language support on parent portal

---

### 🎨 Phase 7 — Polish & Deployment
- [x] Loading states & skeleton loaders
- [x] Empty states (no data illustrations)
- [x] Toast notifications (success/error)
- [x] Confirm dialogs (delete actions)
- [x] Form validation on all forms
- [x] Responsive design (mobile/tablet)
- [x] Khmer font support (Hanuman or Noto Sans Khmer)
- [ ] Dark/light mode (optional)
- [x] Final testing per role
- [ ] Deploy to Vercel / Netlify
- [ ] Connect custom domain (if any)

---

## 📌 Notes
- Supabase anon key is safe to expose in frontend (RLS protects data)
- Parent portal uses Supabase anon role — no login required
- Score calculations happen in `src/utils/scoreCalculator.js` on the frontend
- All file uploads go to Supabase Storage, only URLs saved in DB
- Always filter teacher queries by their assigned class (enforced by RLS)
