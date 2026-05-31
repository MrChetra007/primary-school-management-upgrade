<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useNotificationsStore } from '@/stores/notifications'
import { formatDate } from '@/utils/formatDate'

const auth = useAuthStore()
const notificationsStore = useNotificationsStore()
const loading = ref(true)
const links = ref([])
const filterTab = ref('pending')
const processingId = ref(null)
const rejectionModal = ref(false)
const selectedLink = ref(null)
const rejectionNote = ref('')
const toast = ref(null)

const tabs = [
  { id: 'pending', label: 'កំពុងរង់ចាំ' },
  { id: 'approved', label: 'បានអនុម័ត' },
  { id: 'rejected', label: 'បដិសេធ' },
  { id: 'all', label: 'ទាំងអស់' },
]

const filteredLinks = computed(() => {
  if (filterTab.value === 'all') return links.value
  return links.value.filter(l => l.status === filterTab.value)
})

const months = ['មករា','កុម្ភៈ','មីនា','មេសា','ឧសភា','មិថុនា','កក្កដា','សីហា','កញ្ញា','តុលា','វិច្ឆិកា','ធ្នូ']

function contextLabel(link) {
  if (link.score_type === 'monthly') return `ខែ${months[link.month - 1] || ''}`
  return `ឆមាសទី${link.semester || 1}`
}

onMounted(async () => {
  await loadLinks()
})

async function loadLinks() {
  loading.value = true
  const { data } = await supabase
    .from('report_links')
    .select('*, classes!inner(class_name), teachers!report_links_created_by_fkey(full_name)')
    .order('created_at', { ascending: false })
    .limit(100)
  links.value = data || []
  loading.value = false
}

function statusBadgeClass(status) {
  if (status === 'approved') return 'badge-green'
  if (status === 'rejected') return 'badge-red'
  return 'badge-yellow'
}

