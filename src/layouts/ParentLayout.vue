<script setup>
import { RouterView, RouterLink, useRoute } from 'vue-router'
import { 
  HomeIcon, 
  CalendarIcon, 
  DocumentChartBarIcon, 
  HeartIcon, 
  ScaleIcon, 
  BeakerIcon, 
  FaceFrownIcon,
  MagnifyingGlassIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id

const navItems = [
  { path: 'overview', label: 'ទិដ្ឋភាពទូទៅ', icon: HomeIcon },
  { path: 'attendance', label: 'វត្តមាន', icon: CalendarIcon },
  { path: 'scores', label: 'ពិន្ទុសិក្សា', icon: DocumentChartBarIcon },
  { path: 'health', label: 'សុខភាព', icon: HeartIcon },
  { path: 'growth', label: 'កំណើនកាយ', icon: ScaleIcon },
  { path: 'vaccinations', label: 'វ៉ាក់សាំង', icon: BeakerIcon },
  { path: 'sick-days', label: 'ប្រវត្តិឈឺ', icon: FaceFrownIcon },
]
</script>

<template>
  <div class="parent-layout">
    <!-- Header -->
    <header class="parent-header">
      <div class="header-container">
        <RouterLink to="/parent" class="parent-brand">
          <div class="parent-logo">
            <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" width="20" height="20">
              <path d="M12 2L2 7l10 5 10-5-10-5z"/>
              <path d="M2 17l10 5 10-5"/>
              <path d="M2 12l10 5 10-5"/>
            </svg>
          </div>
          <div class="brand-text">
            <span class="parent-brand-name">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</span>
            <span class="parent-brand-sub">វិបផតថលមាតាបិតា</span>
          </div>
        </RouterLink>

        <div class="header-actions">
          <template v-if="studentId">
            <RouterLink to="/parent" class="btn btn-secondary btn-sm">
              <MagnifyingGlassIcon class="w-4 h-4" />
              <span>ស្វែងរកថ្មី</span>
            </RouterLink>
          </template>
          <div class="badge badge-blue">មាតាបិតា</div>
        </div>
      </div>
    </header>

    <!-- Navigation Tabs -->
    <nav v-if="studentId" class="parent-nav">
      <div class="nav-container">
        <div class="nav-scroll-wrapper">
          <RouterLink 
            v-for="item in navItems" 
            :key="item.path"
            :to="`/parent/student/${studentId}/${item.path}`"
            class="nav-tab"
            :class="{ active: route.path.includes(item.path) }"
          >
            <component :is="item.icon" class="nav-icon" />
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>
      </div>
    </nav>

    <!-- Content Area -->
    <main class="parent-main">
      <div class="content-container">
        <RouterView v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </RouterView>
      </div>
    </main>

    <!-- Footer -->
    <footer class="parent-footer">
      <div class="footer-container">
        <p>© {{ new Date().getFullYear() }} រក្សាសិទ្ធិគ្រប់យ៉ាងដោយសាលារៀន</p>
        <div class="footer-links">
          <span>ជំនួយ</span>
          <span>ឯកជនភាព</span>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.parent-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--bg-app);
}

.parent-header {
  background: white;
  border-bottom: 1px solid var(--border-default);
  height: 72px;
  display: flex;
  align-items: center;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: var(--shadow-sm);
}

.header-container {
  max-width: 1100px;
  width: 100%;
  margin: 0 auto;
  padding: 0 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.parent-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  text-decoration: none;
}

.parent-logo {
  width: 40px;
  height: 40px;
  background: linear-gradient(135deg, var(--primary-500) 0%, var(--primary-700) 100%);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(74, 127, 165, 0.3);
}

.brand-text {
  display: flex;
  flex-direction: column;
}

.parent-brand-name {
  font-size: 15px;
  font-weight: 800;
  color: var(--text-primary);
  line-height: 1.2;
}

.parent-brand-sub {
  font-size: 12px;
  color: var(--primary-500);
  font-weight: 600;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.parent-nav {
  background: white;
  border-bottom: 1px solid var(--border-default);
  position: sticky;
  top: 72px;
  z-index: 90;
}

.nav-container {
  max-width: 1100px;
  width: 100%;
  margin: 0 auto;
  padding: 0 20px;
}

.nav-scroll-wrapper {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.nav-scroll-wrapper::-webkit-scrollbar {
  display: none;
}

.nav-tab {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 16px 12px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  text-decoration: none;
  border-bottom: 3px solid transparent;
  white-space: nowrap;
  transition: all 0.2s ease;
}

.nav-tab:hover {
  color: var(--primary-500);
  background: var(--gray-50);
}

.nav-tab.active {
  color: var(--primary-500);
  border-bottom-color: var(--primary-500);
}

.nav-icon {
  width: 20px;
  height: 20px;
  opacity: 0.8;
}

.parent-main {
  flex: 1;
  padding: 24px 0;
}

.content-container {
  max-width: 1100px;
  width: 100%;
  margin: 0 auto;
  padding: 0 20px;
}

.parent-footer {
  background: white;
  border-top: 1px solid var(--border-default);
  padding: 32px 0;
  margin-top: auto;
}

.footer-container {
  max-width: 1100px;
  width: 100%;
  margin: 0 auto;
  padding: 0 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: var(--text-muted);
  font-size: 13px;
}

.footer-links {
  display: flex;
  gap: 20px;
}

/* Animations */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

@media (max-width: 768px) {
  .header-container, .footer-container {
    flex-direction: column;
    gap: 16px;
    text-align: center;
  }
  
  .brand-text {
    text-align: left;
  }

  .nav-tab span {
    display: none;
  }
  
  .nav-tab {
    padding: 16px 20px;
  }
  
  .nav-icon {
    width: 24px;
    height: 24px;
  }
}
</style>
