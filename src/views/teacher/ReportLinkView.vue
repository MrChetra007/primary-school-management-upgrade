<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useSchoolStore } from '@/stores/school'
import { useAcademicYearStore } from '@/stores/academicYear'
import { supabase } from '@/lib/supabase'
import { computeMonthlyAverage, computeRank } from '@/utils/scoreCalculator'
import {
  CheckCircleIcon, XCircleIcon, DocumentDuplicateIcon,
  ChevronLeftIcon, PaperAirplaneIcon, PencilSquareIcon,
  LinkIcon, LockClosedIcon
} from '@heroicons/vue/24/outline'
import PhrasePicker from '@/components/report/PhrasePicker.vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const auth = useAuthStore()
const schoolStore = useSchoolStore()
const academicYearStore = useAcademicYearStore()

const loading = ref(true)
const classInfo = ref(null)
const students = ref([])
const subjects = ref([])
const allScores = ref([])
const attendancesMap = ref({})
const currentLink = ref(null)
const toast = ref(null)
const processing = ref(false)
const draftMessages = ref({})
const savingStudentId = ref(null)
const editingStudentId = ref(null)

const mode = ref('monthly')
const selectedMonth = ref(new Date().getMonth() + 1)
const selectedSemester = ref(1)

const months = [
  { id: 1, name: 'មករា' }, { id: 2, name: 'កុម្ភៈ' }, { id: 3, name: 'មីនា' },
  { id: 4, name: 'មេសា' }, { id: 5, name: 'ឧសភា' }, { id: 6, name: 'មិថុនា' },
  { id: 7, name: 'កក្កដា' }, { id: 8, name: 'សីហា' }, { id: 9, name: 'កញ្ញា' },
  { id: 10, name: 'តុលា' }, { id: 11, name: 'វិច្ឆិកា' }, { id: 12, name: 'ធ្នូ' }
]

function contextLabel(l) {
  if (!l) return ''
  if (l.score_type === 'monthly') return `ប្រចាំខែ${months[l.month - 1]?.name || ''}`
  return `ឆមាសទី${l.semester || 1}`
}

function getGrade(score) {
  if (score >= 9) return 'A'
  if (score >= 8) return 'B'
  if (score >= 7) return 'C'
  if (score >= 6) return 'D'
  if (score >= 5) return 'E'
  return 'F'
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

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
    await fetchCurrentLink()
    await fetchData()
  }
  loading.value = false
}

async function fetchCurrentLink() {
  if (!classInfo.value) { currentLink.value = null; return }

  const month = mode.value === 'monthly' ? selectedMonth.value : null
  const semester = mode.value === 'semester' ? selectedSemester.value : null

  let query = supabase
    .from('report_links')
    .select('*')
    .eq('class_id', classInfo.value.id)
    .eq('academic_year_id', classInfo.value.academic_year_id)
    .eq('score_type', mode.value)
    .eq('created_by', auth.teacherProfile.id)

  if (month !== null) {
    query = query.eq('month', month)
  } else {
    query = query.is('month', null)
  }

  if (semester !== null) {
    query = query.eq('semester', semester)
  } else {
    query = query.is('semester', null)
  }

  const { data } = await query.maybeSingle()
  currentLink.value = data || null
}

async function fetchData() {
  if (!classInfo.value) return

  const { data: stuData } = await supabase
    .from('students')
    .select('id, full_name, gender')
    .eq('class_id', classInfo.value.id)
    .eq('is_graduated', false)
    .order('full_name')

  students.value = stuData || []
  const studentIds = (stuData || []).map(s => s.id)
  if (studentIds.length === 0) return

  const { data: csData } = await supabase
    .from('class_subjects')
    .select('id, subject_id, subjects(subject_name)')
    .eq('class_id', classInfo.value.id)

  subjects.value = csData || []

  const scoreQuery = supabase
    .from('scores')
    .select('*, subjects(subject_name)')
    .in('student_id', studentIds)
    .eq('academic_year_id', classInfo.value.academic_year_id)
    .eq('score_type', mode.value)

  if (mode.value === 'monthly') {
    scoreQuery.eq('month', selectedMonth.value)
  }

  const { data: scoreData } = await scoreQuery
  allScores.value = scoreData || []

  const now = new Date()
  const year = now.getFullYear()
  const month = mode.value === 'monthly' ? selectedMonth.value : now.getMonth() + 1
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
}

