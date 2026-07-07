<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useNotificationsStore } from '@/stores/notifications'
import { computeRank } from '@/utils/scoreCalculator'
import { useToast } from '@/composables/useToast'
import { genderColor } from '@/utils/gender'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const notificationsStore = useNotificationsStore()
const reportLinkId = route.params.reportLinkId

const { showToast } = useToast()
const loading = ref(true)
const link = ref(null)
const students = ref([])
const allScores = ref([])
const attendancesMap = ref({})
const subjects = ref([])
const processing = ref(false)
const rejectionModal = ref(false)
const rejectionNote = ref('')

const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']

function contextLabel() {
  if (!link.value) return ''
  if (link.value.score_type === 'monthly') {
    return `ប្រចាំខែ${months[link.value.month - 1] || ''}`
  }
  return `ឆមាសទី${link.value.semester || 1}`
}

function getGrade(score) {
  if (score >= 9) return 'A'
  if (score >= 8) return 'B'
  if (score >= 7) return 'C'
  if (score >= 6) return 'D'
  if (score >= 5) return 'E'
  return 'F'
}

onMounted(async () => {
  const { data: linkData } = await supabase
    .from('report_links')
    .select('*, classes!inner(class_name), teachers!report_links_created_by_fkey(full_name)')
    .eq('id', reportLinkId)
    .single()

  if (!linkData) {
    loading.value = false
    return
  }
  link.value = linkData

  const { data: stuData } = await supabase
    .from('students')
    .select('id, full_name, gender')
    .eq('class_id', linkData.class_id)
    .eq('is_graduated', false)
    .order('full_name')

  students.value = stuData || []
  const studentIds = (stuData || []).map(s => s.id)
  if (studentIds.length === 0) {
    loading.value = false
    return
  }

  const { data: csData } = await supabase
    .from('class_subjects')
    .select('id, subject_id, subjects(subject_name)')
    .eq('class_id', linkData.class_id)

  subjects.value = csData || []

  const scoreQuery = supabase
    .from('scores')
    .select('*, subjects(subject_name)')
    .in('student_id', studentIds)
    .eq('academic_year_id', linkData.academic_year_id)
    .eq('score_type', linkData.score_type)

  if (linkData.score_type === 'monthly') {
    scoreQuery.eq('month', linkData.month)
  }

  const { data: scoreData } = await scoreQuery
  allScores.value = scoreData || []

  const now = new Date()
  const year = now.getFullYear()
  let month = linkData.month || now.getMonth() + 1
  const startDate = `${year}-${String(month).padStart(2, '0')}-01`
  const endMonth = month === 12 ? 1 : month + 1
  const endYear = month === 12 ? year + 1 : year
  const endDate = `${endYear}-${String(endMonth).padStart(2, '0')}-01`

  const { data: attData } = await supabase
    .from('attendances')
    .select('*')
    .in('student_id', studentIds)
    .gte('date', startDate)
    .lt('date', endDate)

  const attMap = {}
  for (const att of attData || []) {
    if (!attMap[att.student_id]) attMap[att.student_id] = []
    attMap[att.student_id].push(att)
  }
  attendancesMap.value = attMap

  loading.value = false
})

const rankedList = computed(() => {
  const list = students.value.map(s => {
    const ss = allScores.value.filter(sc => sc.student_id === s.id).map(sc => ({ score: sc.score }))
    return {
      id: s.id,
      full_name: s.full_name,
      gender: s.gender,
      average: ss.length > 0
        ? Number((ss.reduce((a, b) => a + Number(b.score), 0) / ss.length).toFixed(2))
        : 0
    }
  })
  return computeRank(list)
})

const classStats = computed(() => {
  const list = rankedList.value
  if (list.length === 0) return null
  const avg = list.reduce((a, b) => a + b.average, 0) / list.length
  return {
    total: list.length,
    classAverage: Number(avg.toFixed(2)),
    highest: Math.max(...list.map(p => p.average)),
    lowest: Math.min(...list.map(p => p.average)),
    passed: list.filter(p => p.average >= 5).length
  }
})

function getStudentScores(studentId) {
  const subjectMap = {}
  const ss = allScores.value.filter(sc => sc.student_id === studentId)
  for (const cs of subjects.value) {
    const match = ss.find(s => s.subject_id === cs.subject_id)
    subjectMap[cs.subject_id] = match ? match.score : '-'
  }
  return subjectMap
}

