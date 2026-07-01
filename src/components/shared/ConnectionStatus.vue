<script setup>
import { ref, watch } from 'vue'
import { useNetworkStatus } from '@/composables/useNetworkStatus'
import { useToast } from '@/composables/useToast'
import { XMarkIcon } from '@heroicons/vue/24/outline'

const { isOnline } = useNetworkStatus()
const { showToast } = useToast()
const dismissed = ref(false)

watch(isOnline, (online) => {
  dismissed.value = false
  if (online) {
    showToast('ការតភ្ជាប់បណ្តាញត្រឡប់មកវិញហើយ! ទិន្នន័យកំពុងធ្វើសមកាលកម្ម...', 'success', 4000)
  } else {
    showToast('គ្មានការតភ្ជាប់បណ្តាញ! ការផ្លាស់ប្តូរនឹងត្រូវបានរក្សាទុក និងធ្វើសមកាលកម្មពេលមានបណ្តាញវិញ', 'warning', 5000)
  }
})
</script>

<template>
  <div v-if="!isOnline && !dismissed" class="offline-banner">
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
      <span>គ្មានការតភ្ជាប់បណ្តាញ — ការផ្លាស់ប្តូរនឹងត្រូវបានធ្វើសមកាលកម្មពេលមានបណ្តាញវិញ</span>
    </div>
    <button class="offline-banner-close" @click="dismissed = true">
      <XMarkIcon class="w-4 h-4" />
    </button>
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
