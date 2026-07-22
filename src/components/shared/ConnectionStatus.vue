<script setup>
import { ref, watch } from 'vue'
import { useNetworkStatus } from '@/composables/useNetworkStatus'
import { useToast } from '@/composables/useToast'
import { useOfflineQueueStore } from '@/stores/offlineQueue'
import { useAuthStore } from '@/stores/auth'
import { XMarkIcon } from '@heroicons/vue/24/outline'

const { isOnline } = useNetworkStatus()
const { showToast } = useToast()
const queueStore = useOfflineQueueStore()
const authStore = useAuthStore()
const dismissed = ref(false)
const syncing = ref(false)

watch(isOnline, async (online) => {
  if (!authStore.isTeacher) return
  dismissed.value = false
  if (online) {
    const pending = queueStore.pendingCount
    if (pending > 0) {
      syncing.value = true
      showToast(`កំពុងធ្វើសមកាលកម្មទិន្នន័យចំនួន ${pending}...`, 'info', 3000)
      await queueStore.processQueue()
      syncing.value = false
      const remaining = queueStore.pendingCount
      if (remaining === 0) {
        showToast('សមកាលកម្មទិន្នន័យបានជោគជ័យ!', 'success', 3000)
      } else {
        showToast(`សមកាលកម្មមិនពេញលេញ — នៅសល់ ${remaining} ទិន្នន័យ`, 'warning', 4000)
      }
    } else {
      showToast('ការតភ្ជាប់បណ្តាញត្រឡប់មកវិញហើយ!', 'success', 3000)
    }
  } else {
    showToast('គ្មានការតភ្ជាប់បណ្តាញ! ការផ្លាស់ប្តូរនឹងត្រូវបានរក្សាទុក និងធ្វើសមកាលកម្មពេលមានបណ្តាញវិញ', 'warning', 5000)
  }
})
</script>

<template>
  <div v-if="authStore.isTeacher && !isOnline && !dismissed" class="offline-banner">
    <div class="offline-banner-content">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4" style="flex-shrink:0;">
        <line x1="1" y1="1" x2="23" y2="23" />
        <path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55" />
        <path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39" />
        <path d="M10.71 5.05A16 16 0 0 1 22.5 8.5" />
        <path d="M1.5 8.5a16 16 0 0 1 4.5-1.78" />
        <path d="M8.53 16.11a6 6 0 0 1 6.95 0" />
        <line x1="12" y1="20" x2="12.01" y2="20" />
      </svg>
      <span v-if="queueStore.pendingCount > 0">
        គ្មានការតភ្ជាប់បណ្តាញ — ទិន្នន័យចំនួន {{ queueStore.pendingCount }} កំពុងរង់ចាំធ្វើសមកាលកម្ម
      </span>
      <span v-else>
        គ្មានការតភ្ជាប់បណ្តាញ — ការផ្លាស់ប្តូរនឹងត្រូវបានធ្វើសមកាលកម្មពេលមានបណ្តាញវិញ
      </span>
    </div>
    <div style="display:flex;align-items:center;gap:8px;">
      <span v-if="queueStore.pendingCount > 0" class="offline-badge">{{ queueStore.pendingCount }}</span>
      <button class="offline-banner-close" @click="dismissed = true">
        <XMarkIcon class="w-4 h-4" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.offline-banner {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 9998;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 16px;
  background: #fffbeb;
  border-bottom: 1px solid #fde68a;
  color: #92400e;
  font-size: 13px;
  font-weight: 500;
}
.offline-banner-content {
  display: flex;
  align-items: center;
  gap: 10px;
}
.offline-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  border-radius: 10px;
  background: #f59e0b;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}
.offline-banner-close {
  background: none;
  border: none;
  cursor: pointer;
  color: #92400e;
  padding: 4px;
  border-radius: 4px;
  flex-shrink: 0;
}
.offline-banner-close:hover {
  background: #fef3c7;
}
</style>
