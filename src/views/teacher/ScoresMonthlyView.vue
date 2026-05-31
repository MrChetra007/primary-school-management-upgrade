<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { computeMonthlyAverage, computeRank } from '@/utils/scoreCalculator'
import { generateMonthlyScorePDF } from '@/utils/exportPdf'
import { useRouter } from 'vue-router'
import { CheckIcon, XCircleIcon, ArrowDownTrayIcon, BuildingOfficeIcon } from '@heroicons/vue/24/outline'

const router = useRouter()
const auth = useAuthStore()
const students = ref([])
const subjects = ref([])
const classInfo = ref(null)
const loading = ref(true)
const saving = ref(false)
const toast = ref(null)
const pinnedRow = ref(null)
const pinnedCol = ref(null)

function togglePin(id) {
  pinnedRow.value = pinnedRow.value === id ? null : id
}
function togglePinCol(id) {
  pinnedCol.value = pinnedCol.value === id ? null : id
}

const selectedMonth = ref(new Date().getMonth() + 1)
const scores = ref([]) // Raw scores from DB
const scoreMatrix = ref([]) // Transformed data for the table

const months = [
  { id: 1, name: 'មករា' }, { id: 2, name: 'កុម្ភៈ' }, { id: 3, name: 'មីនា' },
  { id: 4, name: 'មេសា' }, { id: 5, name: 'ឧសភា' }, { id: 6, name: 'មិថុនា' },
  { id: 7, name: 'កក្កដា' }, { id: 8, name: 'សីហា' }, { id: 9, name: 'កញ្ញា' },
  { id: 10, name: 'តុលា' }, { id: 11, name: 'វិច្ឆិកា' }, { id: 12, name: 'ធ្នូ' }
]

onMounted(async () => {
  if (auth.teacherProfile) {
    await loadData()
  } else {
    setTimeout(async () => {
      if (auth.teacherProfile) await loadData()
      else loading.value = false
    }, 1000)
  }
})

async function loadData() {
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
    
    // 1. Get Subjects
    const { data: subData } = await supabase
      .from('class_subjects')
      .select('subjects(*)')
      .eq('class_id', classData.id)
    subjects.value = subData?.map(s => s.subjects) || []

    // 2. Get Students
    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name')
      .eq('class_id', classData.id)
      .order('full_name')
    students.value = stuData || []
    
    await fetchScores()
  }
  loading.value = false
}

async function fetchScores() {
  if (!classInfo.value || students.value.length === 0) return
  
  const { data } = await supabase
    .from('scores')
    .select('*')
    .in('student_id', students.value.map(s => s.id))
    .eq('academic_year_id', classInfo.value.academic_year_id)
    .eq('month', selectedMonth.value)
    .eq('score_type', 'monthly')
  
  scores.value = data || []
  buildMatrix()
}

function buildMatrix() {
  const matrix = students.value.map(student => {
    const studentScores = {}
    subjects.value.forEach(sub => {
      const match = scores.value.find(s => s.student_id === student.id && s.subject_id === sub.id)
      studentScores[sub.id] = {
        score: match?.score ?? '',
        id: match?.id ?? null
      }
    })

    return {
      student_id: student.id,
      full_name: student.full_name,
      subjects: studentScores,
      average: 0,
      rank: 0
    }
  })

  scoreMatrix.value = matrix
  calculateAll()
}

function calculateRowAverage(row) {
  const scoresArray = Object.values(row.subjects)
    .filter(s => s.score !== '')
    .map(s => ({ score: s.score }))
  row.average = computeMonthlyAverage(scoresArray)
}

function calculateAll() {
  scoreMatrix.value.forEach(calculateRowAverage)
  const ranked = computeRank(scoreMatrix.value)
  scoreMatrix.value.forEach(row => {
    const match = ranked.find(r => r.student_id === row.student_id)
    row.rank = match?.rank ?? 0
  })
}

function onScoreInput(studentId) {
  const row = scoreMatrix.value.find(r => r.student_id === studentId)
  if (row) calculateRowAverage(row)
}

async function saveAll() {
  saving.value = true
  const toUpsert = []

  scoreMatrix.value.forEach(row => {
    Object.entries(row.subjects).forEach(([subId, data]) => {
      if (data.score === '') return
      
      const payload = {
        student_id: row.student_id,
        subject_id: subId,
        academic_year_id: classInfo.value.academic_year_id,
        score_type: 'monthly',
        month: selectedMonth.value,
        score: Number(data.score),
        school_id: auth.schoolId
      }
      if (data.id) payload.id = data.id
      toUpsert.push(payload)
    })
  })

  if (toUpsert.length > 0) {
    const { data: saved, error } = await supabase
      .from('scores')
      .upsert(toUpsert)
      .select()
    if (error) {
      showToast(error.message, 'error')
    } else {
      saved?.forEach(s => {
        const existing = scores.value.find(x => x.id === s.id)
        if (existing) Object.assign(existing, s)
        else scores.value.push(s)
      })
      buildMatrix()
      showToast('រក្សាទុកពិន្ទុទាំងអស់បានជោគជ័យ!', 'success')
    }
  }

  saving.value = false
}

