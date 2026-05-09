<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { CheckIcon, XCircleIcon, BeakerIcon, ClockIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const vaccinations = ref([])
const students = ref([])
const classInfo = ref(null)
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const toast = ref(null)
const search = ref('')

const emptyForm = () => ({ 
  id: null, 
  student_id: '', 
  name: '', 
  description: '', 
  completed: true, 
  date: new Date().toISOString().split('T')[0] 
})
const form = ref(emptyForm())

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

  const { data: classData } = await supabase
    .from('classes')
    .select('*, academic_years!inner(status)')
    .eq('teacher_id', teacherId)
    .eq('academic_years.status', 'active')
    .maybeSingle()
  
  if (classData) {
    classInfo.value = classData
    
    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name')
      .eq('class_id', classData.id)
      .order('full_name')
    students.value = stuData || []

    await loadVaccinations()
  }
  loading.value = false
}

async function loadVaccinations() {
  const { data } = await supabase
    .from('student_vaccinations')
    .select('*, students!inner(full_name, class_id)')
    .eq('students.class_id', classInfo.value.id)
    .order('date', { ascending: false })
  vaccinations.value = data || []
}

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return vaccinations.value.filter(v => 
    v.students?.full_name.toLowerCase().includes(q) || 
    v.name.toLowerCase().includes(q)
  )
})

function openAdd() {
  isEdit.value = false
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(v) {
  isEdit.value = true
  form.value = { ...v, date: toInputDate(v.date) }
  showModal.value = true
}

async function save() {
  if (!form.value.student_id || !form.value.name) {
    showToast('សូមបំពេញសិស្សនិងឈ្មោះវ៉ាក់សាំង', 'error'); 
    return
  }
  saving.value = true
  const { id, students: _s, ...payload } = form.value
  const { error } = id
    ? await supabase.from('student_vaccinations').update(payload).eq('id', id)
    : await supabase.from('student_vaccinations').insert(payload)
  
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  
  showToast(isEdit.value ? 'បានកែប្រែកំណត់ត្រា!' : 'បានបញ្ចូលវ៉ាក់សាំង!', 'success')
  showModal.value = false
  await loadVaccinations()
}

async function doDelete() {
  const { error } = await supabase.from('student_vaccinations').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបកំណត់ត្រា', 'success')
  await loadVaccinations()
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}
</script>

<template>
  <div>
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header">
      <div>
        <h1 class="page-title">ការចាក់វ៉ាក់សាំង</h1>
        <p class="page-subtitle" v-if="classInfo">
          ថ្នាក់៖ <strong>{{ classInfo.class_name }}</strong>
        </p>
      </div>
      <button v-if="classInfo" class="btn btn-primary" @click="openAdd">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px">
          <line x1="12" y1="5" x2="12" y2="19"/>
          <line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        បញ្ចូលការចាក់វ៉ាក់សាំង
      </button>
    </div>

    <div v-if="loading" class="card card-body">
      <div v-for="i in 5" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
    </div>

    <div v-else-if="!classInfo" class="empty-state">
      <div class="empty-state-icon"><BeakerIcon class="w-12 h-12 text-gray-400" /></div>
      <p class="empty-state-title">មិនទាន់មានថ្នាក់ត្រូវបានចាត់តាំង</p>
    </div>

    <div v-else>
      <div class="filters-bar">
        <div class="search-input-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"/>
            <line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input class="form-input" v-model="search" placeholder="ស្វែងរកតាមឈ្មោះសិស្ស ឬវ៉ាក់សាំង..." />
        </div>
      </div>

      <div class="card">
        <div v-if="filtered.length === 0" class="empty-state">
          <div class="empty-state-icon"><BeakerIcon class="w-12 h-12 text-gray-400" /></div>
          <p class="empty-state-title">មិនមានកំណត់ត្រា</p>
        </div>
        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>សិស្ស</th>
                <th>ឈ្មោះវ៉ាក់សាំង</th>
                <th>កាលបរិច្ឆេទ</th>
                <th>ស្ថានភាព</th>
                <th>សកម្មភាព</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="v in filtered" :key="v.id">
                <td style="font-weight:600;">{{ v.students?.full_name }}</td>
                <td style="font-weight:600;">{{ v.name }}</td>
                <td>{{ formatDate(v.date) }}</td>
                <td>
                  <span class="badge" :class="v.completed ? 'badge-green' : 'badge-yellow'">
                    <template v-if="v.completed">
                      <CheckIcon class="w-4 h-4" /> បានចាក់
                    </template>
                    <template v-else>
                      <ClockIcon class="w-4 h-4" /> មិនទាន់
                    </template>
                  </span>
                </td>
                <td>
                  <div class="table-actions">
                    <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(v)">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                        <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                      </svg>
                    </button>
                    <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = v">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="3 6 5 6 21 6"/>
                        <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែកំណត់ត្រា' : 'បញ្ចូលការចាក់វ៉ាក់សាំង' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group">
            <label class="form-label">សិស្ស *</label>
            <select class="form-select" v-model="form.student_id" :disabled="isEdit">
              <option value="">— ជ្រើសរើសសិស្ស —</option>
              <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">ឈ្មោះវ៉ាក់សាំង *</label>
            <input class="form-input" v-model="form.name" placeholder="ឧ. រលាកថ្លើម B, MMR" />
          </div>
          <div class="form-group">
            <label class="form-label">កាលបរិច្ឆេទ</label>
            <input class="form-input" type="date" v-model="form.date" />
          </div>
          <div class="form-group">
            <label class="form-label">ស្ថានភាព</label>
            <div style="display:flex;gap:16px;">
              <label style="display:flex;align-items:center;gap:8px;cursor:pointer;">
                <input type="radio" :value="true" v-model="form.completed" /> បានចាក់
              </label>
              <label style="display:flex;align-items:center;gap:8px;cursor:pointer;">
                <input type="radio" :value="false" v-model="form.completed" /> មិនទាន់
              </label>
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">ការពិពណ៌នា</label>
            <input class="form-input" v-model="form.description" placeholder="កំណត់ចំណាំ (ជាជម្រើស)" />
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">
            {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>