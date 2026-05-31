<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useNotificationsStore } from '@/stores/notifications'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const notificationsStore = useNotificationsStore()
const auth = useAuthStore()
const open = ref(false)
const dropdownRef = ref(null)

function toggle() {
  open.value = !open.value
}

function close() {
  open.value = false
}

function handleClickOutside(e) {
  if (dropdownRef.value && !dropdownRef.value.contains(e.target)) {
    close()
  }
}

function handleNotificationClick(n) {
  if (!n.is_read) notificationsStore.markAsRead(n.id)
  close()
  if (n.type === 'approval_requested' && auth.isAdmin) {
    router.push('/admin/approvals')
  } else if (n.type === 'approval_approved' || n.type === 'approval_rejected') {
    router.push('/teacher/scores/ranking')
  }
}

function relativeTime(dateStr) {
  const now = Date.now()
  const diff = now - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'ទើបតែប៉ុន្មានវិនាទី'
  if (mins < 60) return `${mins} នាទីមុន`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours} ម៉ោងមុន`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days} ថ្ងៃមុន`
  return new Date(dateStr).toLocaleDateString('km-KH')
}

function notificationLabel(n) {
  const p = n.payload || {}
  if (n.type === 'approval_requested') {
    return `សំណើសុំការអនុញ្ញាត៖ ${p.class_name || ''}`
  }
  if (n.type === 'approval_approved') {
    return `បានអនុញ្ញាត៖ ${p.class_name || ''}`
  }
  if (n.type === 'approval_rejected') {
    return `ត្រូវបានបដិសេដ៖ ${p.class_name || ''}${p.rejection_note ? ` (${p.rejection_note})` : ''}`
  }
  return n.type
}

function typeIcon(n) {
  if (n.type === 'approval_requested') return 'M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2M9 5h6'
  if (n.type === 'approval_approved') return 'M9 12l2 2 4-4M7 21h10a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2z'
  return 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2M7 21h10a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2z'
}

function typeColor(n) {
  if (n.type === 'approval_requested') return '#f59e0b'
  if (n.type === 'approval_approved') return '#22c55e'
  if (n.type === 'approval_rejected') return '#ef4444'
  return '#64748b'
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<template>
  <div ref="dropdownRef" class="notif-dropdown">
    <button class="notif-trigger" @click.stop="toggle" title="សារជូនដំណឹង">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="20" height="20">
        <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0"/>
      </svg>
      <span v-if="notificationsStore.unreadCount > 0" class="notif-badge">
        {{ notificationsStore.unreadCount > 99 ? '99+' : notificationsStore.unreadCount }}
      </span>
    </button>

    <div v-if="open" class="notif-panel" @click.stop>
      <div class="notif-header">
        <span class="notif-header-title">សារជូនដំណឹង</span>
        <button v-if="notificationsStore.unreadCount > 0" class="notif-mark-all" @click="notificationsStore.markAllAsRead()">
          អានទាំងអស់
        </button>
      </div>

      <div class="notif-list">
        <div v-if="notificationsStore.notifications.length === 0" class="notif-empty">
          គ្មានសារជូនដំណឹង
        </div>

        <div
          v-for="n in notificationsStore.notifications.slice(0, 20)"
          :key="n.id"
          class="notif-item"
          :class="{ 'notif-unread': !n.is_read }"
          @click="handleNotificationClick(n)"
        >
          <svg viewBox="0 0 24 24" fill="none" :stroke="typeColor(n)" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" width="18" height="18" class="notif-item-icon">
            <path :d="typeIcon(n)"/>
          </svg>
          <div class="notif-item-body">
            <div class="notif-item-text">{{ notificationLabel(n) }}</div>
            <div class="notif-item-time">{{ relativeTime(n.created_at) }}</div>
          </div>
          <div v-if="!n.is_read" class="notif-dot" :style="{ background: typeColor(n) }"></div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.notif-dropdown {
  position: relative;
}

.notif-trigger {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: none;
  background: transparent;
  border-radius: 8px;
  cursor: pointer;
  color: var(--text-secondary);
  transition: all 0.15s;
}

.notif-trigger:hover {
  background: var(--primary-50);
  color: var(--primary-color);
}

.notif-badge {
  position: absolute;
  top: 2px;
  right: 2px;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  background: #ef4444;
  color: white;
  font-size: 10px;
  font-weight: 700;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}

.notif-panel {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  width: 360px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 10px 40px rgba(0,0,0,0.12);
  border: 1px solid var(--border-default);
  z-index: 100;
  overflow: hidden;
}

.notif-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  border-bottom: 1px solid var(--border-default);
}

.notif-header-title {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-primary);
}

.notif-mark-all {
  font-size: 12px;
  font-weight: 600;
  color: var(--primary-color);
  background: none;
  border: none;
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
}

.notif-mark-all:hover {
  background: var(--primary-50);
}

.notif-list {
  max-height: 360px;
  overflow-y: auto;
}

.notif-empty {
  padding: 32px 16px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13px;
}

.notif-item {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 12px 16px;
  cursor: pointer;
  transition: background 0.1s;
  border-bottom: 1px solid #f1f5f9;
}

.notif-item:hover {
  background: #f8fafc;
}

.notif-unread {
  background: #eff6ff;
}

.notif-unread:hover {
  background: #dbeafe;
}

.notif-item-icon {
  flex-shrink: 0;
  margin-top: 2px;
}

.notif-item-body {
  flex: 1;
  min-width: 0;
}

.notif-item-text {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-primary);
  line-height: 1.4;
}

.notif-unread .notif-item-text {
  font-weight: 600;
}

.notif-item-time {
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.notif-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  margin-top: 6px;
}
</style>
