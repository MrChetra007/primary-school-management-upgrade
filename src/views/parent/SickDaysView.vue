<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { 
  FaceFrownIcon, 
  InformationCircleIcon,
  CalendarDaysIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const loading = ref(true)
const sickDays = ref([])

onMounted(async () => {
  try {
    const { data, error } = await supabase
      .from('student_sick_days')
      .select('*')
      .eq('student_id', studentId)
      .order('date', { ascending: false })

    if (error) throw error
    sickDays.value = data || []
  } catch (err) {
    console.error('Error fetching sick days:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="sick-days-view">
    <div class="view-header">
      <div class="header-main">
        <div class="icon-circle">
          <FaceFrownIcon class="w-6 h-6 text-primary-500" />
        </div>
        <div>
          <h2 class="view-title">ប្រវត្តិឈប់សម្រាកព្យាបាល</h2>
          <p class="view-subtitle">បញ្ជីរាយនាមថ្ងៃដែលសិស្សបានឈប់ដោយសារជំងឺ</p>
        </div>
      </div>
    </div>

    <div v-if="loading" class="padded">
      <div v-for="i in 3" :key="i" class="skeleton list-skeleton"></div>
    </div>

    <div v-else-if="sickDays.length === 0" class="empty-mini padded">
      មិនទាន់មានប្រវត្តិឈប់សម្រាកព្យាបាលត្រូវបានកត់ត្រានៅឡើយទេ
    </div>

    <div v-else class="sick-days-list">
      <div v-for="day in sickDays" :key="day.id" class="card sick-day-card">
        <div class="card-body">
          <div class="sick-day-header">
            <div class="s-icon-box">
              <CalendarDaysIcon class="w-6 h-6" />
            </div>
            <div class="s-title-info">
              <h4 class="s-reason">{{ day.reason || 'ឈប់សម្រាកព្យាបាលជំងឺ' }}</h4>
              <div class="s-date-range">
                <span>កាលបរិច្ឆេទ៖ {{ formatDate(day.date) }}</span>
              </div>
            </div>
            <div class="s-duration">
              <span class="badge badge-red">{{ day.duration }} ថ្ងៃ</span>
            </div>
          </div>

          <div v-if="day.notes" class="s-notes">
            <strong>កំណត់ចំណាំ៖</strong> {{ day.notes }}
          </div>
        </div>
      </div>
    </div>

    <div class="info-note mt-6">
      <InformationCircleIcon class="w-5 h-5" />
      <p>រាល់ការឈប់សម្រាកព្យាបាលត្រូវមានលិខិតបញ្ជាក់ពីគ្រូពេទ្យ ឬការជូនដំណឹងពីមាតាបិតា។</p>
    </div>
  </div>
</template>

<style scoped>
.sick-days-view {
  animation: fadeIn 0.4s ease;
}

.view-header { margin-bottom: 24px; }
.header-main { display: flex; align-items: center; gap: 16px; }
.icon-circle {
  width: 48px; height: 48px;
  background: var(--primary-50);
  border-radius: 14px;
  display: flex; align-items: center; justify-content: center;
}

.view-title { font-size: 20px; font-weight: 700; color: var(--text-primary); }
.view-subtitle { font-size: 13px; color: var(--text-secondary); }

.sick-days-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.sick-day-card {
  border-left: 4px solid var(--color-danger);
}

.sick-day-header {
  display: flex;
  align-items: center;
  gap: 20px;
}

.s-icon-box {
  width: 44px; height: 44px;
  background: var(--bg-danger);
  color: var(--color-danger);
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}

.s-title-info { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.s-reason { font-size: 16px; font-weight: 700; color: var(--text-primary); }
.s-date-range { font-size: 13px; color: var(--text-secondary); display: flex; gap: 8px; align-items: center; }
.s-date-range .divider { color: var(--text-muted); font-weight: 800; }

.s-duration { flex-shrink: 0; }

.s-notes {
  margin-top: 16px; padding: 12px;
  background: var(--gray-50);
  border-radius: 10px;
  font-size: 13px;
  color: var(--text-secondary);
}

.info-note {
  display: flex; gap: 10px; background: #f8fafc;
  padding: 16px; border-radius: 12px; border: 1px solid var(--border-default);
}
.info-note svg { flex-shrink: 0; color: var(--primary-500); }
.info-note p { font-size: 13px; color: var(--text-secondary); }

.padded { padding: 20px; }
.list-skeleton { height: 100px; margin-bottom: 16px; border-radius: 12px; }

@media (max-width: 640px) {
  .sick-day-header { flex-direction: column; align-items: flex-start; gap: 12px; }
  .s-duration { align-self: flex-end; }
}
</style>