function getStudentAttendance(studentId) {
  const atts = attendancesMap.value[studentId] || []
  const total = atts.length
  if (total === 0) return { total: 0, present: 0, rate: 0 }
  const present = atts.filter(a => a.status === 'present').length
  const rate = Math.round((present / total) * 100)
  return { total, present, rate }
}

function getStudentRank(studentId) {
  return rankedList.value.find(r => r.id === studentId) || null
}

async function handleApprove() {
  processing.value = true
  const { error } = await supabase
    .from('report_links')
    .update({
      status: 'approved',
      approved_at: new Date().toISOString(),
      approved_by: auth.teacherProfile?.id
    })
    .eq('id', reportLinkId)
  processing.value = false
  if (error) {
    showToast(error.message, 'error')
    return
  }
  link.value.status = 'approved'
  link.value.approved_at = new Date().toISOString()
  showToast('បានអនុម័តដោយជោគជ័យ!')
}

function openRejection() {
  rejectionNote.value = ''
  rejectionModal.value = true
}

async function handleReject() {
  if (!rejectionNote.value.trim()) {
    showToast('សូមបញ្ចូលមូលហេតុនៃការបដិសេធ', 'error')
    return
  }
  processing.value = true
  const { error } = await supabase
    .from('report_links')
    .update({
      status: 'rejected',
      rejection_note: rejectionNote.value.trim(),
      approved_at: new Date().toISOString(),
      approved_by: auth.teacherProfile?.id
    })
    .eq('id', reportLinkId)
  processing.value = false
  rejectionModal.value = false
  if (error) {
    showToast(error.message, 'error')
    return
  }
  link.value.status = 'rejected'
  link.value.rejection_note = rejectionNote.value.trim()
  showToast('បានបដិសេធដោយជោគជ័យ!')
}
</script>

