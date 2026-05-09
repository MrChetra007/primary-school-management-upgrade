<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { 
  BeakerIcon, 
  ShieldCheckIcon,
  InformationCircleIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const loading = ref(true)
const vaccinations = ref([])

onMounted(async () => {
  try {
    const { data, error } = await supabase
      .from('student_vaccinations')
      .select('*')
      .eq('student_id', studentId)
      .order('vaccination_date', { ascending: false })

    if (error) throw error
    vaccinations.value = data || []
  } catch (err) {
    console.error('Error fetching vaccinations:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="vaccinations-view">
    <div class="view-header">
      <div class="header-main">
        <div class="icon-circle">
          <BeakerIcon class="w-6 h-6 text-primary-500" />
        </div>
        <div>
          <h2 class="view-title">ប្រវត្តិវ៉ាក់សាំង</h2>
          <p class="view-subtitle">បញ្ជីឈ្មោះវ៉ាក់សាំងដែលបានចាក់រួច</p>
        </div>
      </div>
    </div>

    <div v-if="loading" class="padded">
      <div v-for="i in 3" :key="i" class="skeleton list-skeleton"></div>
    </div>

    <div v-else-if="vaccinations.length === 0" class="empty-mini padded">
      មិនទាន់មានទិន្នន័យវ៉ាក់សាំងត្រូវបានកត់ត្រានៅឡើយទេ
    </div>

    <div v-else class="vaccinations-grid">
      <div v-for="v in vaccinations" :key="v.id" class="card vaccination-card">
        <div class="card-body">
          <div class="vaccination-header">
            <div class="v-icon-box">
              <ShieldCheckIcon class="w-6 h-6" />
            </div>
            <div class="v-title-info">
              <h4 class="v-name">{{ v.vaccine_name }}</h4>
              <span class="v-date">ចាក់នៅថ្ងៃទី៖ {{ formatDate(v.vaccination_date) }}</span>
            </div>
          </div>
          
          <div class="v-details">
            <div class="v-detail-item">
              <span class="label">ប្រភេទ/ដូស៖</span>
              <span class="value">{{ v.dose_number || '—' }}</span>
            </div>
            <div class="v-detail-item" v-if="v.next_dose_date">
              <span class="label">ថ្ងៃចាក់លើកក្រោយ៖</span>
              <span class="value color-blue">{{ formatDate(v.next_dose_date) }}</span>
            </div>
          </div>

          <div v-if="v.notes" class="v-notes">
            <strong>សម្គាល់៖</strong> {{ v.notes }}
          </div>
        </div>
      </div>
    </div>

    <div class="info-note mt-6">
      <InformationCircleIcon class="w-5 h-5" />
      <p>សូមរក្សាទុកប័ណ្ណវ៉ាក់សាំងច្បាប់ដើម ដើម្បីផ្ទៀងផ្ទាត់ជាមួយទិន្នន័យក្នុងប្រព័ន្ធ។</p>
    </div>
  </div>
</template>

<style scoped>
.vaccinations-view {
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

.vaccinations-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
}

.vaccination-card {
  transition: transform 0.2s ease;
}
.vaccination-card:hover { transform: translateY(-2px); }

.vaccination-header {
  display: flex;
  gap: 16px;
  align-items: center;
  margin-bottom: 16px;
}

.v-icon-box {
  width: 44px; height: 44px;
  background: var(--bg-success);
  color: var(--color-success);
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
}

.v-title-info { display: flex; flex-direction: column; }
.v-name { font-size: 16px; font-weight: 700; color: var(--text-primary); }
.v-date { font-size: 12px; color: var(--text-muted); }

.v-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
  background: var(--gray-50);
  padding: 12px;
  border-radius: 10px;
}

.v-detail-item {
  display: flex; justify-content: space-between; font-size: 13px;
}
.v-detail-item .label { color: var(--text-secondary); }
.v-detail-item .value { font-weight: 700; color: var(--text-primary); }

.v-notes {
  margin-top: 12px; font-size: 12px; color: var(--text-secondary);
  line-height: 1.5; font-style: italic;
}

.color-blue { color: var(--primary-500) !important; }

.info-note {
  display: flex; gap: 10px; background: #f8fafc;
  padding: 16px; border-radius: 12px; border: 1px solid var(--border-default);
}
.info-note svg { flex-shrink: 0; color: var(--primary-500); }
.info-note p { font-size: 13px; color: var(--text-secondary); }

.padded { padding: 20px; }
.list-skeleton { height: 140px; margin-bottom: 20px; border-radius: 16px; }

@media (max-width: 768px) {
  .vaccinations-grid { grid-template-columns: 1fr; }
}
</style>
