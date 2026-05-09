<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { 
  HeartIcon, 
  ShieldCheckIcon,
  ExclamationTriangleIcon,
  InformationCircleIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const loading = ref(true)
const health = ref(null)

onMounted(async () => {
  try {
    const { data, error } = await supabase
      .from('student_health')
      .select('*')
      .eq('student_id', studentId)
      .maybeSingle()

    if (error) throw error
    health.value = data
  } catch (err) {
    console.error('Error fetching health data:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="health-view">
    <div class="view-header">
      <div class="header-main">
        <div class="icon-circle">
          <HeartIcon class="w-6 h-6 text-primary-500" />
        </div>
        <div>
          <h2 class="view-title">ព័ត៌មានសុខភាព</h2>
          <p class="view-subtitle">ស្ថានភាពសុខភាពទូទៅ និងការប្រុងប្រយ័ត្ន</p>
        </div>
      </div>
    </div>

    <div v-if="loading" class="padded">
      <div class="skeleton list-skeleton"></div>
      <div class="skeleton list-skeleton"></div>
    </div>

    <div v-else-if="!health" class="empty-mini padded">
      មិនទាន់មានព័ត៌មានសុខភាពត្រូវបានកត់ត្រានៅឡើយទេ
    </div>

    <div v-else class="health-content">
      <!-- General Info -->
      <div class="card">
        <div class="card-header">
          <h3 class="card-title">ស្ថានភាពទូទៅ</h3>
        </div>
        <div class="card-body">
          <div class="info-list">
            <div class="info-row">
              <span class="label">ប្រភេទឈាម (Blood Type)</span>
              <span class="value badge badge-red">{{ health.blood_type || '—' }}</span>
            </div>
            <div class="info-row">
              <span class="label">កម្ពស់ (Height)</span>
              <span class="value">{{ health.height_cm ? `${health.height_cm} cm` : '—' }}</span>
            </div>
            <div class="info-row">
              <span class="label">ទម្ងន់ (Weight)</span>
              <span class="value">{{ health.weight_kg ? `${health.weight_kg} kg` : '—' }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Alerts & Conditions -->
      <div class="card mt-6 border-warning" :class="{ 'has-alerts': health.allergies || health.medical_conditions }">
        <div class="card-header">
          <h3 class="card-title flex items-center gap-2">
            <ExclamationTriangleIcon class="w-5 h-5 text-amber-500" />
            ការប្រុងប្រយ័ត្ន & អាឡែហ្ស៊ី
          </h3>
        </div>
        <div class="card-body">
          <div class="alert-item">
            <span class="alert-label">អាឡែហ្ស៊ី (Allergies)</span>
            <div v-if="health.allergies" class="alert-text">{{ health.allergies }}</div>
            <div v-else class="text-muted">មិនមាន</div>
          </div>
          <div class="alert-divider"></div>
          <div class="alert-item">
            <span class="alert-label">ជំងឺប្រចាំកាយ (Medical Conditions)</span>
            <div v-if="health.medical_conditions" class="alert-text">{{ health.medical_conditions }}</div>
            <div v-else class="text-muted">មិនមាន</div>
          </div>
        </div>
      </div>

      <!-- Other info -->
      <div class="card mt-6">
        <div class="card-header">
          <h3 class="card-title">ព័ត៌មានបន្ថែម</h3>
        </div>
        <div class="card-body">
          <div class="info-row vertical">
            <span class="label">កំណត់ចំណាំសុខភាព</span>
            <div class="note-box">
              {{ health.notes || 'មិនមានកំណត់ចំណាំបន្ថែមទេ' }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="info-note mt-6">
      <InformationCircleIcon class="w-5 h-5" />
      <p>ព័ត៌មាននេះត្រូវបានរក្សាទុកជាការសម្ងាត់ និងប្រើប្រាស់សម្រាប់តែគោលបំណងថែទាំសុខភាពសិស្សក្នុងសាលាប៉ុណ្ណោះ។</p>
    </div>
  </div>
</template>

<style scoped>
.health-view {
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

.info-list { display: flex; flex-direction: column; gap: 12px; }
.info-row {
  display: flex; justify-content: space-between; align-items: center;
  padding-bottom: 12px; border-bottom: 1px solid var(--border-default);
}
.info-row:last-child { border-bottom: none; }
.info-row .label { font-size: 14px; color: var(--text-secondary); }
.info-row .value { font-weight: 700; color: var(--text-primary); }

.info-row.vertical { flex-direction: column; align-items: flex-start; gap: 8px; }

.border-warning { border-color: var(--border-warning); }
.has-alerts { background: var(--bg-warning); }

.alert-item { padding: 8px 0; }
.alert-label { font-size: 13px; font-weight: 700; color: var(--text-primary); margin-bottom: 4px; display: block; }
.alert-text { font-size: 14px; color: var(--color-warning); font-weight: 500; }
.alert-divider { height: 1px; background: var(--border-warning); margin: 8px 0; opacity: 0.5; }

.note-box {
  width: 100%;
  padding: 16px;
  background: var(--gray-50);
  border-radius: 12px;
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.6;
}

.info-note {
  display: flex; gap: 10px; background: #f8fafc;
  padding: 16px; border-radius: 12px; border: 1px solid var(--border-default);
}
.info-note svg { flex-shrink: 0; color: var(--primary-500); }
.info-note p { font-size: 13px; color: var(--text-secondary); }

.padded { padding: 20px; }
.list-skeleton { height: 100px; margin-bottom: 20px; border-radius: 12px; }
</style>
