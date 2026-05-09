<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { 
  QuestionMarkCircleIcon, 
  CalendarIcon, 
  AcademicCapIcon, 
  ScaleIcon,
  ChartBarIcon,
  ArrowRightIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const student = ref(null)
const loading = ref(true)
const attendance = ref({ present: 0, absent: 0, late: 0, permission: 0 })
const scores = ref([])
const growth = ref(null)

onMounted(loadData)

async function loadData() {
  loading.value = true
  try {
    // 1. Fetch Student Info
    const { data: stu } = await supabase
      .from('students')
      .select('*, classes(class_name)')
      .eq('id', studentId)
      .single()
    student.value = stu

    // 2. Fetch Attendance Summary
    const { data: att } = await supabase
      .from('student_attendances')
      .select('status')
      .eq('student_id', studentId)
    
    if (att) {
      attendance.value = att.reduce((acc, curr) => {
        if (acc[curr.status] !== undefined) acc[curr.status]++
        return acc
      }, { present: 0, absent: 0, late: 0, permission: 0 })
    }

    // 3. Fetch Recent Scores
    const { data: sc } = await supabase
      .from('scores')
      .select('*, subjects(subject_name)')
      .eq('student_id', studentId)
      .order('created_at', { ascending: false })
      .limit(5)
    scores.value = sc || []

    // 4. Fetch Latest Growth
    const { data: grow } = await supabase
      .from('student_growth')
      .select('*')
      .eq('student_id', studentId)
      .order('check_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    growth.value = grow

  } catch (err) {
    console.error('Error loading dashboard data:', err)
  } finally {
    loading.value = false
  }
}

const attendanceRate = computed(() => {
  const total = attendance.value.present + attendance.value.absent + attendance.value.late + attendance.value.permission
  if (total === 0) return 0
  return Math.round((attendance.value.present / total) * 100)
})
</script>

<template>
  <div class="dashboard-overview">
    <!-- Loading State -->
    <div v-if="loading" class="dashboard-grid">
      <div v-for="i in 3" :key="i" class="skeleton dashboard-card-skeleton"></div>
    </div>

    <!-- Empty State -->
    <div v-else-if="!student" class="empty-state">
      <QuestionMarkCircleIcon class="w-16 h-16 text-gray-300" />
      <h2 class="empty-state-title">មិនមានទិន្នន័យ</h2>
      <p class="empty-state-desc">យើងមិនអាចស្វែងរកព័ត៌មានសម្រាប់សិស្សនេះបានទេ។</p>
      <RouterLink to="/parent" class="btn btn-primary">ត្រឡប់ទៅការស្វែងរក</RouterLink>
    </div>

    <!-- Dashboard Content -->
    <div v-else class="dashboard-content">
      <div class="welcome-banner">
        <div class="banner-text">
          <h1>សួស្តី! មាតាបិតារបស់ {{ student.full_name }}</h1>
          <p>នេះគឺជាសេចក្តីសង្ខេបនៃវឌ្ឍនភាពសិក្សារបស់កូនអ្នកសម្រាប់ខែនេះ។</p>
        </div>
        <div class="banner-illustration">
          <AcademicCapIcon class="w-24 h-24 opacity-20" />
        </div>
      </div>

      <div class="dashboard-grid">
        <!-- Attendance Card -->
        <div class="card stat-summary-card">
          <div class="card-header">
            <div class="header-with-icon">
              <div class="icon-box bg-green">
                <CalendarIcon class="w-5 h-5" />
              </div>
              <h3 class="card-title">វត្តមានសរុប</h3>
            </div>
            <RouterLink :to="`/parent/student/${studentId}/attendance`" class="btn-link">
              មើលលម្អិត <ArrowRightIcon class="w-3 h-3" />
            </RouterLink>
          </div>
          <div class="card-body">
            <div class="attendance-viz">
              <div class="viz-circle">
                <span class="viz-value">{{ attendanceRate }}%</span>
                <span class="viz-label">អត្រាវត្តមាន</span>
              </div>
              <div class="viz-stats">
                <div class="viz-stat-item">
                  <span class="dot dot-green"></span>
                  <span class="label">មកសិក្សា:</span>
                  <span class="value">{{ attendance.present }}</span>
                </div>
                <div class="viz-stat-item">
                  <span class="dot dot-red"></span>
                  <span class="label">អវត្តមាន:</span>
                  <span class="value">{{ attendance.absent }}</span>
                </div>
                <div class="viz-stat-item">
                  <span class="dot dot-yellow"></span>
                  <span class="label">ច្បាប់:</span>
                  <span class="value">{{ attendance.permission }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Growth Card -->
        <div class="card stat-summary-card">
          <div class="card-header">
            <div class="header-with-icon">
              <div class="icon-box bg-blue">
                <ScaleIcon class="w-5 h-5" />
              </div>
              <h3 class="card-title">កំណើនកាយចុងក្រោយ</h3>
            </div>
            <RouterLink :to="`/parent/student/${studentId}/growth`" class="btn-link">
              មើលលម្អិត <ArrowRightIcon class="w-3 h-3" />
            </RouterLink>
          </div>
          <div class="card-body">
            <div v-if="growth" class="growth-summary">
              <div class="growth-stat">
                <span class="label">កម្ពស់</span>
                <span class="value">{{ growth.height_cm }} <small>cm</small></span>
              </div>
              <div class="growth-stat">
                <span class="label">ទម្ងន់</span>
                <span class="value">{{ growth.weight_kg }} <small>kg</small></span>
              </div>
              <div class="growth-date">
                ពិនិត្យចុងក្រោយនៅថ្ងៃទី {{ formatDate(growth.check_date) }}
              </div>
            </div>
            <div v-else class="empty-mini">
              មិនទាន់មានទិន្នន័យកំណើនកាយនៅឡើយ
            </div>
          </div>
        </div>

        <!-- Recent Scores Card -->
        <div class="card stat-summary-card full-width">
          <div class="card-header">
            <div class="header-with-icon">
              <div class="icon-box bg-purple">
                <ChartBarIcon class="w-5 h-5" />
              </div>
              <h3 class="card-title">លទ្ធផលសិក្សាចុងក្រោយ</h3>
            </div>
            <RouterLink :to="`/parent/student/${studentId}/scores`" class="btn-link">
              មើលទាំងអស់ <ArrowRightIcon class="w-3 h-3" />
            </RouterLink>
          </div>
          <div class="card-body no-padding">
            <div v-if="scores.length > 0" class="mini-table-wrapper">
              <table class="mini-table">
                <thead>
                  <tr>
                    <th>មុខវិជ្ជា</th>
                    <th>ប្រភេទ</th>
                    <th>ពិន្ទុ</th>
                    <th>ស្ថានភាព</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="score in scores" :key="score.id">
                    <td class="font-bold">{{ score.subjects?.subject_name }}</td>
                    <td>{{ score.score_type === 'monthly' ? 'ប្រចាំខែ' : 'ឆមាស' }}</td>
                    <td>
                      <span class="score-pill" :class="{ 'low': score.score < 50 }">
                        {{ score.score }}
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
            <div v-else class="empty-mini padded">
              មិនទាន់មានទិន្នន័យពិន្ទុនៅឡើយ
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-content {
  animation: fadeIn 0.4s ease;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.welcome-banner {
  background: linear-gradient(135deg, var(--primary-700) 0%, var(--primary-900) 100%);
  border-radius: 20px;
  padding: 32px;
  color: white;
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  box-shadow: var(--shadow-lg);
  position: relative;
  overflow: hidden;
}

.banner-text h1 {
  font-size: 24px;
  font-weight: 800;
  color: white;
  margin-bottom: 8px;
}

.banner-text p {
  font-size: 15px;
  opacity: 0.8;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 24px;
}

.full-width {
  grid-column: span 2;
}

.stat-summary-card {
  height: 100%;
}

.header-with-icon {
  display: flex;
  align-items: center;
  gap: 12px;
}

.icon-box {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}

.bg-green { background: #10b981; }
.bg-blue { background: #3b82f6; }
.bg-purple { background: #8b5cf6; }

.btn-link {
  font-size: 13px;
  font-weight: 600;
  color: var(--primary-500);
  display: flex;
  align-items: center;
  gap: 4px;
  text-decoration: none;
}

.attendance-viz {
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding: 10px 0;
}

.viz-circle {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  border: 8px solid var(--primary-50);
  border-top-color: var(--primary-500);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.viz-value {
  font-size: 20px;
  font-weight: 800;
  color: var(--text-primary);
}

.viz-label {
  font-size: 10px;
  color: var(--text-muted);
}

.viz-stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.viz-stat-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}

.viz-stat-item .label {
  color: var(--text-secondary);
  width: 70px;
}

.viz-stat-item .value {
  font-weight: 700;
  color: var(--text-primary);
}

.growth-summary {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  text-align: center;
}

.growth-stat {
  background: var(--gray-50);
  padding: 16px;
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.growth-stat .label {
  font-size: 12px;
  color: var(--text-secondary);
}

.growth-stat .value {
  font-size: 22px;
  font-weight: 800;
  color: var(--primary-700);
}

.growth-stat .value small {
  font-size: 12px;
  opacity: 0.6;
}

.growth-date {
  grid-column: span 2;
  font-size: 11px;
  color: var(--text-muted);
  margin-top: 8px;
}

.mini-table-wrapper {
  overflow-x: auto;
}

.mini-table {
  width: 100%;
  border-collapse: collapse;
}

.mini-table th {
  text-align: left;
  padding: 12px 20px;
  background: var(--gray-50);
  font-size: 11px;
  font-weight: 700;
  color: var(--text-muted);
  text-transform: uppercase;
}

.mini-table td {
  padding: 14px 20px;
  border-bottom: 1px solid var(--border-default);
  font-size: 14px;
}

.font-bold { font-weight: 700; }

.score-pill {
  background: var(--primary-50);
  color: var(--primary-700);
  padding: 4px 12px;
  border-radius: 8px;
  font-weight: 800;
}

.score-pill.low {
  background: var(--bg-danger);
  color: var(--color-danger);
}

.empty-mini {
  text-align: center;
  padding: 40px 20px;
  color: var(--text-muted);
  font-size: 14px;
}

.no-padding { padding: 0 !important; }

@media (max-width: 768px) {
  .dashboard-grid { grid-template-columns: 1fr; }
  .full-width { grid-column: span 1; }
  .welcome-banner { flex-direction: column; text-align: center; gap: 20px; }
  .attendance-viz { flex-direction: column; gap: 24px; }
}
</style>