async function onPeriodChange() {
  await fetchCurrentLink()
  await fetchData()
}

watch([mode, selectedMonth, selectedSemester], onPeriodChange)

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

function handlePhrasePick(phrase) {
  if (!editingStudentId.value) return
  const current = draftMessages.value[editingStudentId.value] || ''
  draftMessages.value[editingStudentId.value] = current ? `${current} ${phrase}` : phrase
}

async function saveTeacherMessage(studentId) {
  const text = (draftMessages.value[studentId] || '').trim()
  if (!text || !currentLink.value) return
  savingStudentId.value = studentId
  try {
    const { error } = await supabase
      .from('report_messages')
      .upsert({
        school_id: schoolStore.schoolId,
        report_link_id: currentLink.value.id,
        student_id: studentId,
        teacher_text: text
      }, { onConflict: 'report_link_id,student_id' })

    if (error) throw error

    showToast('សារត្រូវបានរក្សាទុក')
    editingStudentId.value = null
    await loadExistingMessages()
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    savingStudentId.value = null
  }
}

const existingMessages = ref({})

async function loadExistingMessages() {
  if (!currentLink.value) { existingMessages.value = {}; return }
  const { data } = await supabase
    .from('report_messages')
    .select('student_id, teacher_text')
    .eq('report_link_id', currentLink.value.id)

  const map = {}
  for (const m of data || []) {
    map[m.student_id] = m.teacher_text
  }
  existingMessages.value = map
}

function getTeacherMsg(studentId) {
  return existingMessages.value[studentId]
}

function startEdit(studentId) {
  editingStudentId.value = studentId
  draftMessages.value[studentId] = getTeacherMsg(studentId) || ''
}

function cancelEdit(studentId) {
  if (editingStudentId.value === studentId) {
    editingStudentId.value = null
    delete draftMessages.value[studentId]
  }
}

async function handleSendForApproval() {
  if (!classInfo.value) return
  processing.value = true

  try {
    const month = mode.value === 'monthly' ? selectedMonth.value : null
    const semester = mode.value === 'semester' ? selectedSemester.value : null

    await fetchCurrentLink()

    if (currentLink.value && currentLink.value.status !== 'rejected') {
      showToast('តំណភ្ជាប់សម្រាប់ខែនេះមានរួចហើយ', 'info')
      return
    }

    if (currentLink.value && currentLink.value.status === 'rejected') {
      const { error } = await supabase
        .from('report_links')
        .update({ status: 'pending', rejection_note: null, approved_at: null, approved_by: null })
        .eq('id', currentLink.value.id)
      if (error) throw error
      currentLink.value.status = 'pending'
      currentLink.value.rejection_note = null
      showToast('បានស្នើសុំអនុម័តឡើងវិញដោយជោគជ័យ!')
      return
    }

    if (!currentLink.value) {
      const { data: inserted, error } = await supabase
        .from('report_links')
        .insert({
          school_id: schoolStore.schoolId,
          class_id: classInfo.value.id,
          academic_year_id: classInfo.value.academic_year_id,
          created_by: auth.teacherProfile.id,
          score_type: mode.value,
          month,
          semester
        })
        .select('id, status')
        .single()

      if (error) throw error
      currentLink.value = inserted

      const pendingMessages = []
      for (const student of students.value) {
        const text = (draftMessages.value[student.id] || '').trim()
        if (text) {
          pendingMessages.push({
            school_id: schoolStore.schoolId,
            report_link_id: inserted.id,
            student_id: student.id,
            teacher_text: text
          })
        }
      }

      if (pendingMessages.length > 0) {
        const { error: msgError } = await supabase
          .from('report_messages')
          .upsert(pendingMessages, { onConflict: 'report_link_id,student_id' })

        if (msgError) throw msgError
      }

      await loadExistingMessages()
      showToast('បានផ្ញើសម្រាប់ការអនុម័តដោយជោគជ័យ!')
    }
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    processing.value = false
  }
}

async function handleCopyLink() {
  if (!currentLink.value || currentLink.value.status !== 'approved') return
  const link = `${window.location.origin}/parent/report/${currentLink.value.id}`
  try {
    await navigator.clipboard.writeText(link)
    showToast('បានចម្លងតំណភ្ជាប់!')
  } catch {
    showToast('មិនអាចចម្លងតំណភ្ជាប់បានទេ', 'error')
  }
}
</script>

