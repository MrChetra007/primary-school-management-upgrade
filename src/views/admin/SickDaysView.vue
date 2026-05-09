<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { CheckIcon, XCircleIcon, FaceFrownIcon, TrashIcon } from '@heroicons/vue/24/outline'

const sickDays = ref([])
const students = ref([])
const classes = ref([])
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const toast = ref(null)
const search = ref('')
const filterClass = ref('')

const emptyForm = () => ({ id: null, student_id: '', date: '', reason: '', duration: 1, notes: '' })
const form = ref(emptyForm())
const studentSearch = ref('')
const studentResults = ref([])

const filtered = computed(() => {
  let list = sickDays.value
  if (filterClass.value) list = list.filter(s => s.students?.class_id === filterClass.value)
  const q = search.value.toLowerCase()
  if (q) list = list.filter(s => s.students?.full_name.toLowerCase().includes(q))
  return list
})

onMounted(async () => {
  await Promise.all([loadSickDays(), loadStudents(), loadClasses()])
})

async function loadSickDays() {
  loading.value = true
  const { data } = await supabase
    .from('student_sick_days')
    .select('*, students(full_name, class_id, classes(class_name))')
    .order('date', { ascending: false })
  sickDays.value = data || []
  loading.value = false
}

async function loadStudents() {
  const { data } = await supabase.from('students').select('id, full_name').order('full_name')
  students.value = data || []
}

async function loadClasses() {
  const { data } = await supabase.from('classes').select('id, class_name').order('class_name')
  classes.value = data || []
}

function searchStudents() {
  const q = studentSearch.value.toLowerCase()
  studentResults.value = q.length > 1 ? students.value.filter(s => s.full_name.toLowerCase().includes(q)).slice(0, 8) : []
}

function selectStudent(s) {
  form.value.student_id = s.id
  studentSearch.value = s.full_name
  studentResults.value = []
}

function openAdd() {
  isEdit.value = false
  form.value = emptyForm()
  studentSearch.value = ''
  showModal.value = true
}

function openEdit(s) {
  isEdit.value = true
  form.value = { ...s, date: toInputDate(s.date) }
  studentSearch.value = s.students?.full_name || ''
  showModal.value = true
}

async function save() {
  if (!form.value.student_id || !form.value.date) {
    showToast('សូមបំពេញឈ្មោះសិស្ស និងកាលបរិច្ឆេទ', 'error'); return
  }
  saving.value = true
  const { id, students: _s, ...payload } = form.value
  const { error } = isEdit.value
    ? await supabase.from('student_sick_days').update(payload).eq('id', id)
    : await supabase.from('student_sick_days').insert(payload)
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast(isEdit.value ? 'បានធ្វើបច្ចុប្បន្នភាពរួចរាល់!' : 'បានរក្សាទុកទិន្នន័យរួចរាល់!', 'success')
  showModal.value = false
  loadSickDays()
}

async function doDelete() {
  const { error } = await supabase.from('student_sick_days').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបទិន្នន័យរួចរាល់', 'success')
  loadSickDays()
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
        <XCircleIcon v-else class="w-4 h-4" /> {{ toast.msg }}
      </div>
    </div>

    <div class="page-header">
      <div>
        <h1 class="page-title">អវត្តមានដោយសារជំងឺ</h1>
        <p class="page-subtitle">តាមដានការឈប់សម្រាករបស់សិស្សដោយសារបញ្ហាសុខភាព</p>
      </div>
      <button class="btn btn-primary" @click="openAdd">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        បន្ថែមការឈប់សម្រាក
      </button>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរកតាមឈ្មោះសិស្ស..." />
      </div>
      <select class="form-select" v-model="filterClass" style="width:200px;">
        <option value="">គ្រប់ថ្នាក់ទាំងអស់</option>
        <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
      </select>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:48px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <div class="empty-state-icon"><FaceFrownIcon class="w-12 h-12 text-gray-400" /></div>
        <p class="empty-state-title">មិនមានទិន្នន័យការឈប់សម្រាកទេ</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមការឈប់សម្រាក</button>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>ឈ្មោះសិស្ស</th>
              <th>ថ្នាក់</th>
              <th>កាលបរិច្ឆេទ</th>
              <th>រយៈពេល</th>
              <th>មូលហេតុ</th>
              <th>សម្គាល់</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in filtered" :key="s.id">
              <td>
                <div style="font-weight:600;font-size:13px;">{{ s.students?.full_name }}</div>
              </td>
              <td><span class="badge badge-gray">{{ s.students?.classes?.class_name || '—' }}</span></td>
              <td>{{ formatDate(s.date) }}</td>
              <td><span class="badge badge-red">{{ s.duration }} ថ្ងៃ</span></td>
              <td style="font-size:13px;">{{ s.reason || '—' }}</td>
              <td style="font-size:13px;color:var(--text-muted);max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ s.notes || '—' }}</td>
              <td>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(s)">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = s">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal Form -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែព័ត៌មាន' : 'បន្ថែមការឈប់សម្រាក' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group">
            <label class="form-label">ឈ្មោះសិស្ស *</label>
            <input class="form-input" v-model="studentSearch" @input="searchStudents" placeholder="វាយឈ្មោះសិស្ស..." />
            <div v-if="studentResults.length > 0" style="border:1px solid var(--border-default);border-radius:8px;margin-top:4px;background:white;box-shadow:var(--shadow-md);overflow:hidden;z-index:10;">
              <div v-for="s in studentResults" :key="s.id" style="padding:8px 12px;cursor:pointer;font-size:13px;" @click="selectStudent(s)" onmouseover="this.style.background='#f8fafc'" onmouseout="this.style.background='white'">{{ s.full_name }}</div>
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">កាលបរិច្ឆេទ *</label>
            <input class="form-input" type="date" v-model="form.date" />
          </div>
          <div class="form-group">
            <label class="form-label">រយៈពេល (ថ្ងៃ)</label>
            <input class="form-input" type="number" v-model="form.duration" min="1" />
          </div>
          <div class="form-group">
            <label class="form-label">មូលហេតុ</label>
            <input class="form-input" v-model="form.reason" placeholder="ឧ. គ្រុនក្តៅ, ឈឺពោះ" />
          </div>
          <div class="form-group">
            <label class="form-label">សម្គាល់</label>
            <textarea class="form-textarea" v-model="form.notes" rows="3" placeholder="ព័ត៌មានលម្អិតបន្ថែម"></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}</button>
        </div>
      </div>
    </div>

    <!-- Delete Confirm -->
    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:360px;">
        <div class="modal-body" style="text-align:center;padding:28px 24px;">
          <div><TrashIcon class="w-10 h-10 text-red-500" /></div>
          <h3 style="margin-bottom:8px;">លុបទិន្នន័យ?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">តើអ្នកពិតជាចង់លុបកំណត់ត្រាអវត្តមានរបស់ <strong>{{ deleteTarget.students?.full_name }}</strong> មែនទេ?</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រម លុប</button>
        </div>
      </div>
    </div>
  </div>
</template>