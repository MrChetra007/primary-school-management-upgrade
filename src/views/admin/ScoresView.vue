<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAcademicYearStore } from '@/stores/academicYear'
import { computeMonthlyAverage, computeSemesterAverage, computeRank } from '@/utils/scoreCalculator'
import { generateMonthlyScorePDF, generateSemesterScorePDF } from '@/utils/exportPdf'
import { BuildingOfficeIcon, DocumentIcon, UserGroupIcon, StarIcon } from '@heroicons/vue/24/outline'

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

const rankedList = ref([])

const stats = ref({
  total: 0,
  female: 0,
  male: 0,
  passed: 0,
  femalePassed: 0,
  malePassed: 0,
  failed: 0,
  femaleFailed: 0,
  maleFailed: 0,
  classAverage: 0,
  highestAverage: 0,
  lowestAverage: 0,
  ranges: {
    '9.5-10': { total: 0, male: 0, female: 0, percent: 0 },
    '8.0-9.49': { total: 0, male: 0, female: 0, percent: 0 },
    '6.50-7.99': { total: 0, male: 0, female: 0, percent: 0 },
    '5.00-6.49': { total: 0, male: 0, female: 0, percent: 0 },
    'below-5': { total: 0, male: 0, female: 0, percent: 0 }
  },
  gradeCounts: { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 },
  gradePercents: { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 }
})

const months = [
  { id: 1, name: 'មករា' }, { id: 2, name: 'កុម្ភៈ' }, { id: 3, name: 'មីនា' },
  { id: 4, name: 'មេសា' }, { id: 5, name: 'ឧសភា' }, { id: 6, name: 'មិថុនា' },
  { id: 7, name: 'កក្កដា' }, { id: 8, name: 'សីហា' }, { id: 9, name: 'កញ្ញា' },
  { id: 10, name: 'តុលា' }, { id: 11, name: 'វិច្ឆិកា' }, { id: 12, name: 'ធ្នូ' }
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
  rankedList.value = []
  
  await fetchSubjects()

  // 1. Fetch Students
  const { data: stuData } = await supabase
    .from('students')
    .select('id, full_name, gender')
    .eq('class_id', selectedClassId.value)
    .order('full_name')
  students.value = stuData || []

  if (students.value.length === 0) {
    scoreMatrix.value = []
    rankedList.value = []
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
    // Semester Mode
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
      gender: (student.gender || '').toLowerCase(),
      subjects: studentScores,
      average: avg
    }
  })

  const ranked = computeRank(matrix)
  scoreMatrix.value = ranked.sort((a, b) => a.full_name.localeCompare(b.full_name))
  rankedList.value = computeRank(matrix)
  calculateStats()
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
      gender: (student.gender || '').toLowerCase(),
      examSubjects: examSubMap,
      monthlyAverages: mAvgs,
      examAverage: examAvg,
      average: finalAvg
    }
  })

  const ranked = computeRank(matrix)
  scoreMatrix.value = ranked.sort((a, b) => a.full_name.localeCompare(b.full_name))
  rankedList.value = computeRank(matrix)
  calculateStats()
}

