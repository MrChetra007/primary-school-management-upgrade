<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
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
import { generateMonthlyScorePDF } from '@/utils/exportPdf'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const loading = ref(true)
const classInfo = ref(null)
const students = ref([])
const subjects = ref([])
const rawScores = ref([])
const rankedList = ref([])
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
    
    await fetchData()
  }
  loading.value = false
}

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
    const [examRes, monthRes] = await Promise.all([
      supabase.from('scores').select('*').in('student_id', studentIds).eq('semester', selectedSemester.value).eq('score_type', 'semester'),
      supabase.from('scores').select('*').in('student_id', studentIds).in('month', semesterMonths.value).eq('score_type', 'monthly')
    ])
    
    const semesterMonthlyScores = monthRes.data || []
    const semesterExamScores = examRes.data || []
    calculateSemesterRanking(semesterMonthlyScores, semesterExamScores)
  }

  loading.value = false
}

function calculateMonthlyRanking() {
  const list = students.value.map(student => {
    const scores = rawScores.value.filter(s => s.student_id === student.id).map(s => ({ score: s.score }))
    return {
      id: student.id,
      full_name: student.full_name,
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
      average: computeSemesterAverage(mAvgs, examAvg)
    }
  })
  rankedList.value = computeRank(list).sort((a, b) => a.rank - b.rank)
}

