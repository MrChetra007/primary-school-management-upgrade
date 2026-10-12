# School Management System — Design Reference

## Overview

- **Framework**: Vue 3 (Composition API, `<script setup>`) + Vite
- **CSS**: Tailwind CSS 4 + design-token CSS variables (`style.css`)
- **Backend**: Supabase (Postgres, Auth, Realtime)
- **Icons**: Heroicons v24/outline (`@heroicons/vue/24/outline`) + Lucide-vue-next (super admin only)
- **Language**: Khmer (Cambodian) — primary UI language for authenticated pages
- **Fonts**: Inter (Latin) + Hanuman (Khmer) from Google Fonts
- **Role-based routing**: 5 roles (super_admin, admin, teacher, librarian) + public parent portal
- **Shared patterns**: page-header, page-title, page-subtitle, card, table-wrapper, empty-state, btn, form-*, badge-*, modal-*, toast-container, skeleton, filters-bar, tabs

---

## Layouts

### 1. App.vue
Root component — just renders `<RouterView />`. No shell/header at top level.

### 2. SuperLayout (`/super/*`)
- Dark sidebar (slate-900) with indigo-600 accent
- Collapsible sidebar (hamburger toggle on mobile, expands by default on desktop)
- Topbar with breadcrumb + "Platform Online" status indicator
- Lucide-vue-next icons (LayoutDashboard, School, Users, Settings, ShieldCheck, LogOut)
- Page content: max-w-7xl mx-auto with fade + translateY page transitions
- Desktop: sidebar always visible; collapsed state shows icons only
- Mobile: slide-out sidebar with backdrop blur overlay

### 3. AdminLayout (`/admin/*`)
- White sidebar (var(--bg-sidebar): white) with primary-500 brand icon
- Sidebar groups with section labels (grouped as: Overview, People, Attendance, Academics, Finance & Resources, Reports, School Setup)
- Topbar with: back-to-academic-years button, page title (from route meta), school badge, year badge
- Topbar right: NotificationsDropdown, role tag ("អ្នកគ្រប់គ្រង"), user avatar
- Inline SVG icon paths (no icon library import)
- Sidebar nav items with `.nav-item`, `.active` styling (primary-50 bg)
- Mobile: overlay sidebar with backdrop blur

### 4. TeacherLayout (`/teacher/*`)
- White sidebar same pattern as AdminLayout but simpler (no grouped sections)
- Topbar: page title, NotificationsDropdown, badge "គ្រូបង្រៀន", user avatar
- Inline SVG icon paths
- Same sidebar/nav-item CSS classes as AdminLayout

### 5. LibrarianLayout (`/librarian/*`)
- White sidebar, same pattern, 4 nav items (Dashboard, Books, Borrows, Overdue)
- Topbar: title "ការគ្រប់គ្រងបណ្ណាល័យ", badge "បណ្ណារក្ស", user avatar
- Same sidebar/nav-item structure

### 6. ParentLayout (`/parent/*`)
- No sidebar — clean content-only layout
- Header with brand logo (gradient primary), brand name, brand sub
- Optional nav tabs (defined but not used in current page views)
- Footer with placeholder links
- Content max-width 1100px, centered
- Sticky header + nav

---

## Public Pages

### 7. HomeView (`/`)
- **Role**: Public landing
- **Content**: Large hero section with school illustration/icon, app name (SMS), tagline in Khmer, login/register buttons, "skip to dashboard" link
- **Key sections**: Hero, brand story, features grid (3 cards: school management, attendance tracking, report cards), footer with copyright
- **Design style**: Modern landing page, centered layout, gradient primary brand elements, shadow cards, clean white sections with gray dividers

### 8. LoginView (`/login`)
- **Role**: Public / Auth
- **Content**: Centered card with app logo, email input, password input, "Remember me" checkbox, login button, link to register, link to home
- **Design style**: Centered card on app-bg background, max-width ~400px, clean form layout

