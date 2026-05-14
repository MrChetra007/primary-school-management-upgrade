<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { ChevronLeftIcon, CheckCircleIcon, XCircleIcon, ChatBubbleLeftRightIcon } from '@heroicons/vue/24/outline'
import { useRouter } from 'vue-router'

const router = useRouter()
const auth = useAuthStore()

const loading = ref(true)
const classInfo = ref(null)
const reportLinks = ref([])
const selectedLinkId = ref('')
const currentLink = ref(null)
const messages = ref([])
const allStudents = ref([])
const toast = ref(null)

const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']

onMounted(async () => {
  if (auth.teacherProfile) {
    await loadClass()
  } else {
    setTimeout(async () => {
      if (auth.teacherProfile) await loadClass()
      else loading.value = false
    }, 1000)
  }
})

async function loadClass() {
  loading.value = true
  const teacherId = auth.teacherProfile.id

  const { data: classData } = await supabase
    .from('classes')
    .select('*, academic_years!inner(id, year_name, status)')
    .eq('teacher_id', teacherId)
    .eq('academic_years.status', 'active')
    .maybeSingle()

  if (classData) {
    classInfo.value = classData
    await fetchReportLinks()
  }
  loading.value = false
}

async function fetchReportLinks() {
  if (!classInfo.value) return

  const { data } = await supabase
    .from('report_links')
    .select('*')
    .eq('class_id', classInfo.value.id)
    .eq('academic_year_id', classInfo.value.academic_year_id)
    .eq('created_by', auth.teacherProfile.id)
    .order('created_at', { ascending: false })

  reportLinks.value = data || []
}

function linkLabel(link) {
  if (link.score_type === 'monthly') {
    return `ប្រចាំខែ${months[link.month - 1] || ''}`
  }
  return `ឆមាសទី${link.semester || 1}`
}

async function onLinkSelected() {
  if (!selectedLinkId.value) {
    currentLink.value = null
    messages.value = []
    allStudents.value = []
    return
  }

  const link = reportLinks.value.find(l => l.id === selectedLinkId.value)
  if (!link) return

  currentLink.value = link

  const [msgRes, stuRes] = await Promise.all([
    supabase
      .from('report_messages')
      .select('*, students(full_name, gender)')
      .eq('report_link_id', link.id)
      .order('students(full_name)'),
    supabase
      .from('students')
      .select('id, full_name, gender')
      .eq('class_id', link.class_id)
      .eq('is_graduated', false)
      .order('full_name')
  ])

  messages.value = msgRes.data || []
  allStudents.value = stuRes.data || []
}

const mergedList = computed(() => {
  return allStudents.value.map(student => {
    const msg = messages.value.find(m => m.student_id === student.id)
    const hasReply = msg && (msg.parent_text || msg.parent_voice_url)
    return {
      ...student,
      gender: (student.gender || '').toLowerCase(),
      message: msg || null,
      hasReply: !!hasReply
    }
  })
})

const repliedCount = computed(() => mergedList.value.filter(s => s.hasReply).length)
const totalCount = computed(() => mergedList.value.length)

watch(selectedLinkId, onLinkSelected)
</script>