function calculateStats() {
  const list = rankedList.value
  if (list.length === 0) return

  const s = {
    total: list.length,
    female: list.filter(p => (p.gender || '').toLowerCase() === 'female').length,
    male: list.filter(p => (p.gender || '').toLowerCase() === 'male').length,
    passed: list.filter(p => p.average >= 5).length,
    femalePassed: list.filter(p => (p.gender || '').toLowerCase() === 'female' && p.average >= 5).length,
    malePassed: list.filter(p => (p.gender || '').toLowerCase() === 'male' && p.average >= 5).length,
    failed: list.filter(p => p.average < 5).length,
    femaleFailed: list.filter(p => (p.gender || '').toLowerCase() === 'female' && p.average < 5).length,
    maleFailed: list.filter(p => (p.gender || '').toLowerCase() === 'male' && p.average < 5).length,
    classAverage: list.reduce((a, b) => a + b.average, 0) / list.length,
    highestAverage: Math.max(...list.map(p => p.average)),
    lowestAverage: Math.min(...list.map(p => p.average)),
    ranges: {
      '9.5-10': { total: 0, male: 0, female: 0, percent: 0 },
      '8.0-9.49': { total: 0, male: 0, female: 0, percent: 0 },
      '6.50-7.99': { total: 0, male: 0, female: 0, percent: 0 },
      '5.00-6.49': { total: 0, male: 0, female: 0, percent: 0 },
      'below-5': { total: 0, male: 0, female: 0, percent: 0 }
    },
    gradeCounts: { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 },
    gradePercents: { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 }
  }

  list.forEach(p => {
    const avg = p.average
    const g = getGrade(avg)
    s.gradeCounts[g]++

    if (avg >= 9.5) { s.ranges['9.5-10'].total++; if(p.gender === 'female') s.ranges['9.5-10'].female++; else s.ranges['9.5-10'].male++ }
    else if (avg >= 8.0) { s.ranges['8.0-9.49'].total++; if(p.gender === 'female') s.ranges['8.0-9.49'].female++; else s.ranges['8.0-9.49'].male++ }
    else if (avg >= 6.5) { s.ranges['6.50-7.99'].total++; if(p.gender === 'female') s.ranges['6.50-7.99'].female++; else s.ranges['6.50-7.99'].male++ }
    else if (avg >= 5.0) { s.ranges['5.00-6.49'].total++; if(p.gender === 'female') s.ranges['5.00-6.49'].female++; else s.ranges['5.00-6.49'].male++ }
    else { s.ranges['below-5'].total++; if(p.gender === 'female') s.ranges['below-5'].female++; else s.ranges['below-5'].male++ }
  })

  Object.keys(s.ranges).forEach(k => s.ranges[k].percent = Math.round((s.ranges[k].total / s.total) * 100))
  Object.keys(s.gradeCounts).forEach(k => s.gradePercents[k] = Math.round((s.gradeCounts[k] / s.total) * 100))

  stats.value = s
}

function getGrade(score) {
  if (score >= 9.0) return 'A'
  if (score >= 8.0) return 'B'
  if (score >= 7.0) return 'C'
  if (score >= 6.0) return 'D'
  if (score >= 5.0) return 'E'
  return 'F'
}

function toKhmerNum(num) {
  if (num === null || num === undefined) return ''
  const khmerNums = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩']
  return num.toString().replace(/\d/g, d => khmerNums[d])
}