### 9. RegisterView (`/register`)
- **Role**: Public / Auth
- **Content**: Centered card with app logo, school select dropdown, full name, email, password, confirm password, register button, link to login, link to home
- **Design style**: Same centered card pattern as LoginView

### 10. UnauthorizedView (`/unauthorized`)
- **Role**: Public
- **Content**: Centered card with lock/access-denied icon, "គ្មានសិទ្ធិចូលប្រើ" title, description, return-to-dashboard button
- **Design style**: Minimal centered card, danger-colored elements

---

## Super Admin Pages

### 11. Super DashboardView (`/super/dashboard`)
- **Role**: Super Admin
- **Content**: Page header with title/subtitle, stats grid (total schools, total users, active users, platform health), recent activity / usage summary
- **Design style**: Stat cards (stat-card, stat-icon, stat-value pattern), metric-driven dashboard

### 12. Super SchoolsListView (`/super/schools`)
- **Role**: Super Admin
- **Content**: Page header with "Add School" button, search/filter bar, table of schools (name, domain, admin count, student count, status, actions), empty state
- **Design style**: Search bar + data table pattern, table-wrapper with thead/tbody styling, action buttons in table-actions

### 13. Super NewSchoolView (`/super/schools/new`)
- **Role**: Super Admin
- **Content**: Page header "Add New School", card with form: school name, domain, address, phone, admin email/password fields, submit button
- **Design style**: Single form card, form-group + form-input pattern

---

## Admin Pages

### 14. Admin DashboardView (`/admin/dashboard`)
- **Role**: Admin
- **Content**: Stats row (total students, teachers, classes, attendance rate), charts/recent activity, quick action buttons, recent items
- **Design style**: stat-card grid, metric cards with icon/color differentiation, tables for recent data

### 15. Admin AcademicYearsView (`/admin/academic-years`)
- **Role**: Admin
- **Content**: Page header with "New Academic Year" button, list/card view of academic years, each showing year name, current status, date range
- **Design style**: Card list with status badges, year-selection UI (standalone page before main admin)

### 16. Admin ClassesView (`/admin/classes`)
- **Role**: Admin
- **Content**: Page header with "New Class" button, search input, table of classes (name, grade, homeroom teacher, student count, actions), modal for create/edit class
- **Design style**: Search bar + table, modal form for CRUD

### 17. Admin TeachersView (`/admin/teachers`)
- **Role**: Admin
- **Content**: Page header with "Add Teacher" button, search input, teacher list (avatar, name, email, phone, subject, class, status, actions), modal for add/edit
- **Design style**: Table with avatar column, status badge, modal forms, empty state

### 18. Admin StudentsView (`/admin/students`)
- **Role**: Admin
- **Content**: Page header with "Add Student" button, search + filter by class + filter by gender + filter by status (graduated/active), table of students (name, gender, DOB, class, parent phone, status, actions), import CSV button, pagination
- **Design style**: Rich filter bar, data table with pagination, modal for add/edit/import

### 19. Admin StudentDetailView (`/admin/students/:id`)
- **Role**: Admin
- **Content**: Student profile header (name, class, photo avatar), tabs for Scores, Attendance, Health, Growth, Vaccinations, Notes; each tab has relevant sub-content
- **Design style**: Tabbed detail page, card sections per tab

### 20. Admin StudentAgeView (`/admin/students/age`)
- **Role**: Admin
- **Content**: Page header "អាយុសិស្ស", filter by class, table showing each student's age in years/months, summary stats (average age, youngest, oldest)
- **Design style**: Simple table with computed ages, summary badges

### 21. Admin AttendanceStudentsView (`/admin/attendance/students`)
- **Role**: Admin
- **Content**: Page header with "បញ្ចូលវត្តមានថ្ងៃនេះ" button, date picker, filter by class, table of students with attendance status (present/late/absent/permission), bulk update
- **Design style**: Date selector + class filter + student table with status toggle buttons per row

### 22. Admin AttendanceTeachersView (`/admin/attendance/teachers`)
- **Role**: Admin
- **Content**: Page header, date selector, filter by status (all/present/absent), teacher attendance table with status, late minutes, actions
- **Design style**: Similar to student attendance, date-driven, status badge per row