const printArea = ref(null)
async function handleExport() {
  if (!printArea.value) return
  const metadata = {
    schoolName: 'សាលាបឋមសិក្សា',
    className: classInfo.value?.class_name,
    month: mode.value === 'monthly' ? months.find(m => m.id === selectedMonth.value)?.name : `ឆមាសទី ${selectedSemester.value}`,
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

watch([mode, selectedMonth, selectedSemester], fetchData)

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??'
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
            ថ្នាក់ <strong>{{ classInfo.class_name }}</strong> — {{ classInfo.academic_years?.year_name }}
          </p>
        </div>
      </div>
      
      <div style="display:flex; gap:12px; align-items:center;">
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
        <div v-else style="background:var(--primary-700); color:white; padding:6px 16px; border-radius:20px; font-size:12px; font-weight:700;">
          {{ mode === 'monthly' ? 'របាយការណ៍ប្រចាំខែ' : 'របាយការណ៍ឆមាស' }}
        </div>
        <button 
          v-if="rankedList.length > 0"
          class="btn btn-secondary" 
          @click="router.push(`/teacher/scores/certificates?mode=${mode}&month=${selectedMonth}&semester=${selectedSemester}`)"
        >
          <AcademicCapIcon class="w-4 h-4 mr-2" />
          បង្កើតលិខិតសរសើរ (Top 5)
        </button>
        <button class="btn btn-primary" @click="handleExport" :disabled="loading || rankedList.length === 0">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
          </svg>
          ទាញយក PDF
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
            <option :value="1">ឆមាសទី១ (ខែ ១-៣)</option>
            <option :value="2">ឆមាសទី២ (ខែ ៤-៦)</option>
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

    <div v-else ref="printArea">
      <div class="print-only" style="text-align:center; margin-bottom:24px;">
        <h2 style="font-size:24px; font-weight:800;">ចំណាត់ថ្នាក់សិស្សប្រចាំ{{ mode === 'monthly' ? 'ខែ' : 'ឆមាស' }}</h2>
        <div style="display:flex; justify-content:center; gap:24px; margin-top:8px; color:#475569;">
          <span>ថ្នាក់៖ {{ classInfo.class_name }}</span>
          <span>{{ mode === 'monthly' ? 'ខែ៖ ' + months.find(m => m.id === selectedMonth)?.name : 'ឆមាសទី៖ ' + selectedSemester }}</span>
          <span>ឆ្នាំសិក្សា៖ {{ classInfo.academic_years?.year_name }}</span>
        </div>
      </div>
      <!-- Top 3 Podium -->
      <div class="podium">
        <!-- Rank 2 -->
        <div v-if="rankedList[1]" class="podium-item second">
          <div class="avatar-wrap">
            <div class="avatar">{{ initials(rankedList[1].full_name) }}</div>
            <div class="badge-rank">2</div>
          </div>
          <div class="podium-info">
            <div class="name">{{ rankedList[1].full_name }}</div>
            <div class="score">{{ rankedList[1].average }}</div>
          </div>
          <div class="step"></div>
        </div>

        <!-- Rank 1 -->
        <div v-if="rankedList[0]" class="podium-item first">
          <TrophyIcon class="w-8 h-8 trophy-gold" />
          <div class="avatar-wrap">
            <div class="avatar">{{ initials(rankedList[0].full_name) }}</div>
            <div class="badge-rank">1</div>
          </div>
          <div class="podium-info">
            <div class="name">{{ rankedList[0].full_name }}</div>
            <div class="score">{{ rankedList[0].average }}</div>
          </div>
          <div class="step"></div>
        </div>

        <!-- Rank 3 -->
        <div v-if="rankedList[2]" class="podium-item third">
          <div class="avatar-wrap">
            <div class="avatar">{{ initials(rankedList[2].full_name) }}</div>
            <div class="badge-rank">3</div>
          </div>
          <div class="podium-info">
            <div class="name">{{ rankedList[2].full_name }}</div>
            <div class="score">{{ rankedList[2].average }}</div>
          </div>
          <div class="step"></div>
        </div>
      </div>

      <!-- Ranking List -->
      <div class="card ranking-card">
        <div class="table-wrapper">
          <table class="ranking-table">
            <thead>
              <tr>
                <th style="width:80px;">ចំណាត់ថ្នាក់</th>
                <th>ឈ្មោះសិស្ស</th>
                <th style="text-align:right;">មធ្យមភាគ</th>
                <th style="width:120px; text-align:center;">ស្ថានភាព</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="student in rankedList" :key="student.id" :class="{ 'top-row': student.rank <= 3 }">
                <td class="rank-col">
                  <div class="rank-circle" :class="'rank-' + student.rank">
                    {{ student.rank }}
                  </div>
                </td>
                <td class="name-col">
                  <div style="display:flex; align-items:center; gap:12px;">
                    <div class="mini-avatar">{{ initials(student.full_name) }}</div>
                    <span>{{ student.full_name }}</span>
                  </div>
                </td>
                <td class="score-col">{{ student.average }}</td>
                <td style="text-align:center;">
                  <span class="badge" :class="student.average >= 50 ? 'badge-green' : 'badge-red'">
                    {{ student.average >= 50 ? 'ជាប់' : 'ធ្លាក់' }}
                  </span>
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
  max-width: 900px;
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

.stat-info {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #475569;
  font-size: 14px;
  margin-bottom: 4px;
}

/* Podium Styles */
.podium {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 12px;
  margin: 40px 0;
  height: 280px;
}

.podium-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 160px;
}

.avatar-wrap {
  position: relative;
  margin-bottom: 12px;
}

.avatar {
  width: 70px;
  height: 70px;
  background: #f1f5f9;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 24px;
  border: 4px solid white;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.first .avatar {
  width: 90px;
  height: 90px;
  border-color: #fbbf24;
  font-size: 32px;
}

.second .avatar { border-color: #94a3b8; }
.third .avatar { border-color: #b45309; }

.badge-rank {
  position: absolute;
  bottom: -4px;
  right: -4px;
  width: 28px;
  height: 28px;
  background: #1e293b;
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 800;
  border: 2px solid white;
}

.first .badge-rank { background: #fbbf24; }

.podium-info {
  text-align: center;
  margin-bottom: 8px;
}

.podium-info .name {
  font-weight: 800;
  font-size: 14px;
  color: #1e293b;
}

.podium-info .score {
  font-weight: 800;
  font-size: 20px;
  color: var(--primary-700);
}

.step {
  width: 100%;
  background: white;
  border-radius: 12px 12px 0 0;
  box-shadow: 0 -4px 12px rgba(0,0,0,0.05);
}

.first .step { height: 120px; background: linear-gradient(to top, #fef3c7, white); }
.second .step { height: 80px; background: linear-gradient(to top, #f1f5f9, white); }
.third .step { height: 50px; background: linear-gradient(to top, #ffedd5, white); }

.trophy-gold { color: #fbbf24; margin-bottom: 8px; }

/* Table Styles */
.ranking-table {
  width: 100%;
  border-collapse: collapse;
}

.ranking-table th {
  padding: 16px;
  text-align: left;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #475569;
  border-bottom: 1px solid #f1f5f9;
}

.ranking-table td {
  padding: 16px;
  border-bottom: 1px solid #f8fafc;
}

.top-row {
  background: #f8fafc;
}

.rank-col {
  text-align: center;
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

.mini-avatar {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--primary-color);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 700;
}

.score-col {
  text-align: right;
  font-weight: 800;
  font-size: 16px;
  color: var(--text-primary);
}

.print-only { display: none; }
@media print {
  .no-print { display: none !important; }
  .print-only { display: block !important; }
  .ranking-view { padding: 20px; }
}
</style>
