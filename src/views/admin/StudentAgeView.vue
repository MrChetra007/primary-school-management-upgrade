<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAcademicYearStore } from '@/stores/academicYear'
import { formatDate } from '@/utils/formatDate'
import { UserGroupIcon, AcademicCapIcon } from '@heroicons/vue/24/outline'

const yearStore = useAcademicYearStore()

const loading = ref(true)
const classes = ref([])
const allStudents = ref([])

const selectedClassId = ref(null)
const selectedGender = ref('all')
const ageFrom = ref(null)
const ageTo = ref(null)

onMounted(async () => {
  loading.value = true
  await fetchClasses()
  if (classes.value.length > 0) {
    selectedClassId.value = classes.value[0].id
  }
  loading.value = false
})

async function fetchClasses() {
  const { data } = await supabase
    .from('classes')
    .select('id, class_name')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('class_name')
  classes.value = data || []
}

async function fetchData() {
  if (!selectedClassId.value) return
  loading.value = true

  const { data } = await supabase
    .from('students')
    .select('id, full_name, gender, dob, real_id, classes!inner(class_name)')
    .eq('class_id', selectedClassId.value)
    .eq('is_graduated', false)
    .order('full_name')

  allStudents.value = (data || []).map(s => ({
    ...s,
    age: calculateAge(s.dob)
  }))

  loading.value = false
}

function calculateAge(dob) {
  if (!dob) return null
  const birth = new Date(dob)
  const today = new Date()
  let age = today.getFullYear() - birth.getFullYear()
  const m = today.getMonth() - birth.getMonth()
  if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) {
    age--
  }
  return age
}

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??'
}

const filtered = computed(() => {
  let list = allStudents.value

  if (selectedGender.value !== 'all') {
    list = list.filter(s => (s.gender || '').toLowerCase() === selectedGender.value)
  }

  if (ageFrom.value !== null && ageFrom.value !== '') {
    list = list.filter(s => s.age !== null && s.age >= Number(ageFrom.value))
  }

  if (ageTo.value !== null && ageTo.value !== '') {
    list = list.filter(s => s.age !== null && s.age <= Number(ageTo.value))
  }

  return list
})

const stats = computed(() => {
  const list = filtered.value
  if (list.length === 0) {
    return {
      total: 0,
      female: 0,
      male: 0,
      avgAge: 0,
      minAge: 0,
      maxAge: 0,
      ageDistribution: {}
    }
  }

  const ages = list.map(s => s.age).filter(a => a !== null)
  const female = list.filter(s => (s.gender || '').toLowerCase() === 'female').length
  const male = list.filter(s => (s.gender || '').toLowerCase() === 'male').length

  const dist = {}
  ages.forEach(a => {
    const key = a >= 12 ? '12+' : String(a)
    dist[key] = (dist[key] || 0) + 1
  })

  return {
    total: list.length,
    female,
    male,
    avgAge: ages.length ? (ages.reduce((a, b) => a + b, 0) / ages.length) : 0,
    minAge: ages.length ? Math.min(...ages) : 0,
    maxAge: ages.length ? Math.max(...ages) : 0,
    ageDistribution: dist
  }
})

watch(selectedClassId, fetchData)
</script>

