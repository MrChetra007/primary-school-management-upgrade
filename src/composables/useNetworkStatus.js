import { ref, onMounted, onUnmounted } from 'vue'

const isOnline = ref(navigator.onLine)
const wasOffline = ref(false)

export function useNetworkStatus() {
  function handleOnline() {
    isOnline.value = true
    wasOffline.value = true
    setTimeout(() => { wasOffline.value = false }, 5000)
  }

  function handleOffline() {
    isOnline.value = false
  }

  onMounted(() => {
    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)
  })

  onUnmounted(() => {
    window.removeEventListener('online', handleOnline)
    window.removeEventListener('offline', handleOffline)
  })

  return { isOnline, wasOffline }
}
