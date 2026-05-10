<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { useRouter } from 'vue-router'
import { CheckIcon, XCircleIcon, AcademicCapIcon, TrashIcon } from '@heroicons/vue/24/outline'

const router = useRouter()
const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const students = ref([])
const classes = ref([])
const loading = ref(true)
const saving = ref(false)
const search = ref('')
const filterClass = ref('')
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const toast = ref(null)

const emptyForm = () => ({
  id: null, real_id: '', full_name: '', gender: '', dob: '', address: '',
  phone_number: '', father_name: '', father_job: '', mother_name: '', mother_job: '',
  class_id: '', academic_year_id: yearStore.selectedYearId, is_scholarship: false, is_disability: false
})
const form = ref(emptyForm())

const filtered = computed(() => {
  let list = students.value
  if (filterClass.value) list = list.filter(s => s.class_id === filterClass.value)
  const q = search.value.toLowerCase()
  if (q) list = list.filter(s =>
    s.full_name.toLowerCase().includes(q) ||
    (s.real_id || '').toLowerCase().includes(q)
  )
  return list
})

onMounted(async () => {
  await Promise.all([loadStudents(), loadClasses()])
})

async function loadStudents() {
  loading.value = true
  const { data } = await supabase
    .from('students')
    .select('*, classes(class_name)')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('full_name')
  students.value = data || []
  loading.value = false
}

async function loadClasses() {
  const { data } = await supabase
    .from('classes')
    .select('id, class_name')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('class_name')
  classes.value = data || []
}

