# 🏫 Primary School Management System

A comprehensive school management platform for Cambodian primary schools, built for multi-tenant use across multiple schools.

**Stack:** Vue 3 + Vite + Tailwind CSS + Supabase (PostgreSQL)

## Roles

| Role | Access |
|------|--------|
| **Super Admin** | Platform level — manage all schools |
| **Admin** | School director — manage one school |
| **Teacher** | Manage assigned class (scores, attendance, health) |
| **Librarian** | Library CRUD (books, borrows, returns) |
| **Parent** | Anonymous — link-only report card access (no login) |

## Key Features

- **Multi-tenant:** `school_id` on every table, RLS auto-scopes queries
- **Academic years:** Two-layer admin (year selector → dashboard)
- **Scores:** Monthly & semester entry, dynamic subjects, averages, ranking, PDF export
- **Attendance:** Daily bulk marking, monthly calendar, teacher check-in
- **Student rollup:** End-of-year grade promotion (Grade 6 → graduated)
- **Parent portal:** UUID-based report links with voice messaging
- **Honor board / certificates:** Drag-drop editor with template gallery
- **Student score radar chart:** Visual score summary per student
- **Excel import:** Bulk student import with class detection
- **Khmer language UI** throughout

## Routes

| Group | Routes |
|-------|--------|
| Public | `/`, `/login`, `/register`, `/unauthorized` |
| Super Admin | `/super/dashboard`, `/super/schools`, `/super/schools/new` |
| Admin | `/admin/academic-years`, `/admin/dashboard`, `/admin/classes`, `/admin/students`, `/admin/scores`, `/admin/attendance/*`, `/admin/budget`, `/admin/inventory`, `/admin/library`, `/admin/users`, `/admin/reports`, `/admin/honor-board-editor`, etc. |
| Teacher | `/teacher/dashboard`, `/teacher/scores/monthly`, `/teacher/scores/semester`, `/teacher/scores/ranking`, `/teacher/scores/summary/:id`, `/teacher/scores/report-replies`, `/teacher/scores/certificates`, `/teacher/honor-board-editor`, `/teacher/attendance`, `/teacher/growth`, etc. |
| Librarian | `/librarian/dashboard`, `/librarian/books`, `/librarian/borrows`, `/librarian/overdue` |
| Parent | `/parent/report/:report_link_id`, `/parent/report/:report_link_id/:student_id` |

## Database

Full schema in `schema_v9.sql` (fresh install) — covers 24 tables, 25+ indexes, RLS policies, storage buckets, and DB functions (student rollup, teacher check-in, Khmer digit parsing).

Migration files: `migration_v2_to_v3.sql` through `migration_v8_v9.sql`.

## Develop

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Key Dependencies

- `vue 3`, `vue-router 5`, `pinia 3` — core
- `@supabase/supabase-js` — backend
- `chart.js` + `vue-chartjs` — radar charts
- `jspdf` + `jspdf-autotable` — PDF reports
- `html2canvas` — certificate capture
- `xlsx` — Excel import/export
- `@heroicons/vue` + `lucide-vue-next` — icons
- `vee-validate` + `yup` — form validation
- `tailwindcss 4` — styling
