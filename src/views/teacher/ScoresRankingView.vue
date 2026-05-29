<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useSchoolStore } from '@/stores/school'
import { useAcademicYearStore } from '@/stores/academicYear'
import { supabase } from '@/lib/supabase'
import { computeMonthlyAverage, computeSemesterAverage, computeRank } from '@/utils/scoreCalculator'
import { 
  TrophyIcon, 
  UserGroupIcon, 
  CalendarIcon, 
  StarIcon,
  ChevronLeftIcon,
  AcademicCapIcon,
  CheckIcon,
  XCircleIcon
} from '@heroicons/vue/24/outline'
import { useRoute, useRouter } from 'vue-router'
import { generateMonthlyScorePDF, generateSemesterScorePDF } from '@/utils/exportPdf'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const schoolStore = useSchoolStore()
const academicYearStore = useAcademicYearStore()
const loading = ref(true)
const classInfo = ref(null)
const students = ref([])
const subjects = ref([])
const rawScores = ref([])
const rankedList = ref([])
const exporting = ref(false)
const toast = ref(null)

const mode = ref(route.query.mode || 'monthly') 
const selectedMonth = ref(Number(route.query.month) || new Date().getMonth() + 1)
const selectedSemester = ref(Number(route.query.semester) || 1)

const months = [
  { id: 1, name: 'មករា' }, { id: 2, name: 'កុម្ភៈ' }, { id: 3, name: 'មីនា' },
  { id: 4, name: 'មេសា' }, { id: 5, name: 'ឧសភា' }, { id: 6, name: 'មិថុនា' },
  { id: 7, name: 'កក្កដា' }, { id: 8, name: 'សីហា' }, { id: 9, name: 'កញ្ញា' },
  { id: 10, name: 'តុលា' }, { id: 11, name: 'វិច្ឆិកា' }, { id: 12, name: 'ធ្នូ' }
]

const semesterConfigs = ref([])

async function fetchSemesterConfig() {
  if (!classInfo.value) { semesterConfigs.value = []; return }
  const { data } = await supabase
    .from('semester_config')
    .select('*')
    .eq('academic_year_id', classInfo.value.academic_year_id)
    .order('semester')
  semesterConfigs.value = data || []
}

const semesterMonths = computed(() => {
  const cfg = semesterConfigs.value.find(s => s.semester === selectedSemester.value)
  return cfg?.months || []
})

const semesterOptions = computed(() =>
  semesterConfigs.value.map(cfg => ({
    semester: cfg.semester,
    label: `ឆមាសទី${cfg.semester} (ខែ ${cfg.months.join(', ')})`
  }))
)

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

    await fetchSemesterConfig()

    // 2. Get Students
    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name, gender')
      .eq('class_id', classData.id)
      .order('full_name')
    students.value = stuData || []
    
    await fetchData()
  }
  loading.value = false
}

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

async function fetchData() {
  if (!classInfo.value || students.value.length === 0) return
  loading.value = true

  const studentIds = students.value.map(s => s.id)

  if (mode.value === 'monthly') {
    const { data } = await supabase
      .from('scores')
      .select('*')
      .in('student_id', studentIds)
      .eq('month', selectedMonth.value)
      .eq('score_type', 'monthly')
    rawScores.value = data || []
    calculateMonthlyRanking()
  } else {
    if (semesterMonths.value.length === 0) {
      rankedList.value = []
      loading.value = false
      return
    }
    const [examRes, monthRes] = await Promise.all([
      supabase.from('scores').select('*').in('student_id', studentIds).eq('semester', selectedSemester.value).eq('score_type', 'semester'),
      supabase.from('scores').select('*').in('student_id', studentIds).in('month', semesterMonths.value).eq('score_type', 'monthly')
    ])
    
    const semesterMonthlyScores = monthRes.data || []
    const semesterExamScores = examRes.data || []
    calculateSemesterRanking(semesterMonthlyScores, semesterExamScores)
  }

  calculateStats()
  loading.value = false
}

function calculateMonthlyRanking() {
  const list = students.value.map(student => {
    const scores = rawScores.value.filter(s => s.student_id === student.id).map(s => ({ score: s.score }))
    return {
      id: student.id,
      full_name: student.full_name,
      gender: (student.gender || '').toLowerCase(),
      average: computeMonthlyAverage(scores)
    }
  })
  rankedList.value = computeRank(list).sort((a, b) => a.rank - b.rank)
}