<template>
  <div class="admin-preview">
    <div v-if="loading" class="card" style="padding:80px 20px;text-align:center;">
      <div class="spinner"></div>
      <p style="margin-top:12px;color:var(--text-secondary);">កំពុងផ្ទុក...</p>
    </div>

    <div v-else-if="!link" class="card" style="padding:80px 20px;text-align:center;">
      <p style="color:var(--danger-color);font-weight:700;">រកមិនឃើញតំណភ្ជាប់</p>
    </div>

    <template v-else>
      <!-- Header -->
      <div class="card" style="margin-bottom:20px;">
        <div class="card-body">
          <div class="preview-top-bar">
            <button class="btn btn-ghost btn-sm" @click="router.push('/admin/approvals')">
              ← ត្រឡប់ទៅការអនុម័ត
            </button>
            <div class="preview-actions" v-if="link.status === 'pending'">
              <button class="btn btn-sm btn-success" :disabled="processing" @click="handleApprove">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M5 13l4 4L19 7"/></svg>
                អនុម័ត
              </button>
              <button class="btn btn-sm btn-danger" :disabled="processing" @click="openRejection">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M6 18L18 6M6 6l12 12"/></svg>
                បដិសេធ
              </button>
            </div>
          </div>
          <div class="preview-header">
            <div class="preview-info">
              <h1 class="preview-title">{{ link.classes?.class_name }}</h1>
              <p class="preview-subtitle">
                {{ contextLabel() }} · គ្រូ {{ link.teachers?.full_name }}
              </p>
            </div>
            <span class="badge preview-badge"
              :class="link.status === 'approved' ? 'badge-green' : link.status === 'rejected' ? 'badge-red' : 'badge-yellow'">
              {{ link.status === 'approved' ? 'បានអនុម័ត' : link.status === 'rejected' ? 'បដិសេធ' : 'កំពុងរង់ចាំ' }}
            </span>
          </div>
        </div>
      </div>

      <!-- Class Summary -->
      <div class="card" style="margin-bottom:20px;">
        <div class="card-body">
          <div class="summary-grid">
            <div class="summary-item">
              <span class="summary-num">{{ classStats?.total || 0 }}</span>
              <span class="summary-label">សិស្សសរុប</span>
            </div>
            <div class="summary-item">
              <span class="summary-num">{{ classStats?.classAverage ?? '-' }}</span>
              <span class="summary-label">មធ្យមភាគថ្នាក់</span>
            </div>
            <div class="summary-item">
              <span class="summary-num success">{{ classStats?.passed || 0 }}</span>
              <span class="summary-label">ជាប់មធ្យមភាគ</span>
            </div>
            <div class="summary-item">
              <span class="summary-num danger">{{ (classStats?.total || 0) - (classStats?.passed || 0) }}</span>
              <span class="summary-label">ធ្លាក់មធ្យមភាគ</span>
            </div>
            <div class="summary-item">
              <span class="summary-num">{{ classStats?.highest ?? '-' }}</span>
              <span class="summary-label">ខ្ពស់បំផុត</span>
            </div>
            <div class="summary-item">
              <span class="summary-num">{{ classStats?.lowest ?? '-' }}</span>
              <span class="summary-label">ទាបបំផុត</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Student Cards -->
      <div v-if="rankedList.length === 0" class="card" style="padding:40px;text-align:center;color:var(--text-secondary);">
        គ្មានទិន្នន័យសិស្ស
      </div>
      <div v-else class="student-cards">
        <div
          v-for="(student, idx) in rankedList"
          :key="student.id"
          class="card student-card"
          :class="{ 'card-passed': student.average >= 5, 'card-failed': student.average < 5 }"
        >
          <!-- Student Header -->
          <div class="card-header student-card-header">
            <div class="student-card-info">
              <div class="student-card-avatar" :style="{ background: genderColor(student.gender) }">
                {{ (student.full_name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??' }}
              </div>
              <div>
                <div class="student-card-name">{{ idx + 1 }}. {{ student.full_name }}</div>
                <div class="student-card-meta">
                  ចំណាត់ថ្នាក់ទី {{ student.rank }} ·
                  មធ្យមភាគ <strong>{{ student.average }}</strong>
                </div>
              </div>
            </div>
            <span class="grade-chip grade-lg" :class="'chip-' + getGrade(student.average)">
              {{ getGrade(student.average) }}
            </span>
          </div>

          <div class="card-body" style="padding-top:0;">
            <div class="student-card-grid">
              <!-- Scores -->
              <div class="sc-card-section">
                <h4 class="sc-section-title">ពិន្ទុសិក្សា</h4>
                <table class="sc-scores-table">
                  <tbody>
                    <tr v-for="cs in subjects" :key="cs.subject_id">
                      <td class="sc-subj-name">{{ cs.subjects?.subject_name }}</td>
                      <td class="sc-subj-score">{{ getStudentScores(student.id)[cs.subject_id] }}</td>
                      <td class="sc-subj-grade">
                        <span class="grade-chip" :class="'chip-' + getGrade(getStudentScores(student.id)[cs.subject_id])">
                          {{ getGrade(getStudentScores(student.id)[cs.subject_id]) }}
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <!-- Attendance -->
              <div class="sc-card-section">
                <h4 class="sc-section-title">វត្តមាន</h4>
                <div class="sc-att-stats">
                  <div class="sc-att-item">
                    <span class="sc-att-num success">{{ getStudentAttendance(student.id).present }}</span>
                    <span class="sc-att-label">វត្តមាន</span>
                  </div>
                  <div class="sc-att-item">
                    <span class="sc-att-num" style="color:#d97706;">{{ getStudentAttendance(student.id).total - getStudentAttendance(student.id).present }}</span>
                    <span class="sc-att-label">អវត្តមាន</span>
                  </div>
                  <div class="sc-att-item">
                    <span class="sc-att-num" style="color:var(--text-primary);">{{ getStudentAttendance(student.id).total }}</span>
                    <span class="sc-att-label">សរុប</span>
                  </div>
                </div>
                <div class="sc-att-bar-wrapper">
                  <div class="sc-att-bar">
                    <div class="sc-att-fill" :style="{ width: getStudentAttendance(student.id).rate + '%' }"></div>
                  </div>
                  <span class="sc-att-rate" :class="{ 'att-good': getStudentAttendance(student.id).rate >= 80, 'att-warn': getStudentAttendance(student.id).rate < 80 && getStudentAttendance(student.id).rate >= 50, 'att-bad': getStudentAttendance(student.id).rate < 50 }">
                    {{ getStudentAttendance(student.id).rate }}%
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Rejection Modal -->
    <div v-if="rejectionModal" class="modal-overlay" @click.self="rejectionModal = false">
      <div class="modal" style="max-width:420px;">
        <div class="modal-header">
          <span class="modal-title">បដិសេធតំណភ្ជាប់</span>
        </div>
        <div class="modal-body">
          <p style="font-size:13px;color:var(--text-secondary);margin-bottom:12px;">
            សូមបញ្ចូលមូលហេតុនៃការបដិសេធ។
          </p>
          <div class="form-group">
            <label class="form-label">មូលហេតុ</label>
            <textarea class="form-textarea" v-model="rejectionNote" placeholder="បញ្ចូលមូលហេតុ..." rows="3"></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="rejectionModal = false">បោះបង់</button>
          <button class="btn btn-danger" :disabled="processing" @click="handleReject">
            {{ processing ? 'កំពុងដំណើរការ...' : 'បញ្ជាក់ការបដិសេធ' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.admin-preview {
  max-width: 1200px;
  margin: 0 auto;
}

.spinner {
  width: 32px; height: 32px;
  border: 3px solid var(--border-default);
  border-top-color: var(--primary-500);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  margin: 0 auto;
}

@keyframes spin { to { transform: rotate(360deg); } }

.preview-top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.preview-actions {
  display: flex;
  gap: 8px;
}

.preview-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.preview-title {
  font-size: 22px;
  font-weight: 800;
  margin: 0 0 4px;
}

.preview-subtitle {
  font-size: 14px;
  color: var(--text-secondary);
  margin: 0;
}

.preview-badge {
  font-size: 12px;
  padding: 4px 12px;
  white-space: nowrap;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 16px;
}

.summary-item {
  text-align: center;
  padding: 12px 8px;
  background: #f8fafc;
  border-radius: 10px;
}

.summary-num {
  display: block;
  font-size: 22px;
  font-weight: 800;
  margin-bottom: 4px;
}

.summary-num.success { color: #16a34a; }
.summary-num.danger { color: #dc2626; }

.summary-label {
  font-size: 12px;
  color: var(--text-secondary);
}

.student-cards {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.student-card {
  overflow: hidden;
}

.student-card.card-passed {
  border-left: 4px solid #16a34a;
}

.student-card.card-failed {
  border-left: 4px solid #dc2626;
}

.student-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.student-card-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.student-card-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 13px;
  color: white;
  flex-shrink: 0;
}

.student-card-name {
  font-size: 16px;
  font-weight: 700;
}

.student-card-meta {
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.student-card-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.sc-card-section {
  min-width: 0;
}

.sc-section-title {
  font-size: 12px;
  font-weight: 700;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin: 0 0 8px;
}

.sc-scores-table {
  width: 100%;
  border-collapse: collapse;
}

.sc-scores-table td {
  padding: 5px 0;
  font-size: 13px;
  border-bottom: 1px solid #f1f5f9;
}

.sc-scores-table tr:last-child td {
  border-bottom: none;
}

.sc-subj-name {
  color: var(--text-primary);
}

.sc-subj-score {
  text-align: center;
  font-weight: 700;
  width: 40px;
}

.sc-subj-grade {
  text-align: right;
  width: 40px;
}

.sc-att-stats {
  display: flex;
  gap: 16px;
  margin-bottom: 10px;
}

.sc-att-item {
  text-align: center;
}

.sc-att-num {
  display: block;
  font-size: 20px;
  font-weight: 800;
}

.sc-att-num.success { color: #16a34a; }

.sc-att-label {
  font-size: 11px;
  color: var(--text-secondary);
}

.sc-att-bar-wrapper {
  display: flex;
  align-items: center;
  gap: 10px;
}

.sc-att-bar {
  flex: 1;
  height: 8px;
  background: #e2e8f0;
  border-radius: 4px;
  overflow: hidden;
}

.sc-att-fill {
  height: 100%;
  background: #16a34a;
  border-radius: 4px;
  transition: width 0.3s;
}

.sc-att-rate {
  font-size: 14px;
  font-weight: 800;
  white-space: nowrap;
}

.grade-chip {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 800;
}

.grade-lg {
  padding: 4px 14px;
  font-size: 16px;
  border-radius: 8px;
}

.chip-A { background: #dcfce7; color: #166534; }
.chip-B { background: #dbeafe; color: #1e40af; }
.chip-C { background: #fef9c3; color: #854d0e; }
.chip-D { background: #ffedd5; color: #9a3412; }
.chip-E { background: #f1f5f9; color: #475569; }
.chip-F { background: #fee2e2; color: #991b1b; }

.att-good { color: #16a34a; }
.att-warn { color: #d97706; }
.att-bad { color: #dc2626; }

.btn-success {
  background: #16a34a; color: white; border: none;
  padding: 6px 14px; border-radius: 6px;
  font-size: 12px; font-weight: 700;
  cursor: pointer; display: inline-flex; align-items: center; gap: 4px;
}

.btn-success:hover { background: #15803d; }
.btn-success:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-danger {
  background: #dc2626; color: white; border: none;
  padding: 6px 14px; border-radius: 6px;
  font-size: 12px; font-weight: 700;
  cursor: pointer; display: inline-flex; align-items: center; gap: 4px;
}

.btn-danger:hover { background: #b91c1c; }
.btn-danger:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
