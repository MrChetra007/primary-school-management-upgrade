import { ref, onMounted } from 'vue'
import { useRegisterSW } from 'virtual:pwa-register/vue'

export function usePwa() {
  const installPrompt = ref(null)
  const canInstall = ref(false)
  const isIOS = ref(false)
  const isStandalone = ref(false)
  const showIOSHint = ref(false)

  const {
    needRefresh,
    offlineReady,
    updateServiceWorker
  } = useRegisterSW({
    onRegisteredSW(swUrl, registration) {
      if (registration) {
        setInterval(() => {
          registration.update()
        }, 60 * 60 * 1000)
      }
    },
    onRegisterError(e) {
      console.error('SW registration error:', e)
    }
  })

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

  function closeUpdate() {
    needRefresh.value = false
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
    install,
    dismissIOSHint,
    needRefresh,
    offlineReady,
    updateServiceWorker,
    closeUpdate
  }
}
