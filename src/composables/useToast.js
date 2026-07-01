import { ref } from 'vue'

const toast = ref(null)
let timeout = null

export function useToast() {
  function showToast(msg, type = 'success', duration = 3000) {
    if (timeout) clearTimeout(timeout)
    toast.value = { msg, type }
    timeout = setTimeout(() => {
      toast.value = null
      timeout = null
    }, duration)
  }

  return { showToast, toast }
}