const printArea = ref(null)
async function handleExport() {
  if (!printArea.value) return
  const metadata = {
    schoolName: 'សាលាបឋមសិក្សា',
    className: classInfo.value?.class_name,
    month: months.find(m => m.id === selectedMonth.value)?.name,
    year: classInfo.value?.academic_years?.year_name
  }
  try {
    await generateMonthlyScorePDF(printArea.value, metadata)
    showToast('បង្កើត PDF បានជោគជ័យ!', 'success')
  } catch (e) {
    showToast('មិនអាចបង្កើត PDF បានទេ', 'error')
  }
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

watch(selectedMonth, fetchScores)
</script>

<template>
  <div class="scores-monthly-view">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header no-print">
      <div>
        <h1 class="page-title">បញ្ចូលពិន្ទុប្រចាំខែ</h1>
        <p class="page-subtitle" v-if="classInfo">
          គ្រប់គ្រងថ្នាក់ <strong>{{ classInfo.class_name }}</strong> ({{ classInfo.academic_years?.year_name }})
        </p>
      </div>
      <div style="display:flex; gap:12px;">
        <button class="btn btn-secondary" @click="router.push(`/teacher/scores/ranking?mode=monthly&month=${selectedMonth}`)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" class="mr-2">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
          </svg>
          មើលចំណាត់ថ្នាក់
        </button>
        <button class="btn btn-primary" @click="saveAll" :disabled="saving || loading">
          <ArrowDownTrayIcon class="w-4 h-4" /> 
          {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុកទាំងអស់' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:400px; border-radius:12px;"></div>
    </div>

    <div v-else-if="!classInfo" class="empty-state">
      <BuildingOfficeIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">មិនទាន់មានថ្នាក់ត្រូវបានចាត់តាំង</p>
    </div>

    <div v-else>
      <!-- Filters -->
      <div class="card no-print" style="margin-bottom:20px;">
        <div class="card-body">
          <div class="form-group" style="width:240px;">
            <label class="form-label">ជ្រើសរើសខែ</label>
            <select class="form-select" v-model="selectedMonth">
              <option v-for="m in months" :key="m.id" :value="m.id">{{ m.name }}</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Score Matrix -->
      <div class="card" ref="printArea">
        <div class="print-header only-print">
          <h2>បញ្ជីពិន្ទុប្រចាំខែ</h2>
          <div style="display:flex; justify-content:space-between; margin-top:10px;">
            <span>ថ្នាក់៖ {{ classInfo.class_name }}</span>
            <span>ខែ៖ {{ months.find(m => m.id === selectedMonth)?.name }}</span>
            <span>ឆ្នាំសិក្សា៖ {{ classInfo.academic_years?.year_name }}</span>
          </div>
        </div>

        <div class="table-wrapper horizontal-scroll">
          <table class="matrix-table">
            <thead>
              <tr>
                <th class="hide-mobile" style="width:50px;">ល.រ</th>
                <th style="min-width:160px; text-align:left;">ឈ្មោះសិស្ស</th>
                <th v-for="sub in subjects" :key="sub.id" class="sub-col"
                  @click="togglePinCol(sub.id)"
                  :class="{ 'pinned-col': pinnedCol === sub.id }">
                  <div class="vertical-text">{{ sub.subject_name }}</div>
                </th>
                <th class="summary-col">មធ្យមភាគ</th>
                <th class="summary-col">លំដាប់</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, idx) in scoreMatrix" :key="row.student_id"
                @click="togglePin(row.student_id)"
                :class="{ pinned: pinnedRow === row.student_id }">
                <td class="hide-mobile" style="text-align:center;">{{ idx + 1 }}</td>
                <td style="font-weight:700; text-align:left;">{{ row.full_name }}</td>
                <td v-for="sub in subjects" :key="sub.id"
                  :class="{ 'pinned-col': pinnedCol === sub.id }">
                  <input 
                    type="number" 
                    class="score-input"
                    v-model="row.subjects[sub.id].score"
                    min="0" 
                    max="100"
                    @input="onScoreInput(row.student_id)"
                    @click.stop
                  />
                </td>
                <td class="avg-cell" :class="{ 'text-danger': row.average < 50 }">{{ row.average }}</td>
                <td class="rank-cell">{{ row.rank }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="print-footer only-print" style="margin-top:40px; display:flex; justify-content:flex-end; padding:20px;">
          <div style="text-align:center;">
            <p>ថ្ងៃទី ........ ខែ ........ ឆ្នាំ២០........</p>
            <p style="margin-top:10px; font-weight:700;">ហត្ថលេខាគ្រូបន្ទុកថ្នាក់</p>
            <div style="height:60px;"></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.scores-monthly-view {
  max-width: 1200px;
  margin: 0 auto;
}

.table-wrapper {
  overflow-x: auto;
  overflow-y: auto;
  max-height: 70vh;
  -webkit-overflow-scrolling: touch;
  position: relative;
}

.matrix-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  background: white;
}

.matrix-table th,
.matrix-table td {
  border-bottom: 1px solid var(--border-default);
  border-right: 1px solid var(--border-default);
  padding: 8px;
  text-align: center;
}

.matrix-table thead tr th:first-child,
.matrix-table tbody tr td:first-child {
  border-left: 1px solid var(--border-default);
}
.matrix-table thead tr:first-child th {
  border-top: 1px solid var(--border-default);
}

.matrix-table th {
  background: #f8fafc;
  font-size: 12px;
  font-weight: 700;
  color: #64748b;
}

/* Freeze header row — scroll down */
.matrix-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
}

