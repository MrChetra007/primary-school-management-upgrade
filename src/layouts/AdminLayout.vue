<script setup>
import { ref, computed, watch } from 'vue'
import { RouterView, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { useSchoolStore } from '@/stores/school'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const schoolStore = useSchoolStore()
const sidebarOpen = ref(false)

// Close sidebar on route change (mobile)
watch(() => route.path, () => {
  sidebarOpen.value = false
})

const userInitials = computed(() => {
  const email = auth.profile?.email || ''
  return email.slice(0, 2).toUpperCase()
})

async function logout() {
  await auth.logout()
  router.push('/login')
}

const navGroups = [
  {
    label: 'ទិដ្ឋភាពទូទៅ', // Overview
    items: [
      { to: '/admin/dashboard', icon: 'grid', label: 'ផ្ទាំងគ្រប់គ្រង' }, // Dashboard
    ],
  },
  {
    label: 'ការរៀបចំសាលារៀន', // School Setup
    items: [
      { to: '/admin/settings', icon: 'settings', label: 'ការកំណត់' }, // Settings
    ],
  },
  {
    label: 'បុគ្គលិក និង សិស្ស', // People
    items: [
      { to: '/admin/teachers',  icon: 'users',    label: 'គ្រូបង្រៀន' }, // Teachers
      { to: '/admin/classes',   icon: 'layers',   label: 'ថ្នាក់រៀន' }, // Classes
      { to: '/admin/students',  icon: 'user',     label: 'សិស្ស' }, // Students
      { to: '/admin/users',     icon: 'shield',   label: 'គណនីអ្នកប្រើប្រាស់' }, // User Accounts
    ],
  },
  {
    label: 'វត្តមាន', // Attendance
    items: [
      { to: '/admin/attendance/students', icon: 'check-square', label: 'វត្តមានសិស្ស' }, // Student Attendance
      { to: '/admin/attendance/teachers', icon: 'user-check',   label: 'វត្តមានគ្រូ' }, // Teacher Attendance
    ],
  },
  {
    label: 'ការសិក្សា', // Academics
    items: [
      { to: '/admin/scores',    icon: 'bar-chart-2', label: 'ពិន្ទុ' }, // Scores
      { to: '/admin/health',    icon: 'heart',       label: 'សុខភាព' }, // Health Records
      { to: '/admin/sick-days', icon: 'thermometer', label: 'ថ្ងៃឈឺ' }, // Sick Days
    ],
  },
  {
    label: 'ហិរញ្ញវត្ថុ និង ធនធាន', // Finance & Resources
    items: [
      { to: '/admin/budget',    icon: 'dollar-sign', label: 'ថវិកា' }, // Budget
      { to: '/admin/inventory', icon: 'package',     label: 'សម្ភារៈ/ឧបករណ៍' }, // Inventory
      { to: '/admin/library',   icon: 'book',        label: 'បណ្ណាល័យ' }, // Library
    ],
  },
  {
    label: 'របាយការណ៍', // Reports
    items: [
      { to: '/admin/reports', icon: 'printer', label: 'របាយការណ៍ និង បោះពុម្ព' }, // Reports & Print
    ],
  },
]

// Icon SVG paths
const icons = {
  grid:         'M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z',
  info:         'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z',
  calendar:     'M3 9h18M16 2v4M8 2v4M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  'book-open':  'M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2zM22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z',
  sun:          'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42',
  users:        'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  layers:       'M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5',
  user:         'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  'check-square':'M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11',
  'user-check': 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM17 11l2 2 4-4',
  'bar-chart-2':'M18 20V10M12 20V4M6 20v-6',
  heart:        'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z',
  thermometer:  'M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z',
  'dollar-sign':'M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6',
  package:      'M16.5 9.4l-9-5.19M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z',
  book:         'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z',
  printer:      'M6 9V2h12v7M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2M6 14h12v8H6z',
  'log-out':    'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
  shield:       'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
  settings:     'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z',
}

function getIconPath(name) {
  return icons[name] || icons['grid']
}

function isActive(path) {
  return route.path.startsWith(path)
}
</script>

<template>
  <div class="app-layout">
    <div v-if="sidebarOpen" class="sidebar-overlay" @click="sidebarOpen = false"></div>

    <aside class="sidebar" :class="{ 'mobile-open': sidebarOpen }">
      <div class="sidebar-brand">
        <div class="sidebar-brand-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" width="20" height="20">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
            <path d="M2 17l10 5 10-5"/>
            <path d="M2 12l10 5 10-5"/>
          </svg>
        </div>
        <div class="sidebar-brand-text">
          <div class="sidebar-brand-name">SchoolAdmin</div>
          <div class="sidebar-brand-sub">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</div>
        </div>
      </div>

      <nav class="sidebar-nav">
        <template v-for="group in navGroups" :key="group.label">
          <div class="nav-section-label">{{ group.label }}</div>
          <RouterLink
            v-for="item in group.items"
            :key="item.to"
            :to="item.to"
            class="nav-item"
            :class="{ active: isActive(item.to) }"
          >
            <svg viewBox="0 0 24 24" fill="none" :stroke="'currentColor'" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
              <path :d="getIconPath(item.icon)"/>
            </svg>
            {{ item.label }}
          </RouterLink>
        </template>
      </nav>

      <div class="sidebar-footer">
        <div class="sidebar-user">
          <div class="avatar">{{ userInitials }}</div>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name">{{ auth.profile?.email?.split('@')[0] }}</div>
            <div class="sidebar-user-role">អ្នកគ្រប់គ្រង</div>
          </div>
        </div>
        <button class="nav-item logout-btn" @click="logout">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
            <path :d="getIconPath('log-out')"/>
          </svg>
          ចាកចេញ
        </button>
      </div>
    </aside>

    <div class="main-content">
      <header class="top-bar">
        <button class="mobile-toggle" @click="sidebarOpen = true" style="margin-right: 8px;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <path d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
        <div class="top-bar-left">
          <button class="btn btn-ghost btn-sm back-btn" @click="router.push('/admin/academic-years')" title="ប្តូរឆ្នាំសិក្សា">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="16" height="16"><polyline points="15 18 9 12 15 6"/></svg>
            ប្តូរឆ្នាំ
          </button>
          <div class="v-divider"></div>
          <h2 class="top-bar-title">{{ route.meta.title || 'ផ្ទាំងគ្រប់គ្រង' }}</h2>
          <div v-if="schoolStore.schoolName" class="school-badge">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
            {{ schoolStore.schoolName }}
          </div>
          <div v-if="yearStore.selectedYearName" class="year-badge">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <path d="M3 9h18M16 2v4M8 2v4M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
            </svg>
            {{ yearStore.selectedYearName }}
          </div>
        </div>
        <div class="top-bar-right">
          <span class="role-tag">អ្នកគ្រប់គ្រង</span>
          <div class="avatar">{{ userInitials }}</div>
        </div>
      </header>

      <main class="page-content">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<style scoped>
.top-bar-left { flex: 1; display: flex; align-items: center; gap: 12px; }
.top-bar-title { font-size: 16px; font-weight: 600; color: var(--text-primary); }

.year-badge, .school-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
}
.school-badge {
  background: var(--emerald-50);
  color: var(--emerald-700);
}
.year-badge {
  background: var(--primary-50);
  color: var(--primary-700);
}
.top-bar-right { display: flex; align-items: center; gap: 12px; margin-left: auto; }

.sidebar-user {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px;
  border-radius: 8px;
  margin-bottom: 4px;
}
.sidebar-user-info { overflow: hidden; }
.sidebar-user-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sidebar-user-role { font-size: 11px; color: var(--text-secondary); }

.logout-btn {
  width: 100%;
  color: #ef4444 !important;
}
.logout-btn:hover { background: rgba(239,68,68,0.1) !important; }
.back-btn {
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  gap: 4px;
  padding: 6px 10px;
}
.back-btn:hover {
  color: var(--primary-color);
  background: var(--primary-50);
}
.v-divider {
  width: 1px;
  height: 20px;
  background: var(--border-default);
  margin: 0 12px;
}
.role-tag {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--primary-color);
  background: var(--primary-50);
  padding: 4px 10px;
  border-radius: 20px;
}
</style>