function calculateSemesterRanking(mScores, eScores) {
  const list = students.value.map(student => {
    const mAvgs = semesterMonths.value.map(m => {
      const scores = mScores.filter(s => s.student_id === student.id && s.month === m).map(s => ({ score: s.score }))
      return computeMonthlyAverage(scores)
    })
    
    const examScores = eScores.filter(s => s.student_id === student.id).map(s => ({ score: s.score }))
    const examAvg = computeMonthlyAverage(examScores)
    
    return {
      id: student.id,
      full_name: student.full_name,
      gender: (student.gender || '').toLowerCase(),
      average: computeSemesterAverage(mAvgs, examAvg)
    }
  })
  rankedList.value = computeRank(list).sort((a, b) => a.rank - b.rank)
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

async function handleExport() {
  if (exporting.value || rankedList.value.length === 0) return
  exporting.value = true

  const metadata = {
    schoolName:   '.........................',
    districtName: '.........................',
    className:    classInfo.value?.class_name || '',
    year:         classInfo.value?.academic_years?.year_name || ''
  }

  try {
    if (mode.value === 'monthly') {
      metadata.month = months.find(m => m.id === selectedMonth.value)?.name || ''
      await generateMonthlyScorePDF(rankedList.value, metadata)
    } else {
      metadata.semester = selectedSemester.value
      await generateSemesterScorePDF(rankedList.value, metadata)
    }
    showToast('បង្កើត PDF បានជោគជ័យ!', 'success')
  } catch (e) {
    showToast('មិនអាចបង្កើត PDF បានទេ', 'error')
  } finally {
    exporting.value = false
  }
}

function handleNavigateToHonorBoard() {
  const top5 = rankedList.value.slice(0, 5).map(s => ({
    full_name: s.full_name,
    average: s.average,
    rank: s.rank,
    gender: s.gender
  }))
  const className = classInfo.value?.class_name || ''
  const monthName = mode.value === 'monthly'
    ? months.find(m => m.id === selectedMonth.value)?.name || ''
    : ''
  router.push({
    name: 'teacher-honor-board-editor',
    query: {
      mode: mode.value,
      students: JSON.stringify(top5),
      className,
      year: classInfo.value?.academic_years?.year_name || '',
      monthName,
      semester: mode.value === 'semester' ? String(selectedSemester.value) : ''
    }
  })
}

async function generateReportLink() {
  if (!classInfo.value || !mode.value) return

  const month = mode.value === 'monthly' ? selectedMonth.value : null
  const semester = mode.value === 'semester' ? selectedSemester.value : null

  let linkQuery = supabase
    .from('report_links')
    .select('id')
    .eq('class_id', classInfo.value.id)
    .eq('academic_year_id', classInfo.value.academic_year_id)
    .eq('score_type', mode.value)
  if (month !== null) {
    linkQuery = linkQuery.eq('month', month)
  } else {
    linkQuery = linkQuery.is('month', null)
  }
  if (semester !== null) {
    linkQuery = linkQuery.eq('semester', semester)
  } else {
    linkQuery = linkQuery.is('semester', null)
  }
  const { data: existing } = await linkQuery.maybeSingle()

  if (existing) {
    const link = `${window.location.origin}/parent/report/${existing.id}`
    await navigator.clipboard.writeText(link)
    showToast('តំណភ្ជាប់មានរួចហើយ! បានចម្លងឡើងវិញ', 'success')
    return
  }

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
    .select('id')
    .single()

  if (error || !inserted) {
    showToast('មិនអាចបង្កើតតំណភ្ជាប់បានទេ', 'error')
    return
  }

  const link = `${window.location.origin}/parent/report/${inserted.id}`
  await navigator.clipboard.writeText(link)
  showToast('បានបង្កើត និងចម្លងតំណភ្ជាប់ថ្មី!', 'success')
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

watch([mode, selectedMonth, selectedSemester], fetchData)

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??'
}

function toKhmerNum(num) {
  if (num === null || num === undefined) return ''
  const khmerNums = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩']
  return num.toString().replace(/\d/g, d => khmerNums[d])
}
</script>

<template>
  <div class="ranking-view">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header no-print">
      <div style="display:flex; align-items:center; gap:16px;">
        <button class="btn btn-ghost btn-sm btn-icon" @click="router.back()">
          <ChevronLeftIcon class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">ចំណាត់ថ្នាក់សិស្ស</h1>
          <p class="page-subtitle" v-if="classInfo">
           <strong>{{ classInfo.class_name }}</strong> {{ classInfo.academic_years?.year_name }}
          </p>
        </div>
      </div>
      
      <div class="page-actions">
        <div v-if="!route.query.mode" class="mode-toggle">
          <button 
            class="toggle-btn" 
            :class="{ active: mode === 'monthly' }"
            @click="mode = 'monthly'"
          >
            ប្រចាំខែ
          </button>
          <button 
            class="toggle-btn" 
            :class="{ active: mode === 'semester' }"
            @click="mode = 'semester'"
          >
            ឆមាស
          </button>
        </div>
        <div v-else style="background:var(--primary-700); color:white; padding:6px 16px; border-radius:20px; font-size:12px; font-weight:700; white-space:nowrap;">
          {{ mode === 'monthly' ? 'របាយការណ៍ប្រចាំខែ' : 'របាយការណ៍ឆមាស' }}
        </div>
        <button 
          v-if="classInfo"
          class="btn btn-secondary btn-action" 
          @click="generateReportLink"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>
          </svg>
          <span class="btn-label">បង្កើតតំណភ្ជាប់</span>
        </button>

        <button 
          v-if="rankedList.length > 0"
          class="btn btn-secondary btn-action" 
          @click="router.push(`/teacher/scores/certificates?mode=${mode}&month=${selectedMonth}&semester=${selectedSemester}`)"
        >
          <AcademicCapIcon class="w-4 h-4" />
          <span class="btn-label">លិខិតសរសើរ</span>
        </button>
        <button
          class="btn btn-secondary btn-action"
          @click="handleNavigateToHonorBoard"
          :disabled="loading || exporting || rankedList.length === 0"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
          </svg>
          <span class="btn-label">តារាងកិត្តិយស</span>
        </button>
        <button class="btn btn-primary btn-action" @click="handleExport" :disabled="loading || exporting || rankedList.length === 0">
          <span v-if="exporting" class="spinner" />
          <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
          </svg>
          <span class="btn-label">{{ exporting ? 'កំពុងបង្កើត...' : 'ទាញយក PDF' }}</span>
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div v-if="!route.query.mode" class="card filters-card" style="margin-bottom:24px;">
      <div class="card-body" style="display:flex; gap:16px; align-items:flex-end;">
        <div v-if="mode === 'monthly'" class="form-group" style="width:200px;">
          <label class="form-label">ជ្រើសរើសខែ</label>
          <select class="form-select" v-model="selectedMonth">
            <option v-for="m in months" :key="m.id" :value="m.id">{{ m.name }}</option>
          </select>
        </div>
        <div v-else class="form-group" style="width:240px;">
          <label class="form-label">ជ្រើសរើសឆមាស</label>
          <select class="form-select" v-model="selectedSemester">
            <option value="" disabled>ជ្រើសរើសឆមាស</option>
            <option v-for="opt in semesterOptions" :key="opt.semester" :value="opt.semester">{{ opt.label }}</option>
          </select>
        </div>
        <div class="stat-info">
          <UserGroupIcon class="w-5 h-5 text-gray-400" />
          <span>សិស្សសរុប៖ {{ students.length }} នាក់</span>
        </div>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:500px; border-radius:12px;"></div>
    </div>

    <div v-else-if="rankedList.length === 0" class="empty-state">
      <StarIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">មិនទាន់មានទិន្នន័យពិន្ទុសម្រាប់បង្ហាញចំណាត់ថ្នាក់</p>
    </div>

    <div v-else>
      <!-- Summary Tiles Group 1 -->
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

      <!-- Range Distribution Group 2 -->
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

      <div class="print-only" style="text-align:center; margin-bottom:24px;">
        <h2 style="font-size:24px; font-weight:800;">ចំណាត់ថ្នាក់សិស្សប្រចាំ{{ mode === 'monthly' ? 'ខែ' : 'ឆមាស' }}</h2>
        <div style="display:flex; justify-content:center; gap:24px; margin-top:8px; color:#475569;">
          <span>ថ្នាក់៖ {{ classInfo.class_name }}</span>
          <span>{{ mode === 'monthly' ? 'ខែ៖ ' + months.find(m => m.id === selectedMonth)?.name : 'ឆមាសទី៖ ' + selectedSemester }}</span>
          <span>ឆ្នាំសិក្សា៖ {{ classInfo.academic_years?.year_name }}</span>
        </div>
      </div>

      <!-- Ranking Table -->
      <div class="card ranking-card">
        <div class="table-wrapper">
          <table class="ranking-table">
            <thead>
              <tr>
                <th style="width:60px; text-align:center;">ល.រ</th>
                <th>ឈ្មោះសិស្ស</th>
                <th style="text-align:center; width:100px;">ភេទ</th>
                <th style="text-align:center; width:150px;">មធ្យមភាគ</th>
                <th style="text-align:center; width:80px;">កម្រិត</th>
                <th style="text-align:center; width:100px; color:var(--danger-color);">ចំណាត់ថ្នាក់</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(student, idx) in rankedList" :key="student.id" :class="{ 'top-row': student.rank <= 3 }">
                <td style="text-align:center; font-weight:700;">{{ idx + 1 }}</td>
                <td>
                  <div style="display:flex; align-items:center; gap:12px;">
                    <div class="mini-avatar" :style="{ background: student.gender === 'female' ? '#ec4899' : '#3b82f6' }">
                      {{ initials(student.full_name) }}
                    </div>
                    <span style="font-weight:700;">{{ student.full_name }}</span>
                  </div>
                </td>
                <td style="text-align:center;">
                  <span class="gender-badge" :class="student.gender">
                    {{ student.gender === 'female' ? 'ស្រី' : 'ប្រុស' }}
                  </span>
                </td>
                <td>
                  <div class="avg-cell">
                    <span class="avg-val">{{ student.average }}</span>
                    <div class="progress-bar-wrap">
                      <div class="progress-fill" :class="'bg-' + getGrade(student.average)" :style="{ width: (student.average * 10) + '%' }"></div>
                    </div>
                  </div>
                </td>
                <td style="text-align:center;">
                  <span class="grade-chip" :class="'chip-' + getGrade(student.average)">
                    {{ getGrade(student.average) }}
                  </span>
                </td>
                <td style="text-align:center;">
                  <div class="rank-circle" :class="'rank-' + student.rank">{{ toKhmerNum(student.rank) }}</div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ranking-view {
  max-width: 1200px;
  margin: 0 auto;
}

.mode-toggle {
  display: flex;
  background: #e2e8f0;
  padding: 4px;
  border-radius: 12px;
}

.toggle-btn {
  padding: 8px 20px;
  border-radius: 8px;
  border: none;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
  background: transparent;
  color: #475569;
}

.toggle-btn.active {
  background: white;
  color: var(--primary-color);
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.stat-info-simple {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #475569;
  font-size: 14px;
}

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

.gender-badge {
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 700;
}
.gender-badge.female { background: #fdf2f8; color: #db2777; }
.gender-badge.male { background: #eff6ff; color: #2563eb; }

.avg-cell { display: flex; flex-direction: column; gap: 4px; padding: 4px 0; }
.avg-val { font-weight: 800; font-size: 14px; }
.progress-bar-wrap { height: 6px; background: #e2e8f0; border-radius: 3px; overflow: hidden; width: 100%; }
.progress-fill { height: 100%; border-radius: 3px; }

.bg-A { background: #10b981; }
.bg-B { background: #3b82f6; }
.bg-C { background: #f59e0b; }
.bg-D { background: #fbbf24; }
.bg-E { background: #f97316; }
.bg-F { background: #94a3b8; }

.grade-chip { padding: 4px 8px; border-radius: 4px; font-weight: 800; font-size: 11px; }
.chip-A { background: #dcfce7; color: #15803d; }
.chip-B { background: #dbeafe; color: #1d4ed8; }
.chip-C { background: #fef3c7; color: #b45309; }
.chip-D { background: #fef9c3; color: #a16207; }
.chip-E { background: #ffedd5; color: #c2410c; }
.chip-F { background: #f1f5f9; color: #475569; }

.ranking-table th {
  padding: 12px;
  font-size: 12px;
  background: #f8fafc;
  color: #475569;
  text-transform: none;
  letter-spacing: 0;
}

.ranking-table td {
  padding: 12px;
  border-bottom: 1px solid #f1f5f9;
}

.mini-avatar {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 12px;
  color: white;
}

.rank-circle {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 14px;
  background: #f1f5f9;
  color: #475569;
}

.rank-1 { background: #fef3c7; color: #b45309; border: 2px solid #fbbf24; }
.rank-2 { background: #f1f5f9; color: #475569; border: 2px solid #94a3b8; }
.rank-3 { background: #ffedd5; color: #9a3412; border: 2px solid #d97706; }

.btn-view {
  background: #3b82f6;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
}

.btn-view:hover { background: #2563eb; }

.print-only { display: none; }
@media print {
  .no-print { display: none !important; }
  .print-only { display: block !important; }
  .ranking-view { padding: 20px; }
}

@media (max-width: 768px) {
  .grade-grid { grid-template-columns: repeat(3, 1fr); }
  .tiles-row { grid-template-columns: 1fr; }
}

.page-actions {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
}

.btn-action .btn-label {
  display: inline;
}

@media (max-width: 900px) {
  .page-actions {
    gap: 6px;
  }
  .btn-action {
    padding: 6px 10px;
    font-size: 12px;
  }
  .btn-action .btn-label {
    display: none;
  }
}
</style>