<template>
  <div class="report-link-view">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">{{ toast.msg }}</div>
    </div>

    <div class="page-header">
      <div style="display:flex; align-items:center; gap:16px;">
        <button class="btn btn-ghost btn-sm btn-icon" @click="router.push('/teacher/scores/ranking')">
          <ChevronLeftIcon class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">តំណភ្ជាប់របាយការណ៍មាតាបិតា</h1>
          <p class="page-subtitle" v-if="classInfo">
            ថ្នាក់ <strong>{{ classInfo.class_name }}</strong> — {{ classInfo.academic_years?.year_name }}
          </p>
        </div>
      </div>
    </div>

    <div v-if="loading" class="card" style="padding:80px 20px;text-align:center;">
      <div class="spinner"></div>
      <p style="margin-top:12px;color:var(--text-secondary);">កំពុងផ្ទុក...</p>
    </div>

    <template v-else-if="classInfo">
      <!-- Period Selector -->
      <div class="card filters-card" style="margin-bottom:20px;">
        <div class="card-body" style="display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap;">
          <div class="form-group" style="width:140px;">
            <label class="form-label">ប្រភេទ</label>
            <select class="form-select" v-model="mode">
              <option value="monthly">ប្រចាំខែ</option>
              <option value="semester">ឆមាស</option>
            </select>
          </div>
          <div class="form-group" style="width:140px;" v-if="mode === 'monthly'">
            <label class="form-label">ខែ</label>
            <select class="form-select" v-model="selectedMonth">
              <option v-for="m in months" :key="m.id" :value="m.id">{{ m.name }}</option>
            </select>
          </div>
          <div class="form-group" style="width:140px;" v-else>
            <label class="form-label">ឆមាស</label>
            <select class="form-select" v-model="selectedSemester">
              <option :value="1">ឆមាសទី ១</option>
              <option :value="2">ឆមាសទី ២</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Link Status + Actions -->
      <div class="card" style="margin-bottom:20px;">
        <div class="card-body">
          <div class="link-actions-row">
            <div class="link-status-area">
              <LinkIcon class="w-5 h-5" style="color:var(--primary-500);" />
              <span v-if="currentLink" class="link-status-badge" :class="'ls-' + currentLink.status">
                <span v-if="currentLink.status === 'approved'" class="ls-dot" style="background:#16a34a;"></span>
                <span v-else-if="currentLink.status === 'pending'" class="ls-dot" style="background:#f59e0b;"></span>
                <span v-else class="ls-dot" style="background:#dc2626;"></span>
                {{ currentLink.status === 'approved' ? 'បានអនុម័ត' : currentLink.status === 'pending' ? 'កំពុងរង់ចាំ' : 'ត្រូវបានបដិសេធ' }}
              </span>
              <span v-else class="link-status-badge ls-none">
                <span class="ls-dot" style="background:#94a3b8;"></span>
                មិនទាន់មាន
              </span>
              <span v-if="currentLink" style="font-size:13px;color:var(--text-secondary);">
                {{ contextLabel(currentLink) }}
              </span>
            </div>
            <div class="link-actions-buttons">
              <button
                class="btn btn-primary"
                :disabled="processing"
                @click="handleSendForApproval"
                v-if="!currentLink || currentLink.status === 'rejected'"
              >
                <PaperAirplaneIcon class="w-4 h-4" />
                {{ currentLink?.status === 'rejected' ? 'ស្នើសុំឡើងវិញ' : 'ផ្ញើសម្រាប់ការអនុម័ត' }}
              </button>
              <button
                v-if="currentLink?.status === 'approved'"
                class="btn btn-success"
                @click="handleCopyLink"
              >
                <DocumentDuplicateIcon class="w-4 h-4" />
                ចម្លងតំណ
              </button>
              <button
                v-if="currentLink && currentLink.status !== 'approved'"
                class="btn btn-ghost"
                disabled
                style="opacity:0.5;"
              >
                <LockClosedIcon class="w-4 h-4" />
                ចម្លងតំណ
              </button>
            </div>
          </div>
          <div v-if="currentLink?.status === 'rejected' && currentLink?.rejection_note" class="rejection-banner">
            <XCircleIcon class="w-4 h-4" />
            <span>មូលហេតុ៖ {{ currentLink.rejection_note }}</span>
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
              <div class="student-card-avatar" :style="{ background: student.gender === 'female' ? '#ec4899' : '#3b82f6' }">
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

                <!-- Teacher Note -->
                <div class="teacher-note-section">
                  <div class="teacher-note-header">
                    <PencilSquareIcon class="w-3.5 h-3.5" />
                    <span>សារទៅកាន់មាតាបិតា</span>
                  </div>
                  <div v-if="editingStudentId === student.id" class="teacher-note-edit">
                    <textarea
                      v-model="draftMessages[student.id]"
                      class="form-control note-textarea"
                      rows="3"
                      placeholder="សរសេរសារទៅកាន់មាតាបិតាសិស្ស..."
                    ></textarea>
                    <PhrasePicker @pick="handlePhrasePick" />
                    <div class="note-actions">
                      <button
                        class="btn btn-sm btn-primary"
                        :disabled="!(draftMessages[student.id] || '').trim() || savingStudentId === student.id"
                        @click="saveTeacherMessage(student.id)"
                      >
                        <PaperAirplaneIcon class="w-3.5 h-3.5" />
                        រក្សាទុក
                      </button>
                      <button class="btn btn-sm btn-ghost" @click="cancelEdit(student.id)">
                        បោះបង់
                      </button>
                    </div>
                  </div>
                  <div v-else class="teacher-note-display">
                    <p v-if="getTeacherMsg(student.id)" class="note-text">{{ getTeacherMsg(student.id) }}</p>
                    <p v-else class="note-empty">—</p>
                    <button class="btn btn-xs note-edit-btn" @click="startEdit(student.id)">
                      <PencilSquareIcon class="w-3 h-3" />
                      {{ getTeacherMsg(student.id) ? 'កែសម្រួល' : 'សរសេរសារ' }}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <div v-else class="card" style="padding:80px 20px;text-align:center;">
      <p style="color:var(--text-secondary);font-weight:700;">រកមិនឃើញថ្នាក់រៀន</p>
    </div>
  </div>
