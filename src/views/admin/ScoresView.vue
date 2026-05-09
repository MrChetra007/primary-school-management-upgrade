<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAcademicYearStore } from '@/stores/academicYear'
import { computeMonthlyAverage, computeSemesterAverage, computeRank } from '@/utils/scoreCalculator'
import { generateMonthlyScorePDF, generateSemesterScorePDF } from '@/utils/exportPdf'
import { BuildingOfficeIcon, DocumentIcon } from '@heroicons/vue/24/outline'

const yearStore = useAcademicYearStore()

// State
const classes = ref([])
const subjects = ref([])
const students = ref([])
const loading = ref(true)

// Filters
const selectedClassId = ref(null)
const scoreMode = ref('monthly') // 'monthly' or 'semester'
const selectedMonth = ref(new Date().getMonth() + 1)
const selectedSemester = ref(1)

// Scores Data
const rawScores = ref([])
const scoreMatrix = ref([])

const months = [
  { id: 1, name: 'January' }, { id: 2, name: 'February' }, { id: 3, name: 'March' },
  { id: 4, name: 'April' }, { id: 5, name: 'May' }, { id: 6, name: 'June' },
  { id: 7, name: 'July' }, { id: 8, name: 'August' }, { id: 9, name: 'September' },
  { id: 10, name: 'October' }, { id: 11, name: 'November' }, { id: 12, name: 'December' }
]

const semesterMonths = computed(() => {
  return selectedSemester.value === 1 ? [1, 2, 3] : [4, 5, 6]
})

onMounted(async () => {
  loading.value = true
  await Promise.all([fetchClasses(), fetchSubjects()])
  if (classes.value.length > 0) {
    selectedClassId.value = classes.value[0].id
  }
  loading.value = false
})

async function fetchClasses() {
  const { data } = await supabase
    .from('classes')
    .select('id, class_name')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('class_name')
  classes.value = data || []
}

async function fetchSubjects() {
  if (!selectedClassId.value) return
  const { data } = await supabase
    .from('class_subjects')
    .select('subjects(*)')
    .eq('class_id', selectedClassId.value)
  subjects.value = data?.map(s => s.subjects) || []
}

async function fetchData() {
  if (!selectedClassId.value) return
  loading.value = true
  
  await fetchSubjects()

  // 1. Fetch Students
  const { data: stuData } = await supabase
    .from('students')
    .select('id, full_name')
    .eq('class_id', selectedClassId.value)
    .order('full_name')
  students.value = stuData || []

  if (students.value.length === 0) {
    scoreMatrix.value = []
    loading.value = false
    return
  }

  const studentIds = students.value.map(s => s.id)

  if (scoreMode.value === 'monthly') {
    const { data } = await supabase
      .from('scores')
      .select('*')
      .in('student_id', studentIds)
      .eq('month', selectedMonth.value)
      .eq('score_type', 'monthly')
    rawScores.value = data || []
    buildMonthlyMatrix()
  } else {
    // Semester Mode: Fetch Exam + Monthly for those 3 months
    const [examRes, monthRes] = await Promise.all([
      supabase.from('scores').select('*').in('student_id', studentIds).eq('semester', selectedSemester.value).eq('score_type', 'semester'),
      supabase.from('scores').select('*').in('student_id', studentIds).in('month', semesterMonths.value).eq('score_type', 'monthly')
    ])
    
    rawScores.value = examRes.data || []
    const semesterMonthlyScores = monthRes.data || []
    buildSemesterMatrix(semesterMonthlyScores)
  }

  loading.value = false
}

function buildMonthlyMatrix() {
  const matrix = students.value.map(student => {
    const studentScores = {}
    subjects.value.forEach(sub => {
      const match = rawScores.value.find(s => s.student_id === student.id && s.subject_id === sub.id)
      studentScores[sub.id] = match?.score ?? ''
    })

    const scoresArray = Object.values(studentScores).filter(s => s !== '').map(s => ({ score: s }))
    const avg = computeMonthlyAverage(scoresArray)

    return {
      student_id: student.id,
      full_name: student.full_name,
      subjects: studentScores,
      average: avg
    }
  })

  // Rank
  const ranked = computeRank(matrix)
  scoreMatrix.value = ranked.sort((a, b) => a.full_name.localeCompare(b.full_name))
}