### 23. Admin ScoresView (`/admin/scores`)
- **Role**: Admin
- **Content**: Header with breadcrumb/context, class selector, score type selector (monthly/semester), subject selector, student score table with inputs for each subject, save button
- **Design style**: Selector bar + editable table, form-input inside table cells for scores

### 24. Admin HealthView (`/admin/health`)
- **Role**: Admin
- **Content**: Page header with "បន្ថែមកំណត់ត្រា" button, filter by class + student, health records table (date, weight, height, BMI, notes, actions), modal for add/edit
- **Design style**: Table with modal CRUD, BMI computed data shown

### 25. Admin SickDaysView (`/admin/sick-days`)
- **Role**: Admin
- **Content**: Page header with "បន្ថែមថ្ងៃឈឺ" button, filter by class + month, sick-day records table (student, date, reason, duration, actions), modal for add/edit
- **Design style**: Date-filtered table with modal form

### 26. Admin BudgetView (`/admin/budget`)
- **Role**: Admin
- **Content**: Page header, financial summary cards (total income, total expenses, balance), year selector, income table, expense table, buttons to add income/expense, modals for CRUD
- **Design style**: Stat cards at top, dual tables (income + expenses), modal forms

### 27. Admin InventoryView (`/admin/inventory`)
- **Role**: Admin
- **Content**: Page header with "Add Item" button, search bar, filter by category, items table (name, category, quantity, condition, status, actions), modal for add/edit
- **Design style**: Filter bar + data table, badge for condition/status

### 28. Admin LibraryView (`/admin/library`)
- **Role**: Admin
- **Content**: Dashboard-style view with stats (total books, borrowed, overdue), list of recent borrows, quick actions
- **Design style**: Card-based dashboard with stats and recent activity list

### 29. Admin UsersView (`/admin/users`)
- **Role**: Admin
- **Content**: Page header with "បន្ថែមអ្នកប្រើ" button, users table (email, full name, role, status, last login, actions), modal for add/edit user credentials/role
- **Design style**: Table with status badges, modal form for user management

### 30. Admin ReportsView (`/admin/reports`)
- **Role**: Admin
- **Content**: Page header, filter bar (class, month, semester, year), report cards / link management, list of generated report links with status, copy link, actions
- **Design style**: Filter + table of report links, badge statuses

### 31. Admin ApprovalsView (`/admin/approvals`)
- **Role**: Admin
- **Content**: Page header "ការអនុញ្ញាត", tabs (pending/approved/rejected), list of report links awaiting approval, approve/reject buttons, status badges
- **Design style**: Tabbed UI, card/list items with action buttons

### 32. Admin AdminReportPreviewView (`/admin/approvals/:reportLinkId`)
- **Role**: Admin
- **Content**: Preview of report card before approval, shows student scores, attendance, ranking, teacher message, signature areas, approve/reject buttons
- **Design style**: Full report card preview, similar to parent report card view but with admin action controls

### 33. Admin SettingsView (`/admin/settings`)
- **Role**: Admin
- **Content**: Tabbed settings page — General (school name, address, phone, logo), Academic (year management), Notifications, Security; form inputs per section
- **Design style**: Tabbed settings panels, form sections with save buttons

### 34. Admin Honorboardeditor (`/admin/honor-board-editor`)
- **Role**: Admin
- **Content**: Honor board editor tool — select academic year, class, semester; view ranked student list, select students to feature, preview board
- **Design style**: Ranked list with selection, preview card

---

## Teacher Pages

### 35. Teacher DashboardView (`/teacher/dashboard`)
- **Role**: Teacher
- **Content**: Welcome card, stats (my students, attendance rate, pending reports), upcoming holidays, recent activity, quick action buttons
- **Design style**: Stat cards + info cards dashboard

### 36. Teacher StudentsView (`/teacher/students`)
- **Role**: Teacher
- **Content**: Page header with search, student list (avatar, name, gender, class), click to student detail
- **Design style**: Card grid or list of students with avatars