const printArea = ref(null)
async function handleExport() {
  if (!printArea.value) return
  const metadata = {
    schoolName: 'សាលាបឋមសិក្សា',
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
        <h1 class="page-title">របាយការណ៍ពិន្ទុ</h1>
        <p class="page-subtitle">មើល និងទាញយកទិន្នន័យលទ្ធផលសិស្ស</p>
      </div>
      <button class="btn btn-secondary" @click="handleExport" :disabled="loading || scoreMatrix.length === 0">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
        </svg>
        ទាញយក PDF
      </button>
    </div>

    <div class="card no-print" style="margin-bottom:20px;">
      <div class="card-body filter-grid">
        <div class="form-group">
          <label class="form-label">ជ្រើសរើសថ្នាក់</label>
          <select class="form-select" v-model="selectedClassId">
            <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">ប្រភេទរបាយការណ៍</label>
          <select class="form-select" v-model="scoreMode">
            <option value="monthly">របាយការណ៍ប្រចាំខែ</option>
            <option value="semester">របាយការណ៍ឆមាស</option>
          </select>
        </div>
        <div v-if="scoreMode === 'monthly'" class="form-group">
          <label class="form-label">ខែ</label>
          <select class="form-select" v-model="selectedMonth">
            <option v-for="m in months" :key="m.id" :value="m.id">{{ m.name }}</option>
          </select>
        </div>
        <div v-else class="form-group">
          <label class="form-label">ឆមាស</label>
          <select class="form-select" v-model="selectedSemester">
            <option :value="1">ឆមាសទី១ (ខែ ១-៣)</option>
            <option :value="2">ឆមាសទី២ (ខែ ៤-៦)</option>
          </select>
        </div>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:400px; border-radius:12px;"></div>
    </div>

    <div v-else-if="!selectedClassId" class="empty-state">
      <BuildingOfficeIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">សូមជ្រើសរើសថ្នាក់ដើម្បីមើលពិន្ទុ</p>
    </div>

    <div v-else-if="scoreMatrix.length === 0" class="empty-state">
      <DocumentIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">មិនមានពិន្ទុសម្រាប់កំឡុងពេលនេះទេ</p>
    </div>

    <div v-else ref="printArea">
      <!-- Summary Tiles -->
      <div class="tile-group no-print">
        <div class="group-title">សង្ខេបសិស្ស</div>
        <div class="tiles-row">
          <div class="stat-tile border-purple">
            <div class="tile-main">
              <span class="tile-label">សិស្សសរុប</span>
              <span class="tile-val">{{ stats.total }} នាក់</span>
            </div>
            <div class="tile-footer">
              <span>ស្រី <b class="text-pink">{{ stats.female }}</b></span>
              <span>ប្រុស <b class="text-blue">{{ stats.male }}</b></span>
            </div>
          </div>
          <div class="stat-tile border-green">
            <div class="tile-main">
              <span class="tile-label">ជាប់មធ្យមភាគ</span>
              <span class="tile-val">{{ stats.passed }} នាក់</span>
            </div>
            <div class="tile-footer">
              <span>ស្រី <b class="text-pink">{{ stats.femalePassed }}</b></span>
              <span>ប្រុស <b class="text-blue">{{ stats.malePassed }}</b></span>
            </div>
          </div>
          <div class="stat-tile border-red">
            <div class="tile-main">
              <span class="tile-label">ធ្លាក់មធ្យមភាគ</span>
              <span class="tile-val">{{ stats.failed }} នាក់</span>
            </div>
            <div class="tile-footer">
              <span>ស្រី <b class="text-pink">{{ stats.femaleFailed }}</b></span>
              <span>ប្រុស <b class="text-blue">{{ stats.maleFailed }}</b></span>
            </div>
          </div>
        </div>
      </div>

      <!-- Range Distribution -->
      <div class="tile-group no-print">
        <div class="group-title">ការចែកចាយមធ្យមភាគ</div>
        <div class="tiles-row range-tiles">
          <div v-for="(range, key) in stats.ranges" :key="key" class="stat-tile" :class="'border-range-' + key.replace('.', '-')">
            <div class="tile-main">
              <span class="tile-label">មធ្យមភាគ {{ key }}</span>
              <div class="flex items-center gap-2">
                <span class="tile-val">{{ range.total }} នាក់</span>
                <span class="badge-percent">{{ toKhmerNum(range.percent) }}%</span>
              </div>
            </div>
            <div class="tile-footer">
              <span>ស្រី <b class="text-pink">{{ range.female }}</b></span>
              <span>ប្រុស <b class="text-blue">{{ range.male }}</b></span>
            </div>
          </div>

          <div class="stat-tile border-purple highlight-tile">
            <div class="highlight-val">{{ stats.classAverage.toFixed(2) }}</div>
            <div class="highlight-label">មធ្យមភាគថ្នាក់</div>
            <div class="highlight-footer">
              <div class="foot-item">
                <span>ខ្ពស់បំផុត</span>
                <b>{{ stats.highestAverage.toFixed(2) }}</b>
              </div>
              <div class="foot-item">
                <span>ទាបបំផុត</span>
                <b>{{ stats.lowestAverage.toFixed(2) }}</b>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Grade Distribution -->
      <div class="card no-print" style="margin-bottom:24px;">
        <div class="card-header" style="padding:12px 16px; border-bottom:1px solid #f1f5f9;">
          <h3 style="font-size:14px; font-weight:700;">ការចែកចាយកម្រិតពិន្ទុ</h3>
        </div>
        <div class="card-body" style="padding:16px;">
          <div class="grade-grid">
            <div v-for="g in ['A', 'B', 'C', 'D', 'E', 'F']" :key="g" class="grade-box" :class="'box-' + g">
              <div class="grade-letter">{{ g }}</div>
              <div class="grade-info">{{ stats.gradeCounts[g] }} នាក់</div>
              <div class="grade-percent">{{ toKhmerNum(stats.gradePercents[g]) }}%</div>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="table-wrapper horizontal-scroll">
        <table class="matrix-table" :class="{ 'semester-mode': scoreMode === 'semester' }">
          <thead>
            <!-- Monthly Mode -->
            <template v-if="scoreMode === 'monthly'">
              <tr>
                <th style="width:40px;">ល.រ</th>
                <th style="min-width:160px; text-align:left;">ឈ្មោះសិស្ស</th>
                <th v-for="sub in subjects" :key="sub.id" class="sub-col">
                  <div class="vertical-text">{{ sub.subject_name }}</div>
                </th>
                <th class="summary-col">មធ្យមភាគ</th>
                <th class="summary-col">លំដាប់</th>
              </tr>
            </template>

            <!-- Semester Mode -->
            <template v-else>
              <tr>
                <th rowspan="2" style="width:40px;">ល.រ</th>
                <th rowspan="2" style="min-width:150px; text-align:left;">ឈ្មោះសិស្ស</th>
                <th :colspan="subjects.length">ពិន្ទុប្រឡងឆមាស</th>
                <th rowspan="2" class="summary-col">មធ្យមភាគ<br/>ប្រឡង</th>
                <th colspan="3">មធ្យមភាគប្រចាំខែ</th>
                <th rowspan="2" class="summary-col highlight">មធ្យមភាគ<br/>ឆមាស</th>
                <th rowspan="2" class="summary-col highlight">លំដាប់</th>
              </tr>
              <tr>
                <th v-for="sub in subjects" :key="sub.id" class="sub-col small">
                  <div class="vertical-text small">{{ sub.subject_name }}</div>
                </th>
                <th v-for="m in semesterMonths" :key="m" class="month-col">ខែ {{ m }}</th>
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

              <td class="avg-cell highlight" :class="{ 'text-danger': row.average < 50 }">
                {{ row.average }}
              </td>
              <td class="rank-cell highlight">{{ row.rank }}</td>
            </tr>
          </tbody>
        </table>
      </div>
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

/* Stats Tile Styles */
.tile-group {
  margin-bottom: 24px;
}

.group-title {
  font-size: 14px;
  font-weight: 700;
  color: #374151;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 2px solid #e5e7eb;
}

.tiles-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 16px;
}

.stat-tile {
  background: white;
  border-radius: 12px;
  padding: 16px;
  border: 1px solid #e5e7eb;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  transition: transform 0.2s;
}

.stat-tile:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.border-purple { border-left: 4px solid #8b5cf6; }
.border-green { border-left: 4px solid #10b981; }
.border-red { border-left: 4px solid #ef4444; }

.border-range-9-5-10 { border-left: 4px solid #059669; }
.border-range-8-0-9-49 { border-left: 4px solid #3b82f6; }
.border-range-6-50-7-99 { border-left: 4px solid #f59e0b; }
.border-range-5-00-6-49 { border-left: 4px solid #f97316; }
.border-range-below-5 { border-left: 4px solid #dc2626; }

.tile-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.tile-label { font-size: 14px; font-weight: 700; color: #4b5563; }
.tile-val { font-size: 18px; font-weight: 800; color: #1e40af; }

.tile-footer {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #6b7280;
  padding-top: 8px;
  border-top: 1px dashed #e5e7eb;
}

.text-pink { color: #ec4899; }
.text-blue { color: #3b82f6; }

.badge-percent {
  background: #dbeafe;
  color: #1e40af;
  padding: 2px 8px;
  border-radius: 8px;
  font-size: 11px;
  font-weight: 800;
}

.highlight-tile {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.highlight-val { font-size: 32px; font-weight: 800; color: #8b5cf6; }
.highlight-label { font-size: 13px; font-weight: 700; color: #64748b; margin-bottom: 12px; }
.highlight-footer { display: flex; width: 100%; justify-content: space-between; font-size: 11px; }
.foot-item { display: flex; flex-direction: column; }

.grade-grid {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 12px;
}

.grade-box {
  text-align: center;
  padding: 12px;
  border-radius: 10px;
}

.box-A { background: #dcfce7; color: #166534; }
.box-B { background: #dbeafe; color: #1e40af; }
.box-C { background: #fef3c7; color: #92400e; }
.box-D { background: #fde68a; color: #92400e; }
.box-E { background: #fecaca; color: #991b1b; }
.box-F { background: #f3f4f6; color: #6b7280; }

.grade-letter { font-size: 18px; font-weight: 800; }
.grade-info { font-size: 11px; margin: 4px 0; }
.grade-percent { font-size: 10px; opacity: 0.8; }

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
