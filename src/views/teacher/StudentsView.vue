<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { useRouter } from 'vue-router'
import { BuildingOfficeIcon, AcademicCapIcon, PhoneIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const router = useRouter()
const students = ref([])
const classInfo = ref(null)
const loading = ref(true)
const search = ref('')

onMounted(async () => {
  if (auth.teacherProfile) {
    await loadData()
  } else {
    setTimeout(async () => {
      if (auth.teacherProfile) await loadData()
      else loading.value = false
    }, 1000)
  }
})

async function loadData() {
  loading.value = true
  const teacherId = auth.teacherProfile.id

  // Get Class (Filter by active academic year)
  const { data: classData } = await supabase
    .from('classes')
    .select('*, academic_years!inner(status)')
    .eq('teacher_id', teacherId)
    .eq('academic_years.status', 'active').is('academic_years.deleted_at', null)
    .maybeSingle()
  
  if (classData) {
    classInfo.value = classData
    // Get Students
    const { data } = await supabase
      .from('students')
      .select('*')
      .eq('class_id', classData.id)
      .order('full_name')
    students.value = data || []
  }
  loading.value = false
}

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return students.value.filter(s => 
    s.full_name.toLowerCase().includes(q) || 
    (s.real_id || '').toLowerCase().includes(q)
  )
})

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">សិស្សរបស់ខ្ញុំ</h1>
        <p class="page-subtitle" v-if="classInfo">
          ថ្នាក់៖ <strong>{{ classInfo.class_name }}</strong> — សិស្សសរុប {{ students.length }} នាក់
        </p>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div v-for="i in 5" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
    </div>

    <div v-else-if="!classInfo" class="empty-state">
      <div class="empty-state-icon"><BuildingOfficeIcon class="w-12 h-12 text-gray-400" /></div>
      <p class="empty-state-title">មិនទាន់មានថ្នាក់ត្រូវបានចាត់តាំង</p>
      <p class="empty-state-desc">សូមទាក់ទងអ្នកគ្រប់គ្រង។</p>
    </div>

    <div v-else>
      <div class="filters-bar">
        <div class="search-input-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          <input class="form-input" v-model="search" placeholder="ស្វែងរកសិស្សតាមឈ្មោះ ឬលេខកូដ..." />
        </div>
      </div>

      <div class="card">
        <div v-if="filtered.length === 0" class="empty-state">
          <div class="empty-state-icon"><AcademicCapIcon class="w-12 h-12 text-gray-400" /></div>
          <p class="empty-state-title">មិនមានសិស្សត្រូវបានរកឃើញ</p>
        </div>
        
        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>សិស្ស</th>
                <th>លេខកូដ</th>
                <th>ភេទ</th>
                <th>ថ្ងៃខែឆ្នាំកំណើត</th>
                <th>ទូរស័ព្ទអាណាព្យាបាល</th>
                <th>សកម្មភាព</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in filtered" :key="s.id">
                <td>
                  <div style="display:flex;align-items:center;gap:10px;">
                    <div class="avatar">{{ initials(s.full_name) }}</div>
                    <div>
                      <div style="font-weight:600;font-size:13px;">{{ s.full_name }}</div>
                      <div style="font-size:11px;color:var(--text-muted);">{{ s.gender }}</div>
                    </div>
                  </div>
                </td>
                <td style="font-size:12px;color:var(--text-secondary);">{{ s.real_id || '—' }}</td>
                <td>
                  <span class="badge" :class="s.gender === 'Male' ? 'badge-blue' : 'badge-red'">
                    {{ s.gender === 'Male' ? 'ប្រុស' : 'ស្រី' }}
                  </span>
                </td>
                <td style="font-size:13px;">{{ formatDate(s.dob) }}</td>
                <td style="font-size:13px;">
                  <div v-if="s.phone_number">
                    <PhoneIcon class="w-3 h-3" style="display:inline;vertical-align:middle;margin-right:4px;" /> 
                    {{ s.phone_number }}
                  </div>
                  <div v-else style="color:var(--text-muted);">មិនមានលេខទូរស័ព្ទ</div>
                </td>
                <td>
                  <div class="table-actions">
                    <button class="btn btn-ghost btn-sm" @click="router.push('/teacher/students/' + s.id)">
                      មើលព័ត៌មានលម្អិត
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>