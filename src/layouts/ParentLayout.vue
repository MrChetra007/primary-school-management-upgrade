<script setup>
import { RouterView } from 'vue-router'
</script>

<template>
  <div class="parent-layout">
    <main class="parent-main">
      <div class="content-container">
        <RouterView />
      </div>
    </main>
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