### 37. Teacher StudentDetailView (`/teacher/students/:id`)
- **Role**: Teacher
- **Content**: Student profile header, tabs for Scores, Attendance, Health, Growth, Vaccinations, Notes — similar to admin detail but teacher scoped
- **Design style**: Same tabbed detail pattern as admin StudentDetailView

### 38. Teacher AttendanceView (`/teacher/attendance`)
- **Role**: Teacher
- **Content**: Date picker, class selector (if multiple), student roster with attendance status buttons (present/late/absent/permission), bulk actions, save button
- **Design style**: Date-driven attendance grid with color-coded status buttons

### 39. Teacher MyAttendanceView (`/teacher/attendance/my`)
- **Role**: Teacher
- **Content**: Calendar/month view showing teacher's own attendance records, stats (present days, late, absent, permission), history table
- **Design style**: Calendar grid + stats + table

### 40. Teacher ScoresView (`/teacher/scores`)
- **Role**: Teacher
- **Content**: Score type selection (monthly/semester), class/subject selection, student score entry table, save button
- **Design style**: Entry form with table grid

### 41. Teacher ScoresMonthlyView (`/teacher/scores/monthly`)
- **Role**: Teacher
- **Content**: Month selector, class + subject filter, student scores table for selected month, auto-calculated averages, save
- **Design style**: Month-driven score entry grid

### 42. Teacher ScoresSemesterView (`/teacher/scores/semester`)
- **Role**: Teacher
- **Content**: Semester selector, class + subject filter, student scores table with semester subjects, weighted calculation, save
- **Design style**: Semester-driven score entry grid

### 43. Teacher ScoresRankingView (`/teacher/scores/ranking`)
- **Role**: Teacher
- **Content**: Class selector, type (monthly/semester), month/semester selector, ranked student list (rank, name, average, grade), top 3 highlighted
- **Design style**: Ranked table with medal/badge indicators for top 3

### 44. Teacher ScoreSummaryView (`/teacher/scores/summary/:id`)
- **Role**: Teacher
- **Content**: Single student score summary for a given report link — scores by subject, average, grade, rank in class, attendance summary
- **Design style**: Compact card-based summary

### 45. Teacher CertificateDesignView (`/teacher/scores/certificates`)
- **Role**: Teacher
- **Content**: Certificate designer tool — select class, semester/month, rank threshold; preview certificate with border/watermark options; generate PDF
- **Design style**: Side-by-side toolbar + preview (same certificate system as parent report card)

### 46. Teacher Honorboardeditor (`/teacher/scores/honor-board-editor`)
- **Role**: Teacher
- **Content**: Honor board editor — select class, type, period; ranked student list with selection; preview
- **Design style**: Same as admin version but teacher-scoped

### 47. Teacher ReportLinkView (`/teacher/scores/report-link`)
- **Role**: Teacher
- **Content**: Generate report links — select class, score type (monthly/semester), month/semester; show generated link, copy to clipboard, share options, list of existing links
- **Design style**: Generator form + links table

### 48. Teacher ReportRepliesView (`/teacher/scores/report-replies`)
- **Role**: Teacher
- **Content**: List of parent replies to reports — shows student name, parent message, voice recording, reply date, read/unread status
- **Design style**: Card/list of reply items with audio player, text display

### 49. Teacher HolidaysView (`/teacher/holidays`)
- **Role**: Teacher
- **Content**: Calendar/table view of school holidays — date, holiday name, type (public/school), duration
- **Design style**: Calendar grid or table list with holiday badges

### 50. Teacher SickDaysView (`/teacher/sick-days`)
- **Role**: Teacher
- **Content**: Record/view sick days — date range, reason, status (pending/approved/rejected), apply button
- **Design style**: Form + history table with status badges

### 51. Teacher GrowthView (`/teacher/growth`)
- **Role**: Teacher
- **Content**: Student growth tracking — select student, view weight/height/BMI over time, chart/graph visualization, add measurement button
- **Design style**: Chart/table combo for growth metrics, visualization-focused

