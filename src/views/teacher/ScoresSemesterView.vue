<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { computeMonthlyAverage, computeSemesterAverage, computeRank } from '@/utils/scoreCalculator'
import { generateSemesterScorePDF } from '@/utils/exportPdf'
import { CheckIcon, XCircleIcon, ArrowDownTrayIcon, BuildingOfficeIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const students = ref([])
const subjects = ref([])
const classInfo = ref(null)
const loading = ref(true)
const saving = ref(false)
const toast = ref(null)

const selectedSemester = ref(1)
const examScores = ref([]) // Raw semester exam scores from DB
const monthlyScores = ref([]) // Monthly scores for the semester months
const scoreMatrix = ref([]) // Transformed data

const semesterMonths = computed(() => {
  return selectedSemester.value === 1 ? [1, 2, 3] : [4, 5, 6]
})

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
    
    await fetchAllScores()
  }
  loading.value = false
}

async function fetchAllScores() {
  if (!classInfo.value || students.value.length === 0) return
  const studentIds = students.value.map(s => s.id)

  // 1. Fetch Semester Exam Scores
  const { data: examData } = await supabase
    .from('scores')
    .select('*')
    .in('student_id', studentIds)
    .eq('semester', selectedSemester.value)
    .eq('score_type', 'semester')
  
  examScores.value = examData || []

  // 2. Fetch Monthly Scores
  const { data: mData } = await supabase
    .from('scores')
    .select('*')
    .in('student_id', studentIds)
    .in('month', semesterMonths.value)
    .eq('score_type', 'monthly')
  
  monthlyScores.value = mData || []
  buildMatrix()
}

function buildMatrix() {
  const matrix = students.value.map(student => {
    const examSubMap = {}
    subjects.value.forEach(sub => {
      const match = examScores.value.find(s => s.student_id === student.id && s.subject_id === sub.id)
      examSubMap[sub.id] = {
        score: match?.score ?? '',
        id: match?.id ?? null
      }
    })

    const mAvgs = semesterMonths.value.map(m => {
      const monthScores = monthlyScores.value
        .filter(s => s.student_id === student.id && s.month === m)
        .map(s => ({ score: s.score }))
      return computeMonthlyAverage(monthScores)
    })

    return {
      student_id: student.id,
      full_name: student.full_name,
      examSubjects: examSubMap,
      monthlyAverages: mAvgs,
      examAverage: 0,
      monthlyTotalAverage: 0,
      finalAverage: 0,
      rank: 0
    }
  })

  scoreMatrix.value = matrix
  calculateAll()
}

function calculateAll() {
  scoreMatrix.value.forEach(row => {
    const examArray = Object.values(row.examSubjects)
      .filter(s => s.score !== '')
      .map(s => ({ score: s.score }))
    row.examAverage = computeMonthlyAverage(examArray)

    const validMonths = row.monthlyAverages.filter(m => m > 0)
    row.monthlyTotalAverage = validMonths.length > 0 
      ? Number((validMonths.reduce((a, b) => a + b, 0) / validMonths.length).toFixed(2))
      : 0

    row.finalAverage = computeSemesterAverage(row.monthlyAverages, row.examAverage)
  })

  const ranked = computeRank(scoreMatrix.value.map(r => ({ ...r, average: r.finalAverage })))
  
  scoreMatrix.value.forEach(row => {
    const match = ranked.find(r => r.student_id === row.student_id)
    row.rank = match?.rank ?? 0
  })

  scoreMatrix.value.sort((a, b) => a.full_name.localeCompare(b.full_name))
}

async function saveAll() {
  saving.value = true
  const toUpsert = []

  scoreMatrix.value.forEach(row => {
    Object.entries(row.examSubjects).forEach(([subId, data]) => {
      if (data.score === '') return
      
      const payload = {
        student_id: row.student_id,
        subject_id: subId,
        academic_year_id: classInfo.value.academic_year_id,
        score_type: 'semester',
        semester: selectedSemester.value,
        score: Number(data.score)
      }
      if (data.id) payload.id = data.id
      toUpsert.push(payload)
    })
  })

  if (toUpsert.length > 0) {
    const { error } = await supabase.from('scores').upsert(toUpsert)
    if (error) showToast(error.message, 'error')
    else showToast('រក្សាទុកពិន្ទុឆមាសបានជោគជ័យ!', 'success')
  }

  saving.value = false
  await fetchAllScores()
}

