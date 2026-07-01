import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'

const STORAGE_KEY = 'sms_offline_queue'

function loadQueue() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
  } catch { return [] }
}

function generateId() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID()
  return Date.now().toString(36) + Math.random().toString(36).substr(2)
}

export const useOfflineQueueStore = defineStore('offlineQueue', () => {
  const queue = ref(loadQueue())
  const processing = ref(false)

  function persist() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue.value))
  }

  function enqueue(entry) {
    queue.value.push({ id: generateId(), created_at: new Date().toISOString(), ...entry })
    persist()
  }

  function remove(id) {
    queue.value = queue.value.filter(q => q.id !== id)
    persist()
  }

  const pendingCount = computed(() => queue.value.length)

  async function processQueue() {
    if (processing.value || queue.value.length === 0) return
    processing.value = true

    const entries = [...queue.value]
    for (const entry of entries) {
      try {
        let result
        if (entry.type === 'insert') {
          result = await supabase.from(entry.table).insert(entry.payload)
        } else if (entry.type === 'update') {
          let query = supabase.from(entry.table).update(entry.payload)
          for (const [key, val] of Object.entries(entry.filters || {})) query = query.eq(key, val)
          result = await query
        } else if (entry.type === 'delete') {
          let query = supabase.from(entry.table).delete()
          for (const [key, val] of Object.entries(entry.filters || {})) query = query.eq(key, val)
          result = await query
        }
        if (result && result.error) throw result.error
        remove(entry.id)
      } catch (e) {
        console.warn('OfflineQueue: sync failed for', entry.id, e.message)
      }
    }

    processing.value = false
  }

  function clear() {
    queue.value = []
    persist()
  }

  return { queue, processing, pendingCount, enqueue, remove, processQueue, clear }
})
