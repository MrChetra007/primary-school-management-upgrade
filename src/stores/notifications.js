import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from './auth'

export const useNotificationsStore = defineStore('notifications', () => {
  const notifications = ref([])
  const loading = ref(false)
  let channel = null

  const unreadCount = computed(() => notifications.value.filter(n => !n.is_read).length)

  async function fetchNotifications() {
    const auth = useAuthStore()
    if (!auth.userId) return
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('recipient_user_id', auth.userId)
        .order('created_at', { ascending: false })
        .limit(50)
      if (error) throw error
      notifications.value = data || []
    } catch (e) {
      console.error('NotificationsStore: fetch error', e)
    } finally {
      loading.value = false
    }
  }

  async function markAsRead(id) {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
    if (!error) {
      const n = notifications.value.find(x => x.id === id)
      if (n) n.is_read = true
    }
  }

  async function markAllAsRead() {
    const auth = useAuthStore()
    if (!auth.userId) return
    const unreadIds = notifications.value.filter(n => !n.is_read).map(n => n.id)
    if (unreadIds.length === 0) return
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .in('id', unreadIds)
    if (!error) {
      notifications.value.forEach(n => { n.is_read = true })
    }
  }

  function subscribe() {
    const auth = useAuthStore()
    if (!auth.userId || channel) return

    channel = supabase
      .channel('notifications-realtime')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `recipient_user_id=eq.${auth.userId}`
        },
        (payload) => {
          notifications.value.unshift(payload.new)
        }
      )
      .subscribe()
  }

  function unsubscribe() {
    if (channel) {
      supabase.removeChannel(channel)
      channel = null
    }
  }

  return {
    notifications,
    loading,
    unreadCount,
    fetchNotifications,
    markAsRead,
    markAllAsRead,
    subscribe,
    unsubscribe
  }
})