</template>

<style scoped>
.report-link-view {
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

.link-actions-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.link-status-area {
  display: flex;
  align-items: center;
  gap: 10px;
}

.link-actions-buttons {
  display: flex;
  gap: 8px;
}

.link-status-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 700;
}

.ls-approved { background: #f0fdf4; color: #166534; }
.ls-pending { background: #fffbeb; color: #92400e; }
.ls-rejected { background: #fef2f2; color: #991b1b; }
.ls-none { background: #f1f5f9; color: #475569; }

.ls-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}

.rejection-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
  padding: 10px 14px;
  background: #fef2f2;
  border-radius: 8px;
  font-size: 13px;
  color: #991b1b;
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

.sc-subj-name { color: var(--text-primary); }

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

.sc-att-item { text-align: center; }

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

.teacher-note-section {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 2px dashed #e2e8f0;
}

.teacher-note-header {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 700;
  color: var(--primary-600, #1d4ed8);
  margin-bottom: 10px;
}

.teacher-note-display {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.note-textarea {
  font-size: 13px !important;
  resize: vertical;
  min-height: 70px;
  border: 2px solid #c7d2fe !important;
  background: #eef2ff !important;
  transition: border-color 0.2s;
}

.note-textarea:focus {
  border-color: #6366f1 !important;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
}

.note-actions {
  display: flex;
  gap: 8px;
  margin-top: 10px;
}

.note-text {
  font-size: 13px;
  color: var(--text-primary);
  white-space: pre-wrap;
  line-height: 1.5;
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  padding: 10px 12px;
  border-radius: 8px;
  width: 100%;
  margin: 0 0 6px;
}

.note-empty {
  font-size: 13px;
  color: var(--text-muted);
  margin: 0 0 6px;
  font-style: italic;
}

.note-edit-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 600;
  color: var(--primary-600, #1d4ed8);
  background: #eef2ff;
  border: 1px solid #c7d2fe;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s;
}

.note-edit-btn:hover {
  background: #dde3fc;
  border-color: #a5b4fc;
}

.btn-success {
  background: #16a34a; color: white; border: none;
  padding: 6px 14px; border-radius: 6px;
  font-size: 12px; font-weight: 700;
  cursor: pointer; display: inline-flex; align-items: center; gap: 4px;
}

.btn-success:hover { background: #15803d; }
.btn-success:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
