<script setup>
import { RouterView } from 'vue-router'
import ToastContainer from '@/components/shared/ToastContainer.vue'
import ConnectionStatus from '@/components/shared/ConnectionStatus.vue'
import { usePwa } from '@/composables/usePwa'

const { showUpdatePrompt, offlineReady, updateNow, dismissUpdate } = usePwa()
</script>

<template>
  <ConnectionStatus />

  <!-- Update banner — shown on every page when new SW is waiting -->
  <div v-if="showUpdatePrompt" class="update-banner">
    <div class="update-banner-inner">
      <div class="update-banner-body">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" class="update-banner-icon">
          <path d="M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/>
        </svg>
        <div>
          <p class="update-banner-title">កំណែថ្មីមានហើយ!</p>
          <p class="update-banner-desc">សូមធ្វើការអាប់ដេតដើម្បីទទួលបានមុខងារថ្មីៗ</p>
        </div>
      </div>
      <div class="update-banner-actions">
        <button class="update-btn update-btn-reload" @click="updateNow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <path d="M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/>
          </svg>
          អាប់ដេតឥឡូវនេះ
        </button>
        <button class="update-btn update-btn-dismiss" @click="dismissUpdate">ក្រោយ</button>
      </div>
    </div>
  </div>

  <RouterView />
  <ToastContainer />
</template>

<style scoped>
.update-banner {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 9999;
  background: #1e293b;
  color: #fff;
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.25);
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.update-banner-inner {
  max-width: 640px;
  margin: 0 auto;
  padding: 16px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.update-banner-body {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.update-banner-icon {
  flex-shrink: 0;
  color: #60a5fa;
}

.update-banner-title {
  font-weight: 700;
  font-size: 14px;
  margin: 0;
}

.update-banner-desc {
  font-size: 12px;
  color: #94a3b8;
  margin: 2px 0 0;
}

.update-banner-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.update-btn {
  padding: 8px 14px;
  border: none;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: all 0.15s;
  white-space: nowrap;
}

.update-btn-reload {
  background: #2563eb;
  color: #fff;
}

.update-btn-reload:hover {
  background: #1d4ed8;
}

.update-btn-dismiss {
  background: transparent;
  color: #94a3b8;
  border: 1px solid #475569;
}

.update-btn-dismiss:hover {
  background: #334155;
  color: #fff;
}

@media (max-width: 480px) {
  .update-banner-inner {
    flex-direction: column;
    align-items: stretch;
    padding: 14px 16px;
    gap: 12px;
  }

  .update-banner-actions {
    justify-content: stretch;
  }

  .update-btn {
    flex: 1;
    justify-content: center;
  }
}
</style>