function statusLabel(status) {
  if (status === 'approved') return 'បានអនុម័ត'
  if (status === 'rejected') return 'បដិសេធ'
  return 'កំពុងរង់ចាំ'
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

function openRejection(link) {
  selectedLink.value = link
  rejectionNote.value = ''
  rejectionModal.value = true
}

async function handleApprove(link) {
  processingId.value = link.id
  const teacherId = auth.teacherProfile?.id
  const { error } = await supabase
    .from('report_links')
    .update({
      status: 'approved',
      approved_at: new Date().toISOString(),
      approved_by: teacherId
    })
    .eq('id', link.id)
  processingId.value = null
  if (error) {
    showToast(error.message, 'error')
    return
  }
  link.status = 'approved'
  link.approved_at = new Date().toISOString()
  showToast('បានអនុម័តដោយជោគជ័យ!')
}

async function handleReject() {
  if (!rejectionNote.value.trim()) {
    showToast('សូមបញ្ចូលមូលហេតុនៃការបដិសេធ', 'error')
    return
  }
  processingId.value = selectedLink.value.id
  const teacherId = auth.teacherProfile?.id
  const { error } = await supabase
    .from('report_links')
    .update({
      status: 'rejected',
      rejection_note: rejectionNote.value.trim(),
      approved_at: new Date().toISOString(),
      approved_by: teacherId
    })
    .eq('id', selectedLink.value.id)
  processingId.value = null
  rejectionModal.value = false
  if (error) {
    showToast(error.message, 'error')
    return
  }
  selectedLink.value.status = 'rejected'
  selectedLink.value.rejection_note = rejectionNote.value.trim()
  showToast('បានបដិសេធដោយជោគជ័យ!')
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">ការអនុម័តតំណភ្ជាប់</h1>
        <p class="page-subtitle">ពិនិត្យ និងអនុម័តសំណើសុំតំណភ្ជាប់របាយការណ៍ពីគ្រូ</p>
      </div>
    </div>

    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">{{ toast.msg }}</div>
    </div>

    <!-- Filter Tabs -->
    <div class="tabs-nav" style="margin-bottom:20px;">
      <button
        v-for="tab in tabs" :key="tab.id"
        class="tab-btn" :class="{ active: filterTab === tab.id }"
        @click="filterTab = tab.id"
      >
        {{ tab.label }}
        <span v-if="tab.id !== 'all'" class="tab-count">{{ links.filter(l => l.status === tab.id || (tab.id === 'pending' && l.status === 'pending')).length }}</span>
      </button>
    </div>

    <div v-if="loading" class="card card-body">
      <div v-for="i in 5" :key="i" class="skeleton" style="height:60px;margin-bottom:12px;border-radius:12px;"></div>
    </div>

    <div v-else-if="filteredLinks.length === 0" class="card card-body" style="text-align:center;padding:60px 20px;color:var(--text-secondary);">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="48" height="48" style="margin:0 auto 12px;opacity:0.4;">
        <path d="M9 12h6M12 9v6M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z"/>
      </svg>
      <p style="font-size:15px;font-weight:600;">មិនទាន់មានសំណើទេ</p>
    </div>

    <div v-else class="card" style="overflow:hidden;">
      <div class="table-wrapper">
        <table class="approvals-table">
          <thead>
            <tr>
              <th>ថ្នាក់</th>
              <th>គ្រូ</th>
              <th>ប្រភេទ</th>
              <th>កាលបរិច្ឆេទ</th>
              <th>ស្ថានភាព</th>
              <th>មូលហេតុ</th>
              <th style="text-align:center;">សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="link in filteredLinks" :key="link.id">
              <td><strong>{{ link.classes?.class_name }}</strong></td>
              <td>{{ link.teachers?.full_name }}</td>
              <td>
                <span class="badge badge-gray">{{ contextLabel(link) }}</span>
              </td>
              <td>{{ formatDate(link.created_at) }}</td>
              <td>
                <span class="badge" :class="statusBadgeClass(link.status)">{{ statusLabel(link.status) }}</span>
              </td>
              <td style="max-width:200px;font-size:12px;color:var(--text-secondary);">
                {{ link.rejection_note || '-' }}
              </td>
              <td style="text-align:center;">
                <div v-if="link.status === 'pending'" class="action-btns">
                  <button
                    class="btn btn-sm btn-success"
                    :disabled="processingId === link.id"
                    @click="handleApprove(link)"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <path d="M5 13l4 4L19 7"/>
                    </svg>
                    អនុម័ត
                  </button>
                  <button
                    class="btn btn-sm btn-danger"
                    :disabled="processingId === link.id"
                    @click="openRejection(link)"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <path d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    បដិសេធ
                  </button>
                </div>
                <span v-else-if="link.status === 'approved'" style="font-size:12px;color:#16a34a;font-weight:600;">
                  {{ link.approved_at ? formatDate(link.approved_at) : '' }}
                </span>
                <span v-else style="font-size:12px;color:#dc2626;font-weight:600;">
                  {{ link.approved_at ? formatDate(link.approved_at) : '' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Rejection Modal -->
    <div v-if="rejectionModal" class="modal-overlay" @click.self="rejectionModal = false">
      <div class="modal" style="max-width:420px;">
        <div class="modal-header">
          <span class="modal-title">បដិសេធតំណភ្ជាប់</span>
        </div>
        <div class="modal-body">
          <p style="font-size:13px;color:var(--text-secondary);margin-bottom:12px;">
            សូមបញ្ចូលមូលហេតុនៃការបដិសេធ។ គ្រូនឹងទទួលបានសារជូនដំណឹង។
          </p>
          <div class="form-group">
            <label class="form-label">មូលហេតុ</label>
            <textarea
              class="form-textarea"
              v-model="rejectionNote"
              placeholder="បញ្ចូលមូលហេតុ..."
              rows="3"
            ></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="rejectionModal = false">បោះបង់</button>
          <button class="btn btn-danger" :disabled="processingId === selectedLink?.id" @click="handleReject">
            {{ processingId === selectedLink?.id ? 'កំពុងដំណើរការ...' : 'បញ្ជាក់ការបដិសេធ' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tabs-nav {
  display: flex;
  gap: 4px;
  border-bottom: 1px solid var(--border-default);
  padding: 0 4px;
}

.tab-btn {
  position: relative;
  padding: 10px 16px;
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
  background: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 6px;
}

.tab-btn:hover { color: var(--primary-color); }
.tab-btn.active {
  color: var(--primary-color);
  border-bottom-color: var(--primary-color);
}

.tab-count {
  background: #e2e8f0;
  color: #475569;
  font-size: 11px;
  font-weight: 700;
  padding: 1px 7px;
  border-radius: 8px;
}

.tab-btn.active .tab-count {
  background: var(--primary-50);
  color: var(--primary-color);
}

.approvals-table {
  width: 100%;
  border-collapse: collapse;
}

.approvals-table th {
  padding: 12px 16px;
  font-size: 12px;
  background: #f8fafc;
  color: #475569;
  text-align: left;
  white-space: nowrap;
}

.approvals-table td {
  padding: 12px 16px;
  font-size: 13px;
  border-bottom: 1px solid #f1f5f9;
}

.action-btns {
  display: flex;
  gap: 6px;
  justify-content: center;
}

.btn-success {
  background: #16a34a;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.btn-success:hover { background: #15803d; }
.btn-success:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-danger {
  background: #dc2626;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.btn-danger:hover { background: #b91c1c; }
.btn-danger:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
