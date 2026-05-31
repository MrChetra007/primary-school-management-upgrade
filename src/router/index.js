import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // ── Public ──────────────────────────────────────────────
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue'),
      meta: { public: true },
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/auth/LoginView.vue'),
      meta: { public: true },
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('@/views/auth/RegisterView.vue'),
      meta: { public: true },
    },
    {
      path: '/unauthorized',
      name: 'unauthorized',
      component: () => import('@/views/auth/UnauthorizedView.vue'),
      meta: { public: true },
    },

    // ── Super Admin (Platform Level) ───────────────────────
    {
      path: '/super',
      component: () => import('@/layouts/SuperLayout.vue'),
      meta: { requiresAuth: true, role: 'super_admin' },
      children: [
        { path: '', redirect: '/super/dashboard' },
        { path: 'dashboard', name: 'super-dashboard', component: () => import('@/views/super/DashboardView.vue') },
        { path: 'schools',   name: 'super-schools',   component: () => import('@/views/super/SchoolsListView.vue') },
        { path: 'schools/new', name: 'super-schools-new', component: () => import('@/views/super/NewSchoolView.vue') },
        { path: 'users',     name: 'super-users',     component: () => import('@/views/admin/UsersView.vue') }, // Reuse admin users view for now
        { path: 'settings',  name: 'super-settings',  component: () => import('@/views/admin/SettingsView.vue') }, // Reuse settings view
      ],
    },

    // ── Admin Standalone (Layer 1) ─────────────────────────
    {
      path: '/admin/academic-years',
      name: 'admin-academic-years',
      component: () => import('@/views/admin/AcademicYearsView.vue'),
      meta: { requiresAuth: true, role: 'admin' },
    },

    // ── Admin App (Layer 2) ────────────────────────────────
    {
      path: '/admin',
      component: () => import('@/layouts/AdminLayout.vue'),
      meta: { requiresAuth: true, role: 'admin' },
      children: [
        { path: '', redirect: '/admin/dashboard' },
        { path: 'dashboard',       name: 'admin-dashboard',       component: () => import('@/views/admin/DashboardView.vue') },
        { path: 'settings',        name: 'admin-settings',        component: () => import('@/views/admin/SettingsView.vue') },
        { path: 'classes',         name: 'admin-classes',         component: () => import('@/views/admin/ClassesView.vue') },
        { path: 'teachers',        name: 'admin-teachers',        component: () => import('@/views/admin/TeachersView.vue') },
        { path: 'students',        name: 'admin-students',        component: () => import('@/views/admin/StudentsView.vue') },
        { path: 'students/age',    name: 'admin-student-age',     component: () => import('@/views/admin/StudentAgeView.vue') },
        { path: 'students/:id',    name: 'admin-student-detail',  component: () => import('@/views/admin/StudentDetailView.vue') },
        { path: 'attendance/students', name: 'admin-attendance-students', component: () => import('@/views/admin/AttendanceStudentsView.vue') },
        { path: 'attendance/teachers', name: 'admin-attendance-teachers', component: () => import('@/views/admin/AttendanceTeachersView.vue') },
        { path: 'scores',          name: 'admin-scores',          component: () => import('@/views/admin/ScoresView.vue') },
        { path: 'health',          name: 'admin-health',          component: () => import('@/views/admin/HealthView.vue') },
        { path: 'sick-days',       name: 'admin-sick-days',       component: () => import('@/views/admin/SickDaysView.vue') },
        { path: 'budget',          name: 'admin-budget',          component: () => import('@/views/admin/BudgetView.vue') },
        { path: 'inventory',       name: 'admin-inventory',       component: () => import('@/views/admin/InventoryView.vue') },
        { path: 'library',         name: 'admin-library',         component: () => import('@/views/admin/LibraryView.vue') },
        { path: 'users',           name: 'admin-users',           component: () => import('@/views/admin/UsersView.vue') },
        { path: 'reports',         name: 'admin-reports',         component: () => import('@/views/admin/ReportsView.vue') },
        { path: 'approvals',       name: 'admin-approvals',       component: () => import('@/views/admin/ApprovalsView.vue') },
        // {path: 'honor-board', name: 'admin-honor-board', component: () => import('@/views/admin/Honorboard.vue')},
        {path: 'honor-board-editor', name: 'admin-honor-board-editor', component: () => import('@/views/admin/Honorboardeditor.vue')},
      ],
    },

    // ── Teacher ───────────────────────────────────────────
    {
      path: '/teacher',
      component: () => import('@/layouts/TeacherLayout.vue'),
      meta: { requiresAuth: true, role: 'teacher' },
      children: [
        { path: '', redirect: '/teacher/dashboard' },
        { path: 'dashboard',       name: 'teacher-dashboard',       component: () => import('@/views/teacher/DashboardView.vue') },
        { path: 'students',        name: 'teacher-students',        component: () => import('@/views/teacher/StudentsView.vue') },
        { path: 'students/:id',    name: 'teacher-student-detail',  component: () => import('@/views/teacher/StudentDetailView.vue') },
        { path: 'attendance',      name: 'teacher-attendance',      component: () => import('@/views/teacher/AttendanceView.vue') },
        { path: 'attendance/my',   name: 'teacher-my-attendance',   component: () => import('@/views/teacher/MyAttendanceView.vue') },
        { path: 'scores',          name: 'teacher-scores',          component: () => import('@/views/teacher/ScoresView.vue') },
        { path: 'scores/monthly',  name: 'teacher-scores-monthly',  component: () => import('@/views/teacher/ScoresMonthlyView.vue') },
        { path: 'scores/semester', name: 'teacher-scores-semester', component: () => import('@/views/teacher/ScoresSemesterView.vue') },
        { path: 'scores/ranking',  name: 'teacher-scores-ranking',  component: () => import('@/views/teacher/ScoresRankingView.vue') },
        { path: 'scores/certificates', name: 'teacher-scores-certificates', component: () => import('@/views/teacher/CertificateDesignView.vue') },
        { path: 'scores/honor-board-editor', name: 'teacher-honor-board-editor', component: () => import('@/views/teacher/Honorboardeditor.vue') },
        { path: 'scores/report-replies', name: 'teacher-scores-report-replies', component: () => import('@/views/teacher/ReportRepliesView.vue') },
        { path: 'scores/summary/:id', name: 'teacher-scores-summary', component: () => import('@/views/teacher/ScoreSummaryView.vue') },
        { path: 'sick-days',       name: 'teacher-sick-days',       component: () => import('@/views/teacher/SickDaysView.vue') },
        { path: 'growth',          name: 'teacher-growth',          component: () => import('@/views/teacher/GrowthView.vue') },
        { path: 'vaccinations',    name: 'teacher-vaccinations',    component: () => import('@/views/teacher/VaccinationsView.vue') },
        { path: 'holidays',        name: 'teacher-holidays',        component: () => import('@/views/teacher/HolidaysView.vue') },
        { path: 'reports',         name: 'teacher-reports',         component: () => import('@/views/teacher/ReportsView.vue') },
      ],
    },

    // ── Librarian ─────────────────────────────────────────
    {
      path: '/librarian',
      component: () => import('@/layouts/LibrarianLayout.vue'),
      meta: { requiresAuth: true, role: 'librarian' },
      children: [
        { path: '', redirect: '/librarian/dashboard' },
        { path: 'dashboard', name: 'librarian-dashboard', component: () => import('@/views/librarian/DashboardView.vue') },
        { path: 'books',     name: 'librarian-books',     component: () => import('@/views/librarian/BooksView.vue') },
        { path: 'borrows',   name: 'librarian-borrows',   component: () => import('@/views/librarian/BorrowsView.vue') },
        { path: 'overdue',   name: 'librarian-overdue',   component: () => import('@/views/librarian/OverdueView.vue') },
      ],
    },

    // ── Parent (public / anon — link-only) ────────────────
    {
      path: '/parent/report/:report_link_id',
      name: 'parent-report-dropdown',
      component: () => import('@/views/parent/ReportDropdownView.vue'),
      meta: { public: true },
    },
    {
      path: '/parent/report/:report_link_id/:student_id',
      name: 'parent-report-card',
      component: () => import('@/views/parent/ReportCardView.vue'),
      meta: { public: true },
    },

    // ── 404 ───────────────────────────────────────────────
    { path: '/:pathMatch(.*)*', redirect: '/login' },
  ],
})

// Navigation guard
router.beforeEach(async (to) => {
  const auth = useAuthStore()

  // Initialize auth state if session is not loaded
  if (!auth.isLoggedIn) {
    await auth.init()
  }

  // 1. Always allow public routes
  const isPublic = to.matched.some(record => record.meta.public)
  if (isPublic) return true

  // 2. Auth Required Check
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  if (requiresAuth && !auth.isLoggedIn) {
    return { name: 'login' }
  }

  // 3. Role Check
  if (to.meta.role && auth.role !== to.meta.role) {
    return { name: 'unauthorized' }
  }

  // 4. Academic Year Guard for Admin
  if (auth.role === 'admin' && requiresAuth && to.name !== 'admin-academic-years') {
    const yearStore = useAcademicYearStore()
    if (!yearStore.selectedYearId) {
      return { name: 'admin-academic-years' }
    }
  }

  return true
})

export default router
