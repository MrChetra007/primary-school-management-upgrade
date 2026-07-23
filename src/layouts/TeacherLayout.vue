<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { RouterView, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useNotificationsStore } from '@/stores/notifications'
import NotificationsDropdown from '@/components/shared/NotificationsDropdown.vue'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const notificationsStore = useNotificationsStore()
const sidebarOpen = ref(false)

onMounted(() => {
  notificationsStore.fetchNotifications()
  notificationsStore.subscribe()
})

onUnmounted(() => {
  notificationsStore.unsubscribe()
})

watch(() => route.path, () => { sidebarOpen.value = false })

const userInitials = computed(() => {
  const email = auth.profile?.email || ''
  return email.slice(0, 2).toUpperCase()
})

async function logout() {
  await auth.logout()
  router.push('/login')
}

const navItems = [
  { to: '/teacher/dashboard',    icon: 'M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z',    label: 'ផ្ទាំងគ្រប់គ្រង' }, // Dashboard
  { to: '/teacher/students',     icon: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z', label: 'សិស្សរបស់ខ្ញុំ' }, // My Students
  { to: '/teacher/attendance',   icon: 'M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11', label: 'វត្តមាន' }, // Attendance
  { to: '/teacher/scores',       icon: 'M18 20V10M12 20V4M6 20v-6',                                        label: 'ពិន្ទុ' }, // Scores
  { to: '/teacher/holidays',     icon: 'M3 9h18M16 2v4M8 2v4M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', label: 'ថ្ងៃឈប់សម្រាក' }, // Holidays
  // { to: '/teacher/reports',      icon: 'M6 9V2h12v7M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2M6 14h12v8H6z', label: 'របាយការណ៍' }, // Reports
  { to: '/teacher/scores/report-link', icon: 'M10 6H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4M14 4h6m0 0v6m0-6L10 14', label: 'តំណភ្ជាប់របាយការណ៍' }, // Report Link
  { to: '/teacher/scores/report-replies', icon: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', label: 'ការឆ្លើយតប' }, // Report Replies
  { to: '/teacher/attendance/my', icon: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z', label: 'វត្តមានរបស់ខ្ញុំ' }, // My Attendance
]

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
          <div class="sidebar-brand-name">SchoolMS</div>
          <div class="sidebar-brand-sub">វិបផតថលគ្រូបង្រៀន</div>
        </div>
      </div>

      <nav class="sidebar-nav">
        <RouterLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="nav-item"
          :class="{ active: isActive(item.to) }"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
            <path :d="item.icon"/>
          </svg>
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="sidebar-footer">
        <div class="sidebar-user">
          <div class="avatar">{{ userInitials }}</div>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name">{{ auth.profile?.email?.split('@')[0] }}</div>
            <div class="sidebar-user-role">គ្រូបង្រៀន</div>
          </div>
        </div>
        <button class="nav-item logout-btn" @click="logout">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>
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
        <div style="flex:1">
          <h2 style="font-size:16px;font-weight:600;color:var(--text-primary);">{{ route.meta.title || 'ផ្ទាំងព័ត៌មានគ្រូបង្រៀន' }}</h2>
        </div>
        <div style="display:flex;align-items:center;gap:12px;">
          <NotificationsDropdown />
          <span class="badge badge-green">គ្រូបង្រៀន</span>
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
.sidebar-user { display:flex;align-items:center;gap:10px;padding:10px;border-radius:8px;margin-bottom:4px; }
.sidebar-user-info { overflow:hidden; }
.sidebar-user-name { font-size:13px;font-weight:600;color:var(--text-primary);white-space:nowrap;overflow:hidden;text-overflow:ellipsis; }
.sidebar-user-role { font-size:11px;color:var(--text-secondary); }
.logout-btn { width:100%;color:#ef4444 !important; }
.logout-btn:hover { background:rgba(239,68,68,0.1) !important; }
</style>