/* Freeze column 1 (ល.រ) — scroll right */
.matrix-table th:nth-child(1),
.matrix-table td:nth-child(1) {
  position: sticky;
  left: 0;
  z-index: 3;
  width: 50px;
  background: #f8fafc;
}

/* Freeze column 2 (student name) — scroll right */
.matrix-table th:nth-child(2),
.matrix-table td:nth-child(2) {
  position: sticky;
  left: 50px;
  z-index: 3;
  min-width: 180px;
  text-align: left;
  background: white;
  box-shadow: 2px 0 6px -2px rgba(0, 0, 0, 0.08);
}

/* Corner cells — sticky in both directions, highest z-index */
.matrix-table thead th:nth-child(1),
.matrix-table thead th:nth-child(2) {
  z-index: 4;
  background: #f8fafc;
}

.matrix-table tbody tr:hover td:nth-child(1),
.matrix-table tbody tr:hover td:nth-child(2) {
  background: #f1f5f9;
}

.sub-col {
  width: 50px;
  height: 100px;
  vertical-align: bottom;
  padding-bottom: 12px !important;
}

.vertical-text {
  writing-mode: vertical-rl;
  transform: rotate(180deg);
  white-space: nowrap;
  display: inline-block;
}

.score-input {
  width: 44px;
  padding: 4px;
  border: 1px solid #e2e8f0;
  text-align: center;
  font-weight: 600;
  border-radius: 4px;
  background: #f8fafc;
  transition: all 0.2s;
}

.score-input:focus {
  outline: none;
  border-color: var(--primary-color);
  background: #f1f5f9;
}

.score-input::-webkit-inner-spin-button,
.score-input::-webkit-outer-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.avg-cell {
  font-weight: 800;
  background: #f1f5f9;
  color: #1e293b;
}

.rank-cell {
  font-weight: 800;
  color: var(--primary-color);
  background: #eff6ff;
}

.text-danger { color: #ef4444; }

/* ── Pinned row ── */
tr.pinned td,
tr.pinned td.avg-cell,
tr.pinned td.rank-cell {
  background: #dbeafe !important;
}
tr.pinned td:nth-child(2) {
  background: #dbeafe !important;
}

/* ── Pinned column ── */
th.pinned-col,
td.pinned-col {
  background: #fef3c7 !important;
}
th.pinned-col .vertical-text {
  color: #b45309;
}

/* ── Mobile responsive ── */
@media (max-width: 768px) {
  .hide-mobile { display: none; }

  .matrix-table th:nth-child(2),
  .matrix-table td:nth-child(2) {
    left: 0;
  }

  .matrix-table th,
  .matrix-table td {
    padding: 6px 3px;
    font-size: 11px;
  }

  .score-input {
    width: 30px;
    padding: 2px;
    font-size: 11px;
  }

  .sub-col {
    width: 32px;
    min-width: 32px;
    max-width: 32px;
    height: 80px;
    padding-bottom: 8px !important;
  }

  .vertical-text {
    font-size: 9px;
  }

  .summary-col {
    width: 44px;
    min-width: 44px;
    font-size: 10px;
  }

  .matrix-table th:nth-child(1),
  .matrix-table td:nth-child(1) {
    width: 0;
    min-width: 0;
    padding: 0;
  }
}

.only-print { display: none; }

@media print {
  .no-print { display: none !important; }
  .only-print { display: block !important; }
  .matrix-table { font-size: 10px; }
  .score-input { border: none; background: transparent; }
  .card { box-shadow: none; border: none; }
  .print-header { text-align: center; margin-bottom: 20px; }
  .print-header h2 { font-size: 18px; margin-bottom: 5px; }

  .table-wrapper { max-height: none; overflow: visible; }
  .matrix-table th,
  .matrix-table td {
    position: static !important;
    box-shadow: none !important;
  }
}
</style>
