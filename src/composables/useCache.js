import { ref } from 'vue'
import { useNetworkStatus } from './useNetworkStatus'

const PREFIX = 'sms_read_cache_'

export function useCache() {
  const { isOnline } = useNetworkStatus()

  function get(key) {
    try {
      const raw = localStorage.getItem(PREFIX + key)
      if (!raw) return null
      const { data, expiry } = JSON.parse(raw)
      if (expiry && Date.now() > expiry) {
        localStorage.removeItem(PREFIX + key)
        return null
      }
      return data
    } catch {
      return null
    }
  }

  function set(key, data, ttlMinutes = 1440) {
    try {
      localStorage.setItem(PREFIX + key, JSON.stringify({
        data,
        expiry: Date.now() + ttlMinutes * 60 * 1000
      }))
    } catch {
      // localStorage full or unavailable — silently fail
    }
  }

  function remove(key) {
    try {
      localStorage.removeItem(PREFIX + key)
    } catch {}
  }

  return { get, set, remove, isOnline }
}
