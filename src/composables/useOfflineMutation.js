import { supabase } from '@/lib/supabase'
import { useNetworkStatus } from '@/composables/useNetworkStatus'
import { useOfflineQueueStore } from '@/stores/offlineQueue'

export function useOfflineMutation() {
  const { isOnline } = useNetworkStatus()
  const queueStore = useOfflineQueueStore()

  async function mutate(table, type, payload, filters = {}) {
    if (isOnline.value) {
      let result
      if (type === 'insert') {
        result = await supabase.from(table).insert(payload)
      } else if (type === 'update') {
        let query = supabase.from(table).update(payload)
        for (const [key, val] of Object.entries(filters)) query = query.eq(key, val)
        result = await query
      } else if (type === 'upsert') {
        result = await supabase.from(table).upsert(payload).select()
      } else if (type === 'delete') {
        let query = supabase.from(table).delete()
        for (const [key, val] of Object.entries(filters)) query = query.eq(key, val)
        result = await query
      }
      if (result && result.error) throw result.error
      return result
    }

    queueStore.enqueue({ table, type, payload, filters })
    return { data: null, error: null, queued: true }
  }

  return { mutate, pendingCount: queueStore.pendingCount }
}