<template>
  <div class="age-view">
    <div class="page-header">
      <div>
        <h1 class="page-title">របាយការណ៍អាយុសិស្ស</h1>
        <p class="page-subtitle">មើល និងវិភាគការបែងចែកអាយុសិស្សតាមថ្នាក់រៀន</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="card no-print" style="margin-bottom:20px;">
      <div class="card-body filter-grid">
        <div class="form-group">
          <label class="form-label">ថ្នាក់រៀន</label>
          <select class="form-select" v-model="selectedClassId">
            <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">ភេទ</label>
          <select class="form-select" v-model="selectedGender">
            <option value="all">ទាំងអស់</option>
            <option value="male">ប្រុស</option>
            <option value="female">ស្រី</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">អាយុចាប់ពី</label>
          <input type="number" class="form-input" v-model.number="ageFrom" min="0" max="20" placeholder="ទាបបំផុត" />
        </div>
        <div class="form-group">
          <label class="form-label">រហូតដល់អាយុ</label>
          <input type="number" class="form-input" v-model.number="ageTo" min="0" max="20" placeholder="ខ្ពស់បំផុត" />
        </div>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:400px; border-radius:12px;"></div>
    </div>

    <div v-else-if="!selectedClassId" class="empty-state">
      <UserGroupIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">សូមជ្រើសរើសថ្នាក់រៀនដើម្បីមើលអាយុសិស្ស</p>
    </div>

    <div v-else-if="allStudents.length === 0" class="empty-state">
      <AcademicCapIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">មិនមានសិស្សនៅក្នុងថ្នាក់រៀននេះទេ</p>
    </div>

    <div v-else>
      <!-- Summary Tiles -->
      <div class="tile-group">
        <div class="group-title">សេចក្តីសង្ខេប</div>
        <div class="tiles-row">
          <div class="stat-tile border-purple">
            <div class="tile-main">
              <span class="tile-label">សិស្សសរុប</span>
              <span class="tile-val">{{ stats.total }}</span>
            </div>
            <div class="tile-footer">
              <span>ស្រី <b class="text-pink">{{ stats.female }}</b></span>
              <span>ប្រុស <b class="text-blue">{{ stats.male }}</b></span>
            </div>
          </div>
          <div class="stat-tile border-green">
            <div class="tile-main">
              <span class="tile-label">អាយុមធ្យម</span>
              <span class="tile-val">{{ stats.avgAge.toFixed(1) }} ឆ្នាំ</span>
            </div>
            <div class="tile-footer">
              <span>ក្មេងជាងគេ <b>{{ stats.minAge }}</b></span>
              <span>ចាស់ជាងគេ <b>{{ stats.maxAge }}</b></span>
            </div>
          </div>
          <div class="stat-tile border-blue">
            <div class="tile-main">
              <span class="tile-label">ចន្លោះអាយុ</span>
              <span class="tile-val">{{ stats.minAge }} – {{ stats.maxAge }} ឆ្នាំ</span>
            </div>
            <div class="tile-footer">
              <span>ចំនួនចម្រោះសរុប <b>{{ filtered.length }}</b></span>
            </div>
          </div>
        </div>
      </div>

      <!-- Age Distribution -->
      <div class="card no-print" style="margin-bottom:24px;">
        <div class="card-header" style="padding:12px 16px; border-bottom:1px solid #f1f5f9;">
          <h3 style="font-size:14px; font-weight:700;">ការបែងចែកអាយុ</h3>
        </div>
        <div class="card-body" style="padding:16px;">
          <div v-if="Object.keys(stats.ageDistribution).length === 0" style="text-align:center; color:#94a3b8; padding:24px;">
            មិនមានទិន្នន័យអាយុទេ
          </div>
          <div v-else class="age-dist-grid">
            <div
              v-for="age in ['5','6','7','8','9','10','11','12+']"
              :key="age"
              class="age-box"
              :class="{ 'box-active': stats.ageDistribution[age], 'box-empty': !stats.ageDistribution[age] }"
            >
              <div class="age-value">{{ age }}</div>
              <div class="age-count">{{ stats.ageDistribution[age] || 0 }}</div>
              <div class="age-label">ឆ្នាំ</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Student Table -->
      <div class="card">
        <div class="table-wrapper">
          <table class="age-table">
            <thead>
              <tr>
                <th style="width:40px;">#</th>
                <th style="text-align:left;">ឈ្មោះ</th>
                <th style="text-align:center; width:100px;">ភេទ</th>
                <th style="text-align:center; width:140px;">ថ្ងៃខែឆ្នាំកំណើត</th>
                <th style="text-align:center; width:80px;">អាយុ</th>
                <th style="text-align:center; width:120px;">ថ្នាក់</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(s, idx) in filtered" :key="s.id">
                <td style="text-align:center;">{{ idx + 1 }}</td>
                <td>
                  <div style="display:flex; align-items:center; gap:10px;">
                    <div class="mini-avatar" :style="{ background: (s.gender || '').toLowerCase() === 'female' ? '#ec4899' : 'var(--primary-color)' }">
                      {{ initials(s.full_name) }}
                    </div>
                    <span style="font-weight:600;">{{ s.full_name }}</span>
                  </div>
                </td>
                <td style="text-align:center;">
                  <span class="badge" :class="(s.gender || '').toLowerCase() === 'female' ? 'badge-red' : 'badge-blue'">
                    {{ (s.gender || '').toLowerCase() === 'female' ? 'ស្រី' : 'ប្រុស' }}
                  </span>
                </td>
                <td style="text-align:center; font-size:13px;">{{ formatDate(s.dob) }}</td>
                <td style="text-align:center;">
                  <span class="age-chip" :class="{ 'young': s.age <= 5, 'old': s.age >= 12 }">{{ s.age }}</span>
                </td>
                <td style="text-align:center;">
                  <span class="badge badge-gray">{{ s.classes?.class_name || '—' }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="filtered.length === 0" class="card-body" style="text-align:center; color:#94a3b8; padding:24px;">
          មិនមានសិស្សត្រូវនឹងលក្ខខណ្ឌចម្រោះឡើយ
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.age-view {
  display: flex;
  flex-direction: column;
}

.filter-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
}