### 52. Teacher VaccinationsView (`/teacher/vaccinations`)
- **Role**: Teacher
- **Content**: Vaccination records — select class, student vaccination table (vaccine name, date given, next dose, status), add record modal
- **Design style**: Table with vaccine status badges, modal for add/edit

### 53. Teacher ReportsView (`/teacher/reports`)
- **Role**: Teacher
- **Content**: Report management — list of generated report links, status (draft/pending/approved), view report cards, print options
- **Design style**: List/table of report links with action buttons

---

## Librarian Pages

### 54. Librarian DashboardView (`/librarian/dashboard`)
- **Role**: Librarian
- **Content**: Stats cards (total books, borrowed books, overdue books, available), recent borrows list, quick actions (add book, issue book)
- **Design style**: Stat cards + recent activity list

### 55. Librarian BooksView (`/librarian/books`)
- **Role**: Librarian
- **Content**: Page header with "Add Book" button, search bar, filter by category, books table (title, author, ISBN, category, total copies, available, status, actions), modal for add/edit
- **Design style**: Search + filter bar, data table, modal form, status badges

### 56. Librarian BorrowsView (`/librarian/borrows`)
- **Role**: Librarian
- **Content**: Page header with "Issue Book" button, filter by status (active/returned/overdue), borrow records table (student name, book, issue date, due date, return date, status, fine, actions)
- **Design style**: Filtered table with status badges, modal for issuing books

### 57. Librarian OverdueView (`/librarian/overdue`)
- **Role**: Librarian
- **Content**: Page header "សៀវភៅហួសកំណត់", list of overdue items (student, book, due date, days overdue, phone number), "Mark Returned" button per item, empty state when clear
- **Design style**: Table with urgency (red badges for overdue), action buttons, toast notifications

---

## Parent Pages

### 58. Parent ReportDropdownView (`/parent/report/:report_link_id`)
- **Role**: Public (link-based, no auth)
- **Content**: Centered card with logo, report context (class name, period), student selector dropdown from class list, "View Report" button
- **Design style**: Clean centered card, max-width 480px, gradient logo icon, no sidebar/footer

### 59. Parent ReportCardView (`/parent/report/:report_link_id/:student_id`)
- **Role**: Public (link-based, no auth)
- **Content**: Full report card: student header (avatar, name, class), ranking section (rank circle, class stats, passed/failed), scores table (subject, score, grade A-F), attendance stats (present/late/absent/permission with rate bar), teacher message (text + voice), signature & stamp (if approved), parent reply form (text + voice recording), certificate download button (if top 3)
- **Design style**: Mobile-first card stack design, max-width 640px, grades colored by level (A green, B blue, C amber, etc.), attendance bar with gradient fill, ranking hero circle with tier colors, certificate modal with border selector and PDF preview

---

## Shared Components & Patterns

