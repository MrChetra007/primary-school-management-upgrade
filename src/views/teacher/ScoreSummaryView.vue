<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAcademicYearStore } from '@/stores/academicYear'
import { Radar } from 'vue-chartjs'
import {
  Chart as ChartJS,
  RadialLinearScale,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
  Legend
} from 'chart.js'
import { ChevronLeftIcon } from '@heroicons/vue/24/outline'

ChartJS.register(RadialLinearScale, PointElement, LineElement, Filler, Tooltip, Legend)

const route = useRoute()
const router = useRouter()
const academicYearStore = useAcademicYearStore()

const student = ref(null)
const subjects = ref([])
const scores = ref([])
const loading = ref(true)
const mode = ref(route.query.mode || 'monthly')
const month = ref(Number(route.query.month))
const semester = ref(Number(route.query.semester))

const chartData = ref(null)
const chartOptions = ref(null)

const months = [
  { id: 1, name: 'មករា' }, { id: 2, name: 'កុម្ភៈ' }, { id: 3, name: 'មីនា' },
  { id: 4, name: 'មេសា' }, { id: 5, name: 'ឧសភា' }, { id: 6, name: 'មិថុនា' },
  { id: 7, name: 'កក្កដា' }, { id: 8, name: 'សីហា' }, { id: 9, name: 'កញ្ញា' },
  { id: 10, name: 'តុលា' }, { id: 11, name: 'វិច្ឆិកា' }, { id: 12, name: 'ធ្នូ' }
]

onMounted(async () => {
  await loadData()
})

async function loadData() {
  const studentId = route.params.id
  if (!studentId) {
    loading.value = false
    return
  }

  const { data: stu } = await supabase
    .from('students')
    .select('*, classes!inner(class_name)')
    .eq('id', studentId)
    .single()
  student.value = stu

  if (!stu) {
    loading.value = false
    return
  }

  const { data: subData } = await supabase
    .from('class_subjects')
    .select('subjects(*)')
    .eq('class_id', stu.class_id)
  subjects.value = subData?.map(s => s.subjects) || []

  let query = supabase
    .from('scores')
    .select('*')
    .eq('student_id', studentId)
    .eq('academic_year_id', academicYearStore.academicYearId)

  if (mode.value === 'monthly') {
    query = query.eq('month', month.value).eq('score_type', 'monthly')
  } else {
    query = query.eq('semester', semester.value).eq('score_type', 'semester')
  }

  const { data: scoreData } = await query
  scores.value = scoreData || []

  buildChart()
  loading.value = false
}

function buildChart() {
  const labels = subjects.value.map(s => s.subject_name)
  const data = subjects.value.map(sub => {
    const score = scores.value.find(s => s.subject_id === sub.id)
    return score ? Number(score.score) : 0
  })

  const maxScore = Math.max(...data, 10)
  const suggestedMax = Math.ceil(maxScore / 0.5) * 0.5

  chartData.value = {
    labels,
    datasets: [{
      label: student.value?.full_name || '',
      data,
      backgroundColor: 'rgba(59, 130, 246, 0.2)',
      borderColor: '#3b82f6',
      borderWidth: 2,
      pointBackgroundColor: '#3b82f6',
      pointBorderColor: '#fff',
      pointHoverRadius: 6,
      pointRadius: 4
    }]
  }

  chartOptions.value = {
    responsive: true,
    maintainAspectRatio: true,
    scales: {
      r: {
        beginAtZero: true,
        max: Math.max(suggestedMax, 10),
        ticks: {
          stepSize: 1,
          font: { size: 11 }
        },
        pointLabels: {
          font: { size: 13, weight: 'bold' }
        }
      }
    },
    plugins: {
      legend: {
        position: 'bottom',
        labels: { font: { size: 13, weight: 'bold' } }
      },
      tooltip: {
        callbacks: {
          label: (ctx) => `${ctx.label}: ${ctx.raw}`
        }
      }
    }
  }
}

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??'
}
</script>