function openAdd() {
  isEdit.value = false
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(s) {
  isEdit.value = true
  form.value = { ...s, dob: toInputDate(s.dob) }
  showModal.value = true
}

async function save() {
  if (!form.value.full_name.trim() || !form.value.dob) {
    showToast('សូមបំពេញឈ្មោះ និងថ្ងៃខែឆ្នាំកំណើត', 'error'); return
  }
  saving.value = true
  const { id, classes: _c, ...payload } = form.value
  const { error } = isEdit.value
    ? await supabase.from('students').update(payload).eq('id', id)
    : await supabase.from('students').insert({ ...payload, school_id: auth.schoolId })
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast(isEdit.value ? 'បានកែប្រែព័ត៌មានសិស្ស!' : 'បានបន្ថែមសិស្សថ្មី!', 'success')
  showModal.value = false
  loadStudents()
}

async function doDelete() {
  const { error } = await supabase.from('students').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបសិស្ស', 'success')
  loadStudents()
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '??'
}
</script>

<template>
  <div>
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" /><XCircleIcon v-else class="w-4 h-4" /> {{ toast.msg }}
      </div>
    </div>

    <div class="page-header">
      <div>
        <h1 class="page-title">សិស្ស</h1>
        <p class="page-subtitle">សិស្សចំនួន {{ students.length }} នាក់កំពុងសិក្សា</p>
      </div>
      <button class="btn btn-primary" @click="openAdd">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        បន្ថែមសិស្ស
      </button>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរកតាមឈ្មោះ ឬអត្តលេខ..." />
      </div>
      <select class="form-select" v-model="filterClass" style="width:200px;">
        <option value="">ថ្នាក់ទាំងអស់</option>
        <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
      </select>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 6" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <AcademicCapIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">រកមិនឃើញសិស្សទេ</p>
        <p class="empty-state-desc">បន្ថែមសិស្សដំបូងរបស់អ្នកដើម្បីចាប់ផ្តើម</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមសិស្ស</button>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr><th>សិស្ស</th><th>អត្តលេខ</th><th>ភេទ</th><th>ថ្ងៃខែឆ្នាំកំណើត</th><th>ថ្នាក់</th><th>ស្ថានភាព</th><th>សកម្មភាព</th></tr>
          </thead>
          <tbody>
            <tr v-for="s in filtered" :key="s.id" style="cursor:pointer;" @click="router.push('/admin/students/'+s.id)">
              <td @click.stop>
                <div style="display:flex;align-items:center;gap:10px;">
                  <div class="avatar">{{ initials(s.full_name) }}</div>
                  <div>
                    <div style="font-weight:600;font-size:13px;">{{ s.full_name }}</div>
                    <div style="font-size:11px;color:var(--text-muted);">{{ s.father_name ? 'ឪពុក: '+s.father_name : '' }}</div>
                  </div>
                </div>
              </td>
              <td style="font-size:12px;color:var(--text-secondary);">{{ s.real_id || '—' }}</td>
              <td><span class="badge" :class="s.gender === 'Male' ? 'badge-blue' : 'badge-red'">{{ s.gender === 'Male' ? 'ប្រុស' : (s.gender === 'Female' ? 'ស្រី' : '—') }}</span></td>
              <td style="font-size:13px;">{{ formatDate(s.dob) }}</td>
              <td><span class="badge badge-gray">{{ s.classes?.class_name || '—' }}</span></td>
              <td>
                <div style="display:flex;gap:4px;">
                  <span v-if="s.is_scholarship" class="badge badge-green">អាហារូបករណ៍</span>
                  <span v-if="s.is_disability" class="badge badge-yellow">ពិការភាព</span>
                </div>
              </td>
              <td @click.stop>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="router.push('/admin/students/'+s.id)" title="លម្អិត">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                  </button>
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(s)" title="កែប្រែ">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = s" title="លុប">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal modal-lg">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែព័ត៌មានសិស្ស' : 'បន្ថែមសិស្សថ្មី' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body">
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
            <div class="form-group" style="grid-column:1/-1;">
              <label class="form-label">ឈ្មោះពេញ *</label>
              <input class="form-input" v-model="form.full_name" placeholder="ឧ. ចាន់ សុភា" />
            </div>
            <div class="form-group">
              <label class="form-label">អត្តលេខសិស្ស</label>
              <input class="form-input" v-model="form.real_id" placeholder="ឧ. S-001" />
            </div>
            <div class="form-group">
              <label class="form-label">ភេទ</label>
              <select class="form-select" v-model="form.gender">
                <option value="">— ជ្រើសរើស —</option>
                <option value="Male">ប្រុស</option>
                <option value="Female">ស្រី</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">ថ្ងៃខែឆ្នាំកំណើត *</label>
              <input class="form-input" type="date" v-model="form.dob" />
            </div>
            <div class="form-group">
              <label class="form-label">ថ្នាក់រៀន</label>
              <select class="form-select" v-model="form.class_id">
                <option value="">— ជ្រើសរើសថ្នាក់ —</option>
                <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">លេខទូរស័ព្ទ</label>
              <input class="form-input" v-model="form.phone_number" placeholder="012 345 678" />
            </div>
            <div class="form-group" style="grid-column:1/-1;">
              <label class="form-label">អាសយដ្ឋាន</label>
              <textarea class="form-textarea" v-model="form.address" rows="2" placeholder="អាសយដ្ឋានផ្ទះ"></textarea>
            </div>
            <div class="form-group">
              <label class="form-label">ឈ្មោះឪពុក</label>
              <input class="form-input" v-model="form.father_name" placeholder="ឈ្មោះឪពុក" />
            </div>
            <div class="form-group">
              <label class="form-label">មុខរបរឪពុក</label>
              <input class="form-input" v-model="form.father_job" placeholder="មុខរបរឪពុក" />
            </div>
            <div class="form-group">
              <label class="form-label">ឈ្មោះម្ដាយ</label>
              <input class="form-input" v-model="form.mother_name" placeholder="ឈ្មោះម្ដាយ" />
            </div>
            <div class="form-group">
              <label class="form-label">មុខរបរម្ដាយ</label>
              <input class="form-input" v-model="form.mother_job" placeholder="មុខរបរម្ដាយ" />
            </div>
            <div class="form-group" style="grid-column:1/-1;display:flex;gap:24px;">
              <label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-size:13px;">
                <input type="checkbox" v-model="form.is_scholarship" style="width:15px;height:15px;" />
                ទទួលបានអាហារូបករណ៍
              </label>
              <label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-size:13px;">
                <input type="checkbox" v-model="form.is_disability" style="width:15px;height:15px;" />
                មានពិការភាព
              </label>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក...' : isEdit ? 'រក្សាទុកការកែប្រែ' : 'បន្ថែមសិស្ស' }}</button>
        </div>
      </div>
    </div>

    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:380px;">
        <div class="modal-body" style="text-align:center;padding:32px 24px;">
          <TrashIcon class="w-10 h-10 text-gray-400" style="margin: 0 auto 12px;" />
          <h3 style="margin-bottom:8px;">លុបសិស្ស?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">អ្នកពិតជាចង់លុប <strong>{{ deleteTarget.full_name }}</strong> មែនទេ? រាល់ទិន្នន័យពាក់ព័ន្ធទាំងអស់នឹងត្រូវលុបចេញផងដែរ។</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រមលុប</button>
        </div>
      </div>
    </div>
  </div>
</template>
