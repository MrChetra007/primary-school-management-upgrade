<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useSchoolStore } from '@/stores/school'
import { supabase } from '@/lib/supabase'
import { computeMonthlyAverage, computeSemesterAverage, computeYearlyAverage, computeRank } from '@/utils/scoreCalculator'
import { generateYearlyScorePDF } from '@/utils/exportPdf'
import { ArrowDownTrayIcon, BuildingOfficeIcon } from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'
import { useCache } from '@/composables/useCache'

const auth = useAuthStore()
const school = useSchoolStore()
const { showToast } = useToast()
const { get: cacheGet, set: cacheSet, isOnline } = useCache()

const students = ref([])
const subjects = ref([])
const classInfo = ref(null)
const loading = ref(true)
const exporting = ref(false)
const isStale = ref(false)

const semesterConfigs = ref([])
const examScores = ref([])
const monthlyScores = ref([])
const scoreMatrix = ref([])

function defaultMonths(sem) {
  return sem === 1 ? [1, 2, 3] : [4, 5, 6]
}

function monthsForSemester(sem) {
  const cfg = semesterConfigs.value.find(s => s.semester === sem)
  return cfg?.months || defaultMonths(sem)
}

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
  const cacheKey = `yearly_ref_${teacherId}`

  if (isOnline.value) {
    const { data: classData } = await supabase
      .from('classes')
      .select('*, academic_years!inner(id, year_name, status)')
      .eq('teacher_id', teacherId)
      .eq('academic_years.status', 'active').is('academic_years.deleted_at', null)
      .maybeSingle()

    if (classData) {
      classInfo.value = classData

      const { data: subData } = await supabase
        .from('class_subjects')
        .select('subjects(*)')
        .eq('class_id', classData.id)
      subjects.value = subData?.map(s => s.subjects) || []

      const { data: cfgData } = await supabase
        .from('semester_config')
        .select('*')
        .eq('academic_year_id', classData.academic_year_id)
        .order('semester')
      semesterConfigs.value = cfgData || []

      const { data: stuData } = await supabase
        .from('students')
        .select('id, full_name')
        .eq('class_id', classData.id)
        .order('full_name')
      students.value = stuData || []

      cacheSet(cacheKey, {
        classInfo: classInfo.value,
        subjects: subjects.value,
        students: students.value,
        semesterConfigs: semesterConfigs.value
      }, 1440)
      isStale.value = false
      await fetchAllScores()
      loading.value = false
      return
    }
  }

  const cached = cacheGet(cacheKey)
  if (cached) {
    classInfo.value = cached.classInfo
    subjects.value = cached.subjects
    students.value = cached.students
    semesterConfigs.value = cached.semesterConfigs || []
    isStale.value = true
    await fetchAllScores()
  }
  loading.value = false
}

async function fetchAllScores() {
  if (!classInfo.value || students.value.length === 0) return
  const studentIds = students.value.map(s => s.id)
  const academicYearId = classInfo.value.academic_year_id
  const cacheKey = `scores_yearly_${classInfo.value.id}`

  if (isOnline.value) {
    const examResults = await Promise.all([1, 2].map(sem =>
      supabase.from('scores').select('*')
        .in('student_id', studentIds)
        .eq('academic_year_id', academicYearId)
        .eq('score_type', 'semester')
        .eq('semester', sem)
    ))
    const allMonths = [...new Set([1, 2].flatMap(sem => monthsForSemester(sem)))]
    const monthResults = await Promise.all(allMonths.map(m =>
      supabase.from('scores').select('*')
        .in('student_id', studentIds)
        .eq('academic_year_id', academicYearId)
        .eq('score_type', 'monthly')
        .eq('month', m)
    ))
    const error = [...examResults, ...monthResults].find(r => r.error)?.error
    if (!error) {
      examScores.value = examResults.flatMap(r => r.data || [])
      monthlyScores.value = monthResults.flatMap(r => r.data || [])
      cacheSet(cacheKey, { examScores: examScores.value, monthlyScores: monthlyScores.value }, 120)
      buildMatrix()
      return
    }
  }

  const cached = cacheGet(cacheKey)
  if (cached) {
    examScores.value = cached.examScores || []
    monthlyScores.value = cached.monthlyScores || []
  } else {
    examScores.value = []
    monthlyScores.value = []
  }
  buildMatrix()
}

function buildMatrix() {
  const matrix = students.value.map(student => {
    const semAvg = {}
    ;[1, 2].forEach(sem => {
      const semMonths = monthsForSemester(sem)
      const examSubMap = {}
      subjects.value.forEach(sub => {
        const match = examScores.value.find(s =>
          s.student_id === student.id && s.subject_id === sub.id && s.semester === sem)
        examSubMap[sub.id] = match?.score ?? ''
      })

      const mAvgs = semMonths.map(m => {
        const monthScores = monthlyScores.value
          .filter(s => s.student_id === student.id && s.month === m)
          .map(s => ({ score: s.score }))
        return computeMonthlyAverage(monthScores)
      })

      const examArray = Object.values(examSubMap).filter(s => s !== '').map(s => ({ score: s }))
      const examAvg = computeMonthlyAverage(examArray)
      semAvg[sem] = computeSemesterAverage(mAvgs, examAvg)
    })

    return {
      student_id: student.id,
      full_name: student.full_name,
      semester1: semAvg[1],
      semester2: semAvg[2],
      average: computeYearlyAverage([semAvg[1], semAvg[2]]),
      rank: 0
    }
  })

  const ranked = computeRank(matrix)
  scoreMatrix.value = ranked
    .map(r => ({ ...r }))
    .sort((a, b) => a.full_name.localeCompare(b.full_name))
}

async function handleExport() {
  if (exporting.value || scoreMatrix.value.length === 0) return
  exporting.value = true
  try {
    await generateYearlyScorePDF(scoreMatrix.value, {
      schoolName:   school.schoolName || '.........................',
      districtName: '.........................',
      className:    classInfo.value?.class_name || '',
      year:         classInfo.value?.academic_years?.year_name || ''
    })
  } catch (e) {
    console.error('PDF export failed:', e)
    showToast('ការបង្កើត PDF បរាជ័យ', 'error')
  } finally {
    exporting.value = false
  }
}
</script>

<template>
  <div class="scores-yearly-view">
    <div class="page-header">
      <div>
        <h1 class="page-title">លទ្ធផលប្រចាំឆ្នាំ</h1>
        <p class="page-subtitle" v-if="classInfo">
          មធ្យមភាគប្រចាំឆ្នាំរបស់ថ្នាក់ <strong>{{ classInfo.class_name }}</strong> ({{ classInfo.academic_years?.year_name }})
          <span v-if="isStale" class="offline-badge">ប្រើទិន្នន័យពីឃ្លាំង</span>
        </p>
      </div>
      <div>
        <button class="btn btn-primary" @click="handleExport" :disabled="exporting || loading || scoreMatrix.length === 0">
          <ArrowDownTrayIcon class="w-4 h-4" />
          {{ exporting ? 'កំពុងបង្កើត...' : 'ទាញយក PDF' }}
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

    <div v-else-if="scoreMatrix.length === 0" class="empty-state">
      <p class="empty-state-title">មិនមានសិស្សក្នុងថ្នាក់នេះទេ</p>
    </div>

    <div v-else class="card">
      <div class="table-wrapper horizontal-scroll">
        <table class="matrix-table">
          <thead>
            <tr>
              <th style="width:40px;">ល.រ</th>
              <th style="min-width:180px; text-align:left;">ឈ្មោះសិស្ស</th>
              <th class="summary-col">មធ្យមភាគ<br/>ឆមាស ១</th>
              <th class="summary-col">មធ្យមភាគ<br/>ឆមាស ២</th>
              <th class="summary-col highlight">មធ្យមភាគ<br/>ប្រចាំឆ្នាំ</th>
              <th class="summary-col highlight">លំដាប់</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, idx) in scoreMatrix" :key="row.student_id">
              <td style="text-align:center;">{{ idx + 1 }}</td>
              <td style="font-weight:700; text-align:left;">{{ row.full_name }}</td>
              <td class="avg-cell">{{ row.semester1 > 0 ? row.semester1 : '—' }}</td>
              <td class="avg-cell">{{ row.semester2 > 0 ? row.semester2 : '—' }}</td>
              <td class="avg-cell highlight" :class="{ 'text-danger': row.average < 5 }">{{ row.average }}</td>
              <td class="rank-cell highlight">{{ row.rank }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.scores-yearly-view {
  max-width: 1000px;
  margin: 0 auto;
}

.table-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  position: relative;
}

.matrix-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  background: white;
  white-space: nowrap;
}

.matrix-table th,
.matrix-table td {
  border-bottom: 1px solid var(--border-default);
  border-right: 1px solid var(--border-default);
  padding: 10px;
  text-align: center;
}

.matrix-table thead tr:first-child th {
  border-top: 1px solid var(--border-default);
}

.matrix-table th:first-child,
.matrix-table td:first-child {
  border-left: 1px solid var(--border-default);
}

.matrix-table th {
  background: #f8fafc;
  font-size: 12px;
  font-weight: 700;
  color: #64748b;
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

.text-danger { color: #ef4444; }

.offline-badge {
  margin-left: 8px;
  font-size: 11px;
  font-weight: 700;
  color: #92400e;
  background: #fef3c7;
  padding: 2px 8px;
  border-radius: 8px;
}
</style>