function buildSemesterMatrix(mScores) {
  const matrix = students.value.map(student => {
    const examSubMap = {}
    subjects.value.forEach(sub => {
      const match = rawScores.value.find(s => s.student_id === student.id && s.subject_id === sub.id)
      examSubMap[sub.id] = match?.score ?? ''
    })

    const mAvgs = semesterMonths.value.map(m => {
      const scores = mScores.filter(s => s.student_id === student.id && s.month === m).map(s => ({ score: s.score }))
      return computeMonthlyAverage(scores)
    })

    const examArray = Object.values(examSubMap).filter(s => s !== '').map(s => ({ score: s }))
    const examAvg = computeMonthlyAverage(examArray)
    const finalAvg = computeSemesterAverage(mAvgs, examAvg)

    return {
      student_id: student.id,
      full_name: student.full_name,
      examSubjects: examSubMap,
      monthlyAverages: mAvgs,
      examAverage: examAvg,
      average: finalAvg // for ranking
    }
  })

  const ranked = computeRank(matrix)
  scoreMatrix.value = ranked.sort((a, b) => a.full_name.localeCompare(b.full_name))
}

const printArea = ref(null)
async function handleExport() {
  if (!printArea.value) return
  const metadata = {
    schoolName: 'Primary School',
    className: classes.value.find(c => c.id === selectedClassId.value)?.class_name,
    year: yearStore.selectedYearName
  }
  
  try {
    if (scoreMode.value === 'monthly') {
      metadata.month = months.find(m => m.id === selectedMonth.value)?.name
      await generateMonthlyScorePDF(printArea.value, metadata)
    } else {
      metadata.semester = selectedSemester.value
      await generateSemesterScorePDF(printArea.value, metadata)
    }
  } catch (e) {
    console.error(e)
  }
}

watch([selectedClassId, scoreMode, selectedMonth, selectedSemester], fetchData)
</script>

