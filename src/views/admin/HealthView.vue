<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { ChartBarIcon, BeakerIcon, CheckIcon, ClockIcon } from '@heroicons/vue/24/outline'

const activeTab = ref('growth')
const loading = ref(true)
const growth = ref([])
const vaccinations = ref([])
const search = ref('')

onMounted(async () => {
  await loadData()
})

async function loadData() {
  loading.value = true
  const [gr, vac] = await Promise.all([
    supabase.from('student_growth').select('*, students(full_name, class_id, classes(class_name))').order('date', { ascending: false }),
    supabase.from('student_vaccinations').select('*, students(full_name, class_id, classes(class_name))').order('date', { ascending: false })
  ])
  growth.value = gr.data || []
  vaccinations.value = vac.data || []
  loading.value = false
}

const filteredGrowth = computed(() => {
  const q = search.value.toLowerCase()
  return growth.value.filter(g => g.students?.full_name.toLowerCase().includes(q))
})

const filteredVaccinations = computed(() => {
  const q = search.value.toLowerCase()
  return vaccinations.value.filter(v => v.students?.full_name.toLowerCase().includes(q) || v.name.toLowerCase().includes(q))
})
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">មជ្ឈមណ្ឌលសុខភាព</h1>
        <p class="page-subtitle">កំណត់ត្រាសុខភាព និងការលូតលាស់របស់សិស្សទូទាំងសាលា</p>
      </div>
    </div>

    <div class="tabs">
      <div class="tab-item" :class="{ active: activeTab === 'growth' }" @click="activeTab = 'growth'">
        <ChartBarIcon class="w-4 h-4" /> កំណត់ត្រាការលូតលាស់
      </div>
      <div class="tab-item" :class="{ active: activeTab === 'vaccinations' }" @click="activeTab = 'vaccinations'">
        <BeakerIcon class="w-4 h-4" /> ការចាក់វ៉ាក់សាំង
      </div>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរកតាមឈ្មោះសិស្ស ឬប្រភេទវ៉ាក់សាំង..." />
      </div>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:48px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      
      <!-- Growth Table (តារាងការលូតលាស់) -->
      <div v-else-if="activeTab === 'growth'" class="table-wrapper">
        <table v-if="filteredGrowth.length > 0">
          <thead>
            <tr>
              <th>ឈ្មោះសិស្ស</th>
              <th>ថ្នាក់</th>
              <th>កាលបរិច្ឆេទ</th>
              <th>កម្ពស់ (cm)</th>
              <th>ទម្ងន់ (kg)</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="g in filteredGrowth" :key="g.id">
              <td style="font-weight:600;">{{ g.students?.full_name }}</td>
              <td><span class="badge badge-gray">{{ g.students?.classes?.class_name }}</span></td>
              <td>{{ formatDate(g.date) }}</td>
              <td style="font-weight:700;">{{ g.height }}</td>
              <td style="font-weight:700;">{{ g.weight }}</td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">រកមិនឃើញទិន្នន័យការលូតលាស់ទេ។</div>
      </div>

      <!-- Vaccinations Table (តារាងវ៉ាក់សាំង) -->
      <div v-else-if="activeTab === 'vaccinations'" class="table-wrapper">
        <table v-if="filteredVaccinations.length > 0">
          <thead>
            <tr>
              <th>ឈ្មោះសិស្ស</th>
              <th>ថ្នាក់</th>
              <th>វ៉ាក់សាំង</th>
              <th>កាលបរិច្ឆេទ</th>
              <th>ស្ថានភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="v in filteredVaccinations" :key="v.id">
              <td style="font-weight:600;">{{ v.students?.full_name }}</td>
              <td><span class="badge badge-gray">{{ v.students?.classes?.class_name }}</span></td>
              <td style="font-weight:600;">{{ v.name }}</td>
              <td>{{ formatDate(v.date) }}</td>
              <td>
                <span class="badge" :class="v.completed ? 'badge-green' : 'badge-yellow'">
                  <template v-if="v.completed">
                    <CheckIcon class="w-4 h-4" /> រួចរាល់
                  </template>
                  <template v-else>
                    <ClockIcon class="w-4 h-4" /> កំពុងរង់ចាំ
                  </template>
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">រកមិនឃើញទិន្នន័យវ៉ាក់សាំងទេ។</div>
      </div>
    </div>
  </div>
</template>
