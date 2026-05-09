<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { 
  DocumentChartBarIcon, 
  FunnelIcon,
  AcademicCapIcon,
  InformationCircleIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const loading = ref(true)
const scores = ref([])
const activeTab = ref('monthly') // 'monthly' or 'semester'

const filterMonth = ref(new Date().getMonth() + 1)
const filterSemester = ref(1)

const months = [
  { val: 10, label: 'តុលា' },
  { val: 11, label: 'វិច្ឆិកា' },
  { val: 12, label: 'ធ្នូ' },
  { val: 1, label: 'មករា' },
  { val: 2, label: 'កុម្ភៈ' },
  { val: 3, label: 'មីនា' },
  { val: 4, label: 'មេសា' },
  { val: 5, label: 'ឧសភា' },
  { val: 6, label: 'មិថុនា' },
  { val: 7, label: 'កក្កដា' },
]

onMounted(fetchScores)

async function fetchScores() {
  loading.value = true
  try {
    let query = supabase
      .from('scores')
      .select('*, subjects(subject_name)')
      .eq('student_id', studentId)
      .eq('score_type', activeTab.value)

    if (activeTab.value === 'monthly') {
      query = query.eq('month', filterMonth.value)
    } else {
      query = query.eq('semester', filterSemester.value)
    }

    const { data, error } = await query.order('created_at', { ascending: true })
    if (error) throw error
    scores.value = data || []
  } catch (err) {
    console.error('Error fetching scores:', err)
  } finally {
    loading.value = false
  }
}

function setTab(tab) {
  activeTab.value = tab
  fetchScores()
}

const averageScore = computed(() => {
  if (scores.value.length === 0) return 0
  const sum = scores.value.reduce((acc, curr) => acc + curr.score, 0)
  return (sum / scores.value.length).toFixed(2)
})

const getGrade = (score) => {
  if (score >= 90) return { label: 'A', class: 'grade-a' }
  if (score >= 80) return { label: 'B', class: 'grade-b' }
  if (score >= 70) return { label: 'C', class: 'grade-c' }
  if (score >= 60) return { label: 'D', class: 'grade-d' }
  if (score >= 50) return { label: 'E', class: 'grade-e' }
  return { label: 'F', class: 'grade-f' }
}
</script>

<template>
  <div class="scores-view">
    <div class="view-header">
      <div class="header-main">
        <div class="icon-circle">
          <DocumentChartBarIcon class="w-6 h-6 text-primary-500" />
        </div>
        <div>
          <h2 class="view-title">ពិន្ទុសិក្សា</h2>
          <p class="view-subtitle">ពិនិត្យលទ្ធផលប្រឡងប្រចាំខែ និងឆមាស</p>
        </div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="score-tabs">
      <button 
        @click="setTab('monthly')" 
        class="score-tab" 
        :class="{ active: activeTab === 'monthly' }"
      >
        ប្រចាំខែ
      </button>
      <button 
        @click="setTab('semester')" 
        class="score-tab" 
        :class="{ active: activeTab === 'semester' }"
      >
        ប្រចាំឆមាស
      </button>
    </div>

    <!-- Filters -->
    <div class="filters-card card">
      <div class="filters-body">
        <div v-if="activeTab === 'monthly'" class="filter-group">
          <label>ជ្រើសរើសខែ</label>
          <select v-model="filterMonth" @change="fetchScores" class="form-select">
            <option v-for="m in months" :key="m.val" :val="m.val">{{ m.label }}</option>
          </select>
        </div>
        <div v-else class="filter-group">
          <label>ជ្រើសរើសឆមាស</label>
          <select v-model="filterSemester" @change="fetchScores" class="form-select">
            <option :value="1">ឆមាសទី ១</option>
            <option :value="2">ឆមាសទី ២</option>
          </select>
        </div>

        <div class="summary-pill">
          <span class="label">ពិន្ទុមធ្យមភាគ៖</span>
          <span class="value" :class="{ 'text-danger': averageScore < 50 }">{{ averageScore }}</span>
        </div>
      </div>
    </div>

    <!-- Scores Table -->
    <div class="card mt-6">
      <div v-if="loading" class="padded">
        <div v-for="i in 5" :key="i" class="skeleton list-skeleton"></div>
      </div>

      <div v-else-if="scores.length === 0" class="empty-mini padded">
        មិនមានទិន្នន័យពិន្ទុសម្រាប់កាលបរិច្ឆេទនេះទេ
      </div>

      <div v-else class="table-wrapper">
        <table class="scores-table">
          <thead>
            <tr>
              <th>មុខវិជ្ជា</th>
              <th>ពិន្ទុ</th>
              <th>និទ្ទេស</th>
              <th>លទ្ធផល</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="score in scores" :key="score.id">
              <td class="subject-cell">
                <AcademicCapIcon class="w-5 h-5 text-gray-400" />
                <span>{{ score.subjects?.subject_name }}</span>
              </td>
              <td>
                <span class="score-value" :class="{ 'low': score.score < 50 }">
                  {{ score.score }}
                </span>
              </td>
              <td>
                <span class="grade-badge" :class="getGrade(score.score).class">
                  {{ getGrade(score.score).label }}
                </span>
              </td>
              <td>
                <span class="badge" :class="score.score >= 50 ? 'badge-green' : 'badge-red'">
                  {{ score.score >= 50 ? 'ជាប់' : 'ធ្លាក់' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Footer Info -->
    <div class="info-note mt-4">
      <InformationCircleIcon class="w-5 h-5" />
      <p>និទ្ទេសត្រូវបានគណនាផ្អែកលើពិន្ទុសរុបក្នុងមុខវិជ្ជានីមួយៗ។ ប្រសិនបើមានចម្ងល់ សូមទាក់ទងមកសាលារៀន។</p>
    </div>
  </div>
</template>

<style scoped>
.scores-view {
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

.score-tabs {
  display: flex;
  background: var(--gray-100);
  padding: 4px;
  border-radius: 12px;
  margin-bottom: 20px;
}

.score-tab {
  flex: 1;
  padding: 10px;
  border: none;
  background: transparent;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.2s ease;
}

.score-tab.active {
  background: white;
  color: var(--primary-700);
  box-shadow: var(--shadow-sm);
}

.filters-body {
  padding: 16px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 12px;
}

.filter-group label {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
}

.form-select {
  padding: 8px 32px 8px 12px;
  border-radius: 10px;
  border: 1px solid var(--border-default);
  background-color: white;
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
}

.summary-pill {
  background: var(--primary-50);
  padding: 8px 16px;
  border-radius: 99px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.summary-pill .label {
  font-size: 13px;
  font-weight: 600;
  color: var(--primary-700);
}

.summary-pill .value {
  font-size: 18px;
  font-weight: 800;
  color: var(--primary-700);
}

.scores-table th {
  background: var(--gray-50);
  padding: 12px 20px;
  font-size: 12px;
  text-align: left;
  color: var(--text-muted);
}

.scores-table td {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border-default);
}

.subject-cell {
  display: flex;
  align-items: center;
  gap: 12px;
  font-weight: 700;
  color: var(--text-primary);
}

.score-value {
  font-size: 18px;
  font-weight: 800;
  color: var(--primary-700);
}

.score-value.low { color: var(--color-danger); }

.grade-badge {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  font-weight: 800;
  font-size: 14px;
}

.grade-a { background: #dcfce7; color: #166534; }
.grade-b { background: #ecfdf5; color: #065f46; }
.grade-c { background: #fef9c3; color: #854d0e; }
.grade-d { background: #fff7ed; color: #9a3412; }
.grade-e { background: #fff1f2; color: #9f1239; }
.grade-f { background: #fef2f2; color: #991b1b; }

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
  line-height: 1.5;
}

.padded { padding: 20px; }
.list-skeleton { height: 50px; margin-bottom: 12px; border-radius: 8px; }

@media (max-width: 768px) {
  .filters-body { flex-direction: column; align-items: stretch; gap: 16px; }
  .summary-pill { justify-content: center; }
  .subject-cell span { font-size: 14px; }
}
</style>
