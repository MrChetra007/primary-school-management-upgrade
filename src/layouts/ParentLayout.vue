<script setup>
import { RouterView, RouterLink, useRoute } from 'vue-router'

const route = useRoute()
</script>

<template>
  <div class="parent-layout">
    <header class="parent-header">
      <RouterLink to="/parent" class="parent-brand">
        <div class="parent-logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" width="18" height="18">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
            <path d="M2 17l10 5 10-5"/>
            <path d="M2 12l10 5 10-5"/>
          </svg>
        </div>
        <span class="parent-brand-name">ទំព័រព័ត៌មានសាលា</span>
      </RouterLink>
      <div class="parent-header-right">
        <span class="badge badge-blue">មាតាបិតា / អាណាព្យាបាល</span>
      </div>
    </header>

    <main class="parent-content">
      <RouterView />
    </main>

    <footer class="parent-footer">
      <p>© {{ new Date().getFullYear() }} ប្រព័ន្ធគ្រប់គ្រងសាលារៀន — វិបផតថលមាតាបិតា</p>
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
  height: 64px;
  padding: 0 24px;
  background: white;
  border-bottom: 1px solid var(--border-default);
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  box-shadow: var(--shadow-sm);
  position: sticky;
  top: 0;
  z-index: 100;
}

.parent-brand {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 12px;
  text-decoration: none;
}

.parent-logo {
  width: 32px;
  height: 32px;
  background: var(--primary-color);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.parent-brand-name {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

.parent-header-right { display: flex; }

.parent-content {
  flex: 1;
  max-width: 1000px;
  width: 100%;
  margin: 0 auto;
  padding: 32px 20px;
}

.parent-footer {
  text-align: center;
  padding: 24px;
  font-size: 13px;
  color: var(--text-muted);
  border-top: 1px solid var(--border-default);
  background: white;
}

@media (max-width: 768px) {
  .parent-content { padding: 20px 16px; }
  .parent-header { padding: 0 16px; }
}
</style>