.tile-group {
  margin-bottom: 24px;
}

.group-title {
  font-size: 14px;
  font-weight: 700;
  color: #374151;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 2px solid #e5e7eb;
}

.tiles-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 16px;
}

.stat-tile {
  background: white;
  border-radius: 12px;
  padding: 16px;
  border: 1px solid #e5e7eb;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  transition: transform 0.2s;
}

.stat-tile:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.border-purple { border-left: 4px solid #8b5cf6; }
.border-green { border-left: 4px solid #10b981; }
.border-blue { border-left: 4px solid #3b82f6; }

.tile-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.tile-label { font-size: 14px; font-weight: 700; color: #4b5563; }
.tile-val { font-size: 18px; font-weight: 800; color: #1e40af; }

.tile-footer {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #6b7280;
  padding-top: 8px;
  border-top: 1px dashed #e5e7eb;
}

.text-pink { color: #ec4899; }
.text-blue { color: #3b82f6; }

.age-dist-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 12px;
}

.age-box {
  text-align: center;
  padding: 16px 8px;
  border-radius: 12px;
  border: 2px solid #e5e7eb;
  transition: all 0.2s;
}

.age-box.box-active {
  background: #eff6ff;
  border-color: #3b82f6;
}

.age-box.box-empty {
  opacity: 0.4;
}

.age-value {
  font-size: 24px;
  font-weight: 800;
  color: #1e40af;
}

.age-count {
  font-size: 14px;
  font-weight: 700;
  color: #374151;
  margin: 4px 0;
}

.age-label {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 600;
}

.age-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.age-table th, .age-table td {
  padding: 10px 12px;
  border-bottom: 1px solid #f1f5f9;
}

.age-table th {
  background: #f8fafc;
  color: #64748b;
  font-weight: 700;
  font-size: 12px;
  text-transform: none;
  letter-spacing: 0;
}

.mini-avatar {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 12px;
  color: white;
  flex-shrink: 0;
}

.age-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  font-weight: 800;
  font-size: 14px;
  background: #dbeafe;
  color: #1e40af;
}

.age-chip.young {
  background: #dcfce7;
  color: #15803d;
}

.age-chip.old {
  background: #fef3c7;
  color: #b45309;
}

@media (max-width: 768px) {
  .age-dist-grid {
    grid-template-columns: repeat(4, 1fr);
  }
  .tiles-row {
    grid-template-columns: 1fr;
  }
}
</style>
