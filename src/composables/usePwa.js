import { ref, onMounted, onUnmounted } from 'vue'
import { useRegisterSW } from 'virtual:pwa-register/vue'

export function usePwa() {
  const installPrompt = ref(null)
  const canInstall = ref(false)
  const isIOS = ref(false)
  const isStandalone = ref(false)
  const showIOSHint = ref(false)
  const showUpdatePrompt = ref(false)
  const offlineReady = ref(false)
  let updateInterval = null

  const {
    needRefresh,
    offlineReady: swOfflineReady,
    updateServiceWorker
  } = useRegisterSW({
    onRegisteredSW(swUrl, registration) {
      if (registration) {
        updateInterval = setInterval(() => {
          registration.update()
        }, 60 * 60 * 1000)
      }
    },
    onRegisterError(e) {
      console.error('SW registration error:', e)
    },
    onNeedRefresh() {
      showUpdatePrompt.value = true
    },
    onOfflineReady() {
      offlineReady.value = true
    }
  })

  onUnmounted(() => {
    if (updateInterval) {
      clearInterval(updateInterval)
      updateInterval = null
    }
  })

  function updateNow() {
    showUpdatePrompt.value = false
    updateServiceWorker()
  }

  function dismissUpdate() {
    showUpdatePrompt.value = false
  }

  function checkIOS() {
    const ua = navigator.userAgent || navigator.vendor || window.opera
    const iOS = /iPad|iPhone|iPod/.test(ua) && !window.MSStream
    const standalone = window.matchMedia('(display-mode: standalone)').matches
    isIOS.value = iOS
    isStandalone.value = standalone
    showIOSHint.value = iOS && !standalone
  }

  function handleBeforeInstallPrompt(e) {
    e.preventDefault()
    installPrompt.value = e
    canInstall.value = true
  }

  async function install() {
    if (!installPrompt.value) return
    installPrompt.value.prompt()
    const result = await installPrompt.value.userChoice
    if (result.outcome === 'accepted') {
      canInstall.value = false
      installPrompt.value = null
    }
  }

  function dismissIOSHint() {
    showIOSHint.value = false
  }

  onMounted(() => {
    checkIOS()
    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', () => {
      canInstall.value = false
      installPrompt.value = null
      isStandalone.value = true
      showIOSHint.value = false
    })
  })

  return {
    canInstall,
    isIOS,
    isStandalone,
    showIOSHint,
    showUpdatePrompt,
    offlineReady,
    install,
    dismissIOSHint,
    updateNow,
    dismissUpdate
  }
}