const printArea = ref(null)
async function handleExport() {
  if (!printArea.value) return
  const metadata = {
    schoolName: 'សាលាបឋមសិក្សា',
    className: classInfo.value?.class_name,
    semester: selectedSemester.value,
    year: classInfo.value?.academic_years?.year_name
  }
  try {
    await generateSemesterScorePDF(printArea.value, metadata)
    showToast('បង្កើត PDF បានជោគជ័យ!', 'success')
  } catch (e) {
    showToast('មិនអាចបង្កើត PDF បានទេ', 'error')
  }
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

watch(selectedSemester, fetchAllScores)
</script>

<template>
  <div class="scores-semester-view">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header no-print">
      <div>
        <h1 class="page-title">បញ្ចូលពិន្ទុប្រឡងឆមាស</h1>
        <p class="page-subtitle" v-if="classInfo">
          គ្រប់គ្រងថ្នាក់ <strong>{{ classInfo.class_name }}</strong> ({{ classInfo.academic_years?.year_name }})
        </p>
      </div>
      <div style="display:flex; gap:12px;">
        <button class="btn btn-secondary" @click="handleExport" :disabled="loading || scoreMatrix.length === 0">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
          </svg>
          ទាញយក PDF
        </button>
        <button class="btn btn-primary" @click="saveAll" :disabled="saving || loading">
          <ArrowDownTrayIcon class="w-4 h-4" /> 
          {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុកពិន្ទុឆមាស' }}
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
          <div class="form-group" style="width:280px;">
            <label class="form-label">ជ្រើសរើសឆមាស</label>
            <select class="form-select" v-model="selectedSemester">
              <option :value="1">ឆមាសទី១ (ខែ ១-៣)</option>
              <option :value="2">ឆមាសទី២ (ខែ ៤-៦)</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Score Matrix -->
      <div class="card" ref="printArea">
        <div class="print-header only-print">
          <h2>បញ្ជីពិន្ទុឆមាស</h2>
          <div style="display:flex; justify-content:space-between; margin-top:10px;">
            <span>ថ្នាក់៖ {{ classInfo.class_name }}</span>
            <span>ឆមាសទី៖ {{ selectedSemester }}</span>
            <span>ឆ្នាំសិក្សា៖ {{ classInfo.academic_years?.year_name }}</span>
          </div>
        </div>

        <div class="table-wrapper horizontal-scroll">
          <table class="matrix-table">
            <thead>
              <tr>
                <th rowspan="2" style="width:40px;">ល.រ</th>
                <th rowspan="2" style="min-width:160px; text-align:left;">ឈ្មោះសិស្ស</th>
                <th :colspan="subjects.length" class="text-center">ពិន្ទុប្រឡងឆមាស</th>
                <th rowspan="2" class="summary-col">មធ្យមភាគ<br/>ប្រឡង</th>
                <th colspan="3" class="text-center">មធ្យមភាគប្រចាំខែ</th>
                <th rowspan="2" class="summary-col">មធ្យមភាគ<br/>ខែ</th>
                <th rowspan="2" class="summary-col highlight">មធ្យមភាគ<br/>ឆមាស</th>
                <th rowspan="2" class="summary-col highlight">លំដាប់</th>
              </tr>
              <tr>
                <th v-for="sub in subjects" :key="sub.id" class="sub-col small">
                  <div class="vertical-text small">{{ sub.subject_name }}</div>
                </th>
                <th v-for="m in semesterMonths" :key="m" class="month-col">ខែ {{ m }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, idx) in scoreMatrix" :key="row.student_id">
                <td style="text-align:center;">{{ idx + 1 }}</td>
                <td style="font-weight:700; text-align:left;">{{ row.full_name }}</td>
                <td v-for="sub in subjects" :key="sub.id">
                  <input 
                    type="number" 
                    class="score-input"
                    v-model="row.examSubjects[sub.id].score"
                    min="0" 
                    max="100"
                    @input="calculateAll"
                  />
                </td>
                <td class="avg-cell">{{ row.examAverage }}</td>
                <td v-for="(avg, midx) in row.monthlyAverages" :key="midx" class="monthly-val">
                  {{ avg > 0 ? avg : '—' }}
                </td>
                <td class="avg-cell">{{ row.monthlyTotalAverage }}</td>
                <td class="avg-cell highlight" :class="{ 'text-danger': row.finalAverage < 50 }">{{ row.finalAverage }}</td>
                <td class="rank-cell highlight">{{ row.rank }}</td>
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
.scores-semester-view {
  max-width: 1400px;
  margin: 0 auto;
}

.matrix-table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  font-size: 12px;
}

.matrix-table th, .matrix-table td {
  border: 1px solid var(--border-default);
  padding: 4px;
  text-align: center;
}

.matrix-table th {
  background: #f8fafc;
  font-weight: 700;
  color: #64748b;
}

.sub-col {
  width: 36px;
  height: 80px;
  vertical-align: bottom;
  padding-bottom: 8px !important;
}

.vertical-text {
  writing-mode: vertical-rl;
  transform: rotate(180deg);
  white-space: nowrap;
  display: inline-block;
  font-size: 10px;
}

.score-input {
  width: 32px;
  padding: 2px;
  border: 1px solid transparent;
  text-align: center;
  font-weight: 600;
  border-radius: 4px;
  font-size: 11px;
}

.score-input:focus {
  outline: none;
  border-color: var(--primary-color);
  background: #f1f5f9;
}

.monthly-val {
  color: #94a3b8;
  font-size: 11px;
}

.avg-cell {
  font-weight: 700;
  background: #f8fafc;
  min-width: 45px;
}

.highlight {
  background: #f1f5f9 !important;
  font-weight: 800 !important;
}

.rank-cell {
  font-weight: 800;
  color: var(--primary-color);
  background: #eff6ff !important;
}

.text-danger { color: #ef4444; }

.only-print { display: none; }

@media print {
  .no-print { display: none !important; }
  .only-print { display: block !important; }
  .matrix-table { font-size: 9px; }
  .score-input { border: none; background: transparent; }
  .card { box-shadow: none; border: none; }
}
</style>