### CSS Design Tokens (`style.css`)
- **Brand**: primary-50 (#F0F4F8) → primary-900 (#1A3557), accent #4A7FA5
- **Semantic**: success (green), danger (red), warning (amber), info (blue), purple
- **Surfaces**: --bg-app (gray-50), --bg-card (white), --bg-sidebar (white)
- **Typography**: --font-sans (Inter), --font-khmer (Hanuman)
- **Shadows**: sm, md, lg, xl with gray/black values
- **Sidebar**: fixed 220px width, collapsible on mobile

### Reusable UI Classes (defined in `style.css`)
- **.card** / **.card-header** / **.card-body** / **.card-title** — white rounded container with border + shadow
- **.stat-card** / **.stat-icon** / **.stat-info** / **.stat-label** / **.stat-value** / **.stat-sub** — metric display cards with hover elevation
- **.btn** / **.btn-primary** / **.btn-secondary** / **.btn-ghost** / **.btn-danger** / **.btn-success** / **.btn-sm** / **.btn-lg** / **.btn-icon** — button variants
- **.badge** / **.badge-blue** / **.badge-green** / **.badge-yellow** / **.badge-red** / **.badge-gray** / **.badge-purple** — status labels
- **.table-wrapper** / **table** / **thead** / **tbody** / **.table-actions** — data tables with hover rows
- **.form-group** / **.form-label** / **.form-input** / **.form-select** / **.form-textarea** / **.form-error** / **.form-hint** — form controls
- **.page-header** / **.page-title** / **.page-subtitle** — page heading sections
- **.filters-bar** / **.search-input-wrap** — toolbar for search/filter
- **.tabs** / **.tab-item** — tab navigation
- **.empty-state** / **.empty-state-icon** / **.empty-state-title** / **.empty-state-desc** — empty content display
- **.modal-overlay** / **.modal** / **.modal-lg** / **.modal-header** / **.modal-title** / **.modal-body** / **.modal-footer** — modal dialogs
- **.toast-container** / **.toast** / **.toast-success** / **.toast-error** / **.toast-info** / **.toast-warning** — toast notifications
- **.skeleton** — shimmer loading placeholders
- **.app-layout** / **.sidebar** / **.main-content** / **.top-bar** / **.page-content** — app shell
- **.sidebar-brand** / **.sidebar-brand-icon** / **.sidebar-brand-text** — brand area
- **.sidebar-nav** / **.nav-section-label** / **.nav-item** — navigation items
- **.sidebar-footer** / **.sidebar-user** / **.avatar** — user area
- **.grid-cols-4** / **.grid-cols-3** / **.grid-cols-2** — responsive grid helpers
- **.dot** / **.dot-green** / **.dot-red** / **.dot-yellow** / **.dot-gray** — status indicators

### Notification System
- Realtime subscription via Supabase
- NotificationsDropdown component in admin/teacher topbars
- Toast notification system with auto-dismiss after 3s

### Certificate System (used in parent ReportCardView + teacher CertificateDesignView)
- html2canvas + jsPDF for PDF generation
- Selectable border images (4 styles: border1–border4)
- Watermark overlay
- Content includes: Ministry header, school name, "ប័ណ្ណសរសើរ" (Certificate of Honor), student name, rank, period, average, signature spaces
- Khmer OS Muol Light font for formal sections

### Voice Recording (parent reply + teacher messages)
- useVoiceRecorder composable — start/stop recording, upload to Supabase storage
- Audio player displays recorded voice
- Used in ReportCardView (parent reply) and ReportRepliesView (teacher)

### Event/Action Patterns
- CRUD operations via Supabase REST API
- Modal-based create/edit forms
- Toast feedback on success/error
- Skeleton loading states
- Empty state when no data
- Data tables with hover row highlight
- Search + filter bars for list views
- Tab navigation for detail views (student profiles)
- Color-coded badges for status indication
- Scrollable table-wrapper for wide tables
- Responsive grid: 4-col → 2-col → 1-col breakpoints
- .page-content padding: 24px (desktop) → 16px (mobile)
- Sidebar: drawer overlay pattern on mobile (position fixed, transform translateX)

---

## Page Count by Role

| Role | Pages |
|------|-------|
| Public | 4 (Home, Login, Register, Unauthorized) |
| Super Admin | 3 (Dashboard, Schools, New School) |
| Admin | 21 (Dashboard, AcademicYears, Classes, Teachers, Students, StudentDetail, StudentAge, AttendanceStudents, AttendanceTeachers, Scores, Health, SickDays, Budget, Inventory, Library, Users, Reports, Approvals, AdminReportPreview, Settings, Honorboardeditor) |
| Teacher | 19 (Dashboard, Students, StudentDetail, Attendance, MyAttendance, Scores, ScoresMonthly, ScoresSemester, ScoresRanking, ScoreSummary, CertificateDesign, Honorboardeditor, ReportLink, ReportReplies, Holidays, SickDays, Growth, Vaccinations, Reports) |
| Librarian | 4 (Dashboard, Books, Borrows, Overdue) |
| Parent | 2 (ReportDropdown, ReportCard) |
| **Total** | **53** |