<template>
  <div class="scores-view">
    <div class="page-header no-print">
      <div>
        <h1 class="page-title">របាយការណ៍ពិន្ទុ (Score Reports)</h1>
        <p class="page-subtitle">View and export class performance data</p>
      </div>
      <button class="btn btn-secondary" @click="handleExport" :disabled="loading || scoreMatrix.length === 0">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
        Print PDF
      </button>
    </div>

    <div class="card no-print" style="margin-bottom:20px;">
      <div class="card-body filter-grid">
        <div class="form-group">
          <label class="form-label">Select Class</label>
          <select class="form-select" v-model="selectedClassId">
            <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">Report Type</label>
          <select class="form-select" v-model="scoreMode">
            <option value="monthly">Monthly Report</option>
            <option value="semester">Semester Report</option>
          </select>
        </div>
        <div v-if="scoreMode === 'monthly'" class="form-group">
          <label class="form-label">Month</label>
          <select class="form-select" v-model="selectedMonth">
            <option v-for="m in months" :key="m.id" :value="m.id">{{ m.name }}</option>
          </select>
        </div>
        <div v-else class="form-group">
          <label class="form-label">Semester</label>
          <select class="form-select" v-model="selectedSemester">
            <option :value="1">Semester 1 (Months 1-3)</option>
            <option :value="2">Semester 2 (Months 4-6)</option>
          </select>
        </div>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:400px; border-radius:12px;"></div>
    </div>

    <div v-else-if="!selectedClassId" class="empty-state">
      <BuildingOfficeIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">Select a class to view scores</p>
    </div>

    <div v-else-if="scoreMatrix.length === 0" class="empty-state">
      <DocumentIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">No scores found for this period</p>
    </div>

    <div v-else ref="printArea" class="card">
      <div class="table-wrapper horizontal-scroll">
        <table class="matrix-table" :class="{ 'semester-mode': scoreMode === 'semester' }">
          <thead>
            <template v-if="scoreMode === 'monthly'">
              <tr>
                <th style="width:40px;">ល.រ</th>
                <th style="min-width:160px; text-align:left;">ឈ្មោះសិស្ស</th>
                <th v-for="sub in subjects" :key="sub.id" class="sub-col">
                  <div class="vertical-text">{{ sub.subject_name }}</div>
                </th>
                <th class="summary-col">មធ្យម</th>
                <th class="summary-col">លំដាប់</th>
              </tr>
            </template>
            <template v-else>
              <tr>
                <th rowspan="2" style="width:40px;">ល.រ</th>
                <th rowspan="2" style="min-width:150px; text-align:left;">ឈ្មោះសិស្ស</th>
                <th :colspan="subjects.length">ពិន្ទុប្រឡងឆមាស</th>
                <th rowspan="2" class="summary-col">មធ្យម<br/>ប្រឡង</th>
                <th colspan="3">មធ្យមភាគប្រចាំខែ</th>
                <th rowspan="2" class="summary-col highlight">មធ្យម<br/>ឆមាស</th>
                <th rowspan="2" class="summary-col highlight">លំដាប់</th>
              </tr>
              <tr>
                <th v-for="sub in subjects" :key="sub.id" class="sub-col small">
                  <div class="vertical-text small">{{ sub.subject_name }}</div>
                </th>
                <th v-for="m in semesterMonths" :key="m" class="month-col">ម.{{ m }}</th>
              </tr>
            </template>
          </thead>
          <tbody>
            <tr v-for="(row, idx) in scoreMatrix" :key="row.student_id">
              <td style="text-align:center;">{{ idx + 1 }}</td>
              <td style="font-weight:700; text-align:left;">{{ row.full_name }}</td>
              
              <template v-if="scoreMode === 'monthly'">
                <td v-for="sub in subjects" :key="sub.id">
                  {{ row.subjects[sub.id] || '—' }}
                </td>
              </template>

              <template v-else>
                <td v-for="sub in subjects" :key="sub.id">
                  {{ row.examSubjects[sub.id] || '—' }}
                </td>
                <td class="avg-cell">{{ row.examAverage }}</td>
                <td v-for="(avg, midx) in row.monthlyAverages" :key="midx" class="monthly-val">
                  {{ avg > 0 ? avg : '—' }}
                </td>
              </template>

              <td class="avg-cell highlight" :class="{ 'text-danger': row.average < 50 }">{{ row.average }}</td>
              <td class="rank-cell highlight">{{ row.rank }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.scores-view {
  display: flex;
  flex-direction: column;
}

.filter-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
}

.matrix-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.matrix-table th, .matrix-table td {
  border: 1px solid var(--border-default);
  padding: 6px;
  text-align: center;
}

.matrix-table th {
  background: #f8fafc;
  color: #64748b;
  font-weight: 700;
}

.sub-col {
  width: 40px;
  height: 90px;
  vertical-align: bottom;
  padding-bottom: 8px !important;
}

.vertical-text {
  writing-mode: vertical-rl;
  transform: rotate(180deg);
  white-space: nowrap;
  display: inline-block;
  font-size: 11px;
}

.avg-cell {
  font-weight: 700;
  background: #f8fafc;
}

.highlight {
  background: #f1f5f9 !important;
  font-weight: 800 !important;
}

.rank-cell {
  color: var(--primary-color);
  background: #eff6ff !important;
  font-weight: 800;
}

.monthly-val {
  color: #94a3b8;
  font-size: 11px;
}

.text-danger { color: #ef4444; }

/* Adjustments for Semester mode which has more columns */
.semester-mode {
  font-size: 11px;
}
.semester-mode .sub-col {
  height: 70px;
}
.semester-mode .vertical-text {
  font-size: 10px;
}
</style>
