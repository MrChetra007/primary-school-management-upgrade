<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { 
  ScaleIcon, 
  ArrowTrendingUpIcon,
  InformationCircleIcon
} from '@heroicons/vue/24/outline'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js'
import { Line } from 'vue-chartjs'

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
)

const route = useRoute()
const studentId = route.params.id
const loading = ref(true)
const growthData = ref([])

onMounted(fetchGrowth)

async function fetchGrowth() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('student_growth')
      .select('*')
      .eq('student_id', studentId)
      .order('date', { ascending: true })

    if (error) throw error
    growthData.value = data || []
  } catch (err) {
    console.error('Error fetching growth data:', err)
  } finally {
    loading.value = false
  }
}

const chartData = computed(() => ({
  labels: growthData.value.map(d => formatDate(d.date)),
  datasets: [
    {
      label: 'កម្ពស់ (cm)',
      backgroundColor: '#3b82f6',
      borderColor: '#3b82f6',
      data: growthData.value.map(d => d.height),
      tension: 0.3
    },
    {
      label: 'ទម្ងន់ (kg)',
      backgroundColor: '#10b981',
      borderColor: '#10b981',
      data: growthData.value.map(d => d.weight),
      tension: 0.3
    }
  ]
}))

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        font: { family: 'Hanuman' }
      }
    }
  },
  scales: {
    y: {
      beginAtZero: false
    }
  }
}

const latestRecord = computed(() => {
  if (growthData.value.length === 0) return null
  return growthData.value[growthData.value.length - 1]
})
</script>

<template>
  <div class="growth-view">
    <div class="view-header">
      <div class="header-main">
        <div class="icon-circle">
          <ScaleIcon class="w-6 h-6 text-primary-500" />
        </div>
        <div>
          <h2 class="view-title">កំណើនកាយសិស្ស</h2>
          <p class="view-subtitle">តាមដានកម្ពស់ និងទម្ងន់របស់កូនអ្នក</p>
        </div>
      </div>
    </div>

    <!-- Summary Cards -->
    <div v-if="latestRecord" class="growth-stats">
      <div class="card stat-card">
        <div class="stat-icon bg-blue-light">
          <ArrowTrendingUpIcon class="w-6 h-6 text-blue-600" />
        </div>
        <div class="stat-content">
          <span class="label">កម្ពស់បច្ចុប្បន្ន</span>
          <div class="value-row">
            <span class="value">{{ latestRecord.height }}</span>
            <span class="unit">cm</span>
          </div>
        </div>
      </div>
      <div class="card stat-card">
        <div class="stat-icon bg-green-light">
          <ScaleIcon class="w-6 h-6 text-green-600" />
        </div>
        <div class="stat-content">
          <span class="label">ទម្ងន់បច្ចុប្បន្ន</span>
          <div class="value-row">
            <span class="value">{{ latestRecord.weight }}</span>
            <span class="unit">kg</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Chart -->
    <div class="card mt-6">
      <div class="card-header">
        <h3 class="card-title">ក្រាហ្វបង្ហាញពីកំណើនកាយ</h3>
      </div>
      <div class="card-body">
        <div v-if="loading" class="chart-container padded">
          <div class="skeleton full-height"></div>
        </div>
        <div v-else-if="growthData.length < 2" class="empty-mini padded">
          ត្រូវមានទិន្នន័យយ៉ាងតិច ២ ដើម្បីបង្ហាញក្រាហ្វ
        </div>
        <div v-else class="chart-container">
          <Line :data="chartData" :options="chartOptions" />
        </div>
      </div>
    </div>

    <!-- History Table -->
    <div class="card mt-6">
      <div class="card-header">
        <h3 class="card-title">ប្រវត្តិពិនិត្យកន្លងមក</h3>
      </div>
      <div class="table-wrapper">
        <table v-if="growthData.length > 0">
          <thead>
            <tr>
              <th>កាលបរិច្ឆេទ</th>
              <th>កម្ពស់ (cm)</th>
              <th>ទម្ងន់ (kg)</th>
              <th>BMI</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="record in [...growthData].reverse()" :key="record.id">
              <td>{{ formatDate(record.date) }}</td>
              <td class="font-bold">{{ record.height }}</td>
              <td class="font-bold">{{ record.weight }}</td>
              <td>
                <span class="badge badge-gray">
                  {{ (record.weight / Math.pow(record.height / 100, 2)).toFixed(1) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-mini padded">មិនទាន់មានទិន្នន័យ</div>
      </div>
    </div>

    <div class="info-note mt-4">
      <InformationCircleIcon class="w-5 h-5" />
      <p>ទិន្នន័យនេះត្រូវបានកត់ត្រាជារៀងរាល់ឆមាស ឬតាមការកំណត់របស់សាលារៀន។</p>
    </div>
  </div>
</template>

<style scoped>
.growth-view {
  animation: fadeIn 0.4s ease;
}

.view-header {
  margin-bottom: 24px;
}

.header-main {
  display: flex;
  align-items: center;
  gap: 16px;
}

.icon-circle {
  width: 48px;
  height: 48px;
  background: var(--primary-50);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.view-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary);
}

.view-subtitle {
  font-size: 13px;
  color: var(--text-secondary);
}

.growth-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.stat-card {
  padding: 24px;
  display: flex;
  align-items: center;
  gap: 20px;
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.bg-blue-light { background: #eff6ff; }
.bg-green-light { background: #ecfdf5; }

.stat-content {
  display: flex;
  flex-direction: column;
}

.stat-content .label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
}

.value-row {
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.value-row .value {
  font-size: 32px;
  font-weight: 800;
  color: var(--text-primary);
}

.value-row .unit {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-muted);
}

.chart-container {
  height: 300px;
  position: relative;
}

.padded { padding: 20px; }
.full-height { height: 100%; }
.font-bold { font-weight: 700; }

.info-note {
  display: flex;
  gap: 10px;
  background: #f8fafc;
  padding: 16px;
  border-radius: 12px;
  border: 1px solid var(--border-default);
}

.info-note svg {
  flex-shrink: 0;
  color: var(--primary-500);
}

.info-note p {
  font-size: 13px;
  color: var(--text-secondary);
}

@media (max-width: 640px) {
  .growth-stats { grid-template-columns: 1fr; }
}
</style>
