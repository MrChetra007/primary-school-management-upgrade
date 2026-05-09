<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { 
  CalendarIcon, 
  ChevronLeftIcon, 
  ChevronRightIcon,
  InformationCircleIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const loading = ref(true)
const attendanceRecords = ref([])
const currentDate = ref(new Date())

const khmerMonths = [
  'មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា',
  'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'
]

const currentMonthLabel = computed(() => {
  return `${khmerMonths[currentDate.value.getMonth()]} ${currentDate.value.getFullYear()}`
})

onMounted(fetchAttendance)

async function fetchAttendance() {
  loading.value = true
  try {
    const startOfMonth = new Date(currentDate.value.getFullYear(), currentDate.value.getMonth(), 1).toISOString()
    const endOfMonth = new Date(currentDate.value.getFullYear(), currentDate.value.getMonth() + 1, 0).toISOString()

    const { data, error } = await supabase
      .from('student_attendances')
      .select('*')
      .eq('student_id', studentId)
      .gte('date', startOfMonth)
      .lte('date', endOfMonth)
      .order('date', { ascending: false })

    if (error) throw error
    attendanceRecords.value = data || []
  } catch (err) {
    console.error('Error fetching attendance:', err)
  } finally {
    loading.value = false
  }
}

function changeMonth(delta) {
  const newDate = new Date(currentDate.value)
  newDate.setMonth(newDate.getMonth() + delta)
  currentDate.value = newDate
  fetchAttendance()
}

const stats = computed(() => {
  return attendanceRecords.value.reduce((acc, curr) => {
    if (acc[curr.status] !== undefined) acc[curr.status]++
    return acc
  }, { present: 0, absent: 0, late: 0, permission: 0 })
})

function getStatusLabel(status) {
  const labels = {
    present: 'វត្តមាន',
    absent: 'អវត្តមាន',
    late: 'មកយឺត',
    permission: 'ច្បាប់'
  }
  return labels[status] || status
}

function getStatusBadgeClass(status) {
  const classes = {
    present: 'badge-green',
    absent: 'badge-red',
    late: 'badge-yellow',
    permission: 'badge-blue'
  }
  return classes[status] || 'badge-gray'
}
</script>

<template>
  <div class="attendance-view">
    <div class="view-header">
      <div class="header-main">
        <div class="icon-circle">
          <CalendarIcon class="w-6 h-6 text-primary-500" />
        </div>
        <div>
          <h2 class="view-title">វត្តមានសិស្ស</h2>
          <p class="view-subtitle">តាមដានការមកសិក្សាប្រចាំខែ</p>
        </div>
      </div>

      <div class="month-selector">
        <button @click="changeMonth(-1)" class="btn-icon btn-sm"><ChevronLeftIcon /></button>
        <span class="current-month">{{ currentMonthLabel }}</span>
        <button @click="changeMonth(1)" class="btn-icon btn-sm"><ChevronRightIcon /></button>
      </div>
    </div>

    <!-- Stats Summary -->
    <div class="attendance-stats-row">
      <div class="mini-stat-card">
        <span class="val color-green">{{ stats.present }}</span>
        <span class="lab">វត្តមាន</span>
      </div>
      <div class="mini-stat-card">
        <span class="val color-red">{{ stats.absent }}</span>
        <span class="lab">អវត្តមាន</span>
      </div>
      <div class="mini-stat-card">
        <span class="val color-blue">{{ stats.permission }}</span>
        <span class="lab">ច្បាប់</span>
      </div>
      <div class="mini-stat-card">
        <span class="val color-yellow">{{ stats.late }}</span>
        <span class="lab">មកយឺត</span>
      </div>
    </div>

    <!-- Attendance List -->
    <div class="card mt-6">
      <div v-if="loading" class="padded">
        <div v-for="i in 5" :key="i" class="skeleton list-skeleton"></div>
      </div>
      
      <div v-else-if="attendanceRecords.length === 0" class="empty-mini padded">
        មិនមានទិន្នន័យវត្តមានសម្រាប់ខែនេះទេ
      </div>

      <div v-else class="table-wrapper">
        <table class="attendance-table">
          <thead>
            <tr>
              <th>កាលបរិច្ឆេទ</th>
              <th>ស្ថានភាព</th>
              <th>សម្គាល់</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="record in attendanceRecords" :key="record.id">
              <td class="date-cell">
                <div class="date-box">
                  <span class="day">{{ new Date(record.date).getDate() }}</span>
                  <span class="month">{{ khmerMonths[new Date(record.date).getMonth()] }}</span>
                </div>
                <span class="full-date">{{ formatDate(record.date) }}</span>
              </td>
              <td>
                <span class="badge" :class="getStatusBadgeClass(record.status)">
                  {{ getStatusLabel(record.status) }}
                </span>
              </td>
              <td class="note-cell">
                <span v-if="record.notes" class="note-text">{{ record.notes }}</span>
                <span v-else class="text-muted">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Legend -->
    <div class="attendance-legend">
      <div class="legend-item">
        <InformationCircleIcon class="w-4 h-4 text-primary-500" />
        <span>ព័ត៌មានបន្ថែម៖ វត្តមានត្រូវបានកត់ត្រាដោយគ្រូបន្ទុកថ្នាក់រៀងរាល់ព្រឹក។</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.attendance-view {
  animation: fadeIn 0.4s ease;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
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

.month-selector {
  display: flex;
  align-items: center;
  gap: 12px;
  background: white;
  padding: 6px 12px;
  border-radius: 12px;
  border: 1px solid var(--border-default);
  box-shadow: var(--shadow-sm);
}

.current-month {
  font-size: 14px;
  font-weight: 700;
  color: var(--primary-700);
  min-width: 120px;
  text-align: center;
}

.attendance-stats-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.mini-stat-card {
  background: white;
  padding: 16px;
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  border: 1px solid var(--border-default);
  box-shadow: var(--shadow-sm);
}

.mini-stat-card .val {
  font-size: 24px;
  font-weight: 800;
}

.mini-stat-card .lab {
  font-size: 11px;
  font-weight: 700;
  color: var(--text-muted);
  text-transform: uppercase;
}

.color-green { color: #10b981; }
.color-red { color: #ef4444; }
.color-blue { color: #3b82f6; }
.color-yellow { color: #f59e0b; }

.attendance-table th {
  background: var(--gray-50);
  padding: 12px 20px;
  font-size: 12px;
  text-align: left;
  color: var(--text-muted);
}

.attendance-table td {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border-default);
}

.date-cell {
  display: flex;
  align-items: center;
  gap: 16px;
}

.date-box {
  width: 44px;
  height: 44px;
  background: var(--gray-50);
  border-radius: 10px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--border-default);
}

.date-box .day {
  font-size: 16px;
  font-weight: 800;
  color: var(--text-primary);
  line-height: 1;
}

.date-box .month {
  font-size: 9px;
  font-weight: 700;
  color: var(--text-muted);
  text-transform: uppercase;
}

.full-date {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
}

.note-text {
  font-size: 13px;
  color: var(--text-secondary);
}

.attendance-legend {
  margin-top: 24px;
  background: var(--bg-info);
  padding: 12px 16px;
  border-radius: 12px;
  border: 1px solid var(--border-info);
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12px;
  color: var(--color-info);
}

.padded { padding: 20px; }
.list-skeleton { height: 60px; margin-bottom: 12px; border-radius: 10px; }

@media (max-width: 768px) {
  .attendance-stats-row { grid-template-columns: repeat(2, 1fr); }
  .view-header { flex-direction: column; align-items: flex-start; gap: 16px; }
  .month-selector { width: 100%; justify-content: space-between; }
  .date-cell .full-date { display: none; }
}
</style>