<template>
  <div class="replies-view">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckCircleIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header">
      <div style="display:flex; align-items:center; gap:16px;">
        <button class="btn btn-ghost btn-sm btn-icon" @click="router.back()">
          <ChevronLeftIcon class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">ការឆ្លើយតបពីមាតាបិតា</h1>
          <p class="page-subtitle" v-if="classInfo">
            ថ្នាក់ <strong>{{ classInfo.class_name }}</strong> — {{ classInfo.academic_years?.year_name }}
          </p>
        </div>
      </div>
    </div>

    <!-- Report Link Selector -->
    <div class="card filters-card" style="margin-bottom:24px;">
      <div class="card-body" style="display:flex; gap:16px; align-items:flex-end; flex-wrap:wrap;">
        <div class="form-group" style="width:320px;">
          <label class="form-label">ជ្រើសរើសតំណភ្ជាប់របាយការណ៍</label>
          <select class="form-select" v-model="selectedLinkId">
            <option value="">-- ជ្រើសរើសតំណភ្ជាប់ --</option>
            <option v-for="link in reportLinks" :key="link.id" :value="link.id">
              {{ linkLabel(link) }} ({{ link.created_at?.split('T')[0] || '' }})
            </option>
          </select>
        </div>
      </div>
    </div>

    <!-- Summary -->
    <div v-if="currentLink" class="card" style="margin-bottom:24px;">
      <div class="card-body" style="display:flex; gap:24px; align-items:center;">
        <div class="stat-info-simple">
          <ChatBubbleLeftRightIcon class="w-5 h-5" style="color:var(--primary-500);" />
          <span>សិស្សសរុប៖ <strong>{{ totalCount }}</strong> នាក់</span>
        </div>
        <div class="stat-info-simple">
          <CheckCircleIcon class="w-5 h-5" style="color:#10b981;" />
          <span>បានឆ្លើយតប៖ <strong>{{ repliedCount }}</strong> នាក់</span>
        </div>
        <div class="stat-info-simple">
          <XCircleIcon class="w-5 h-5" style="color:#94a3b8;" />
          <span>មិនទាន់ឆ្លើយតប៖ <strong>{{ totalCount - repliedCount }}</strong> នាក់</span>
        </div>
      </div>
    </div>

    <!-- No link generated yet -->
    <div v-if="!loading && !currentLink" class="card">
      <div class="card-body empty-state">
        <ChatBubbleLeftRightIcon class="w-12 h-12" style="color:var(--text-muted);" />
        <p class="empty-state-title">មិនទាន់មានតំណភ្ជាប់របាយការណ៍</p>
        <p class="empty-state-desc">សូមចូលទៅកាន់ទំព័រចំណាត់ថ្នាក់ដើម្បីបង្កើតតំណភ្ជាប់ជាមុន</p>
        <button class="btn btn-primary" @click="router.push('/teacher/scores/ranking')">
          ទៅកាន់ទំព័រចំណាត់ថ្នាក់
        </button>
      </div>
    </div>

    <!-- Student List -->
    <div v-if="currentLink" class="card">
      <div class="table-wrapper">
        <table class="replies-table">
          <thead>
            <tr>
              <th style="width:60px; text-align:center;">ល.រ</th>
              <th>ឈ្មោះសិស្ស</th>
              <th style="width:100px; text-align:center;">ភេទ</th>
              <th style="width:120px; text-align:center;">ស្ថានភាព</th>
              <th>សារពីមាតាបិតា</th>
              <th style="width:160px;">សំឡេង</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, idx) in mergedList" :key="item.id" :class="{ 'has-reply': item.hasReply }">
              <td style="text-align:center;">{{ idx + 1 }}</td>
              <td>
                <div style="display:flex; align-items:center; gap:10px;">
                  <div class="mini-avatar" :style="{ background: item.gender === 'female' ? '#ec4899' : 'var(--primary-color)' }">
                    {{ (item.full_name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??' }}
                  </div>
                  <span style="font-weight:600;">{{ item.full_name }}</span>
                </div>
              </td>
              <td style="text-align:center;">
                <span class="gender-badge" :class="(item.gender || '').toLowerCase()">
                  {{ item.gender === 'female' ? 'ស្រី' : 'ប្រុស' }}
                </span>
              </td>
              <td style="text-align:center;">
                <span v-if="item.hasReply" class="badge badge-green">
                  <CheckCircleIcon class="w-3 h-3" />
                  បានឆ្លើយតប
                </span>
                <span v-else class="badge badge-gray">
                  <XCircleIcon class="w-3 h-3" />
                  មិនទាន់
                </span>
              </td>
              <td style="max-width:260px;">
                <p v-if="item.message?.parent_text" class="reply-text">{{ item.message.parent_text }}</p>
                <p v-else class="reply-empty">—</p>
              </td>
              <td>
                <audio
                  v-if="item.message?.parent_voice_url"
                  :src="item.message.parent_voice_url"
                  controls
                  style="width:100%; height:32px;"
                ></audio>
                <span v-else class="reply-empty">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.replies-view {
  max-width: 1000px;
  margin: 0 auto;
}

.stat-info-simple {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--text-secondary);
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
}

.mini-avatar {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 11px;
  color: white;
  flex-shrink: 0;
}

.gender-badge {
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 700;
}

.gender-badge.female { background: #fdf2f8; color: #db2777; }
.gender-badge.male { background: #eff6ff; color: #2563eb; }

.replies-table th {
  padding: 12px 14px;
  font-size: 12px;
  background: #f8fafc;
  color: var(--text-secondary);
}

.replies-table td {
  padding: 14px;
  border-bottom: 1px solid var(--border-default);
  font-size: 13px;
  vertical-align: middle;
}

.replies-table tr.has-reply td {
  background: #fafef5;
}

.reply-text {
  white-space: pre-wrap;
  line-height: 1.5;
  font-size: 13px;
  color: var(--text-primary);
}

.reply-empty {
  color: var(--text-muted);
  font-size: 13px;
}
</style>