<template>
  <div class="summary-view">
    <div class="page-header">
      <div style="display:flex; align-items:center; gap:16px;">
        <button class="btn btn-ghost btn-sm btn-icon" @click="router.back()">
          <ChevronLeftIcon class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">សង្ខេបពិន្ទុសិស្ស</h1>
          <p class="page-subtitle" v-if="student">
            <strong>{{ student.full_name }}</strong>
            — ថ្នាក់ {{ student.classes?.class_name }}
            — {{ mode === 'monthly' ? months.find(m => m.id === month.value)?.name : 'ឆមាសទី' + semester.value }}
          </p>
        </div>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:500px; border-radius:12px;"></div>
    </div>

    <div v-else-if="!student" class="empty-state">
      <p>រកមិនឃើញសិស្ស</p>
    </div>

    <div v-else class="chart-card">
      <div class="chart-header">
        <div class="student-info">
          <div class="mini-avatar" :class="(student.gender || '').toLowerCase()">
            {{ initials(student.full_name) }}
          </div>
          <div>
            <h3>{{ student.full_name }}</h3>
            <span class="class-label">ថ្នាក់ {{ student.classes?.class_name }}</span>
          </div>
        </div>
        <div class="context-badge">
          {{ mode === 'monthly' ? 'ប្រចាំខែ' : 'ឆមាស' }} —
          {{ mode === 'monthly' ? months.find(m => m.id === month.value)?.name : 'ទី១' }}
        </div>
      </div>

      <div class="chart-wrapper" v-if="chartData && subjects.length > 0">
        <Radar :data="chartData" :options="chartOptions" />
      </div>

      <div v-else class="empty-chart">
        <p>មិនទាន់មានទិន្នន័យពិន្ទុ</p>
      </div>

      <div class="scores-table" v-if="subjects.length > 0">
        <table>
          <thead>
            <tr>
              <th>មុខវិជ្ជា</th>
              <th style="text-align:center; width:100px;">ពិន្ទុ</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="sub in subjects" :key="sub.id">
              <td>{{ sub.subject_name }}</td>
              <td style="text-align:center;">
                <span class="score-chip" :class="'score-' + ((scores.find(s => s.subject_id === sub.id)?.score || 0) >= 5 ? 'pass' : 'fail')">
                  {{ scores.find(s => s.subject_id === sub.id)?.score ?? '-' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.summary-view {
  max-width: 900px;
  margin: 0 auto;
}

.chart-card {
  background: white;
  border-radius: 12px;
  border: 1px solid #e5e7eb;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  overflow: hidden;
}

.chart-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #f1f5f9;
}

.student-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.student-info h3 {
  font-size: 16px;
  font-weight: 700;
  margin: 0;
}

.class-label {
  font-size: 12px;
  color: #6b7280;
}

.mini-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 14px;
  color: white;
}

.mini-avatar.female {
  background: #ec4899;
}

.mini-avatar.male {
  background: #3b82f6;
}

.context-badge {
  background: #eff6ff;
  color: #1d4ed8;
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 700;
}

.chart-wrapper {
  padding: 32px;
  max-width: 600px;
  margin: 0 auto;
}

.empty-chart {
  padding: 60px;
  text-align: center;
  color: #94a3b8;
  font-weight: 700;
}

.scores-table {
  padding: 0 20px 20px;
}

.scores-table table {
  width: 100%;
  border-collapse: collapse;
}

.scores-table th {
  padding: 10px 12px;
  font-size: 12px;
  background: #f8fafc;
  color: #475569;
  text-align: left;
  border-bottom: 1px solid #e2e8f0;
}

.scores-table td {
  padding: 10px 12px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 14px;
}

.score-chip {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 6px;
  font-weight: 700;
  font-size: 13px;
}

.score-pass {
  background: #dcfce7;
  color: #15803d;
}

.score-fail {
  background: #fef2f2;
  color: #dc2626;
}
</style>
