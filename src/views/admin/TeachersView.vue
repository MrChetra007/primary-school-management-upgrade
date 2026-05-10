<script setup>
import { ref, computed, onMounted } from 'vue'
import { CheckIcon, XCircleIcon, AcademicCapIcon, CameraIcon, TrashIcon } from '@heroicons/vue/24/outline'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { formatDate, toInputDate } from '@/utils/formatDate'

const auth = useAuthStore()
const teachers = ref([])
const loading = ref(true)
const saving = ref(false)
const search = ref('')
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const toast = ref(null)
const uploadingPhoto = ref(false)

const form = ref({
  id: null, full_name: '', gender: '', dob: '',
  phone_number: '', degree: '', address: '', email: '', profile_url: ''
})

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return teachers.value.filter(t =>
    t.full_name.toLowerCase().includes(q) ||
    (t.email || '').toLowerCase().includes(q) ||
    (t.phone_number || '').includes(q)
  )
})

onMounted(load)

async function load() {
  loading.value = true
  const { data } = await supabase.from('teachers').select('*').order('full_name')
  teachers.value = data || []
  loading.value = false
}

function openAdd() {
  isEdit.value = false
  form.value = { id: null, full_name: '', gender: '', dob: '', phone_number: '', degree: '', address: '', email: '', profile_url: '' }
  showModal.value = true
}

function openEdit(t) {
  isEdit.value = true
  form.value = { ...t, dob: toInputDate(t.dob) }
  showModal.value = true
}

async function uploadPhoto(e) {
  const file = e.target.files[0]
  if (!file) return
  uploadingPhoto.value = true
  const path = `${Date.now()}.${file.name.split('.').pop()}`
  const { error } = await supabase.storage.from('teacher-profiles').upload(path, file, { upsert: true })
  if (!error) {
    const { data } = supabase.storage.from('teacher-profiles').getPublicUrl(path)
    form.value.profile_url = data.publicUrl
  }
  uploadingPhoto.value = false
}

async function save() {
  if (!form.value.full_name.trim()) { showToast('សូមបំពេញឈ្មោះ', 'error'); return }
  saving.value = true
  const { id, ...payload } = form.value
  const { error } = isEdit.value
    ? await supabase.from('teachers').update(payload).eq('id', id)
    : await supabase.from('teachers').insert({ ...payload, school_id: auth.schoolId })
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast(isEdit.value ? 'បានកែប្រែព័ត៌មានបុគ្គលិក!' : 'បានបន្ថែមបុគ្គលិកថ្មី!', 'success')
  showModal.value = false
  load()
}

async function doDelete() {
  const { error } = await supabase.from('teachers').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបបុគ្គលិក', 'success')
  load()
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
        <h1 class="page-title">ប្រវត្តិរូបបុគ្គលិក</h1>
        <p class="page-subtitle">ប្រវត្តិរូបផ្ទាល់ខ្លួនសម្រាប់បុគ្គលិកទាំងអស់ (រដ្ឋបាល, គ្រូបង្រៀន, បណ្ណារក្ស)</p>
      </div>
      <div class="badge badge-gray">កម្មវិធីគ្រប់គ្រងអត្តសញ្ញាណ</div>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរកតាមឈ្មោះ, អ៊ីមែល, ឬលេខទូរស័ព្ទ..." />
      </div>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <AcademicCapIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">រកមិនឃើញបុគ្គលិកទេ</p>
        <p class="empty-state-desc">បន្ថែមបុគ្គលិកដំបូងរបស់អ្នកដើម្បីចាប់ផ្តើម</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមបុគ្គលិក</button>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr><th>បុគ្គលិក</th><th>ភេទ</th><th>លេខទូរស័ព្ទ</th><th>សញ្ញាបត្រ</th><th>អ៊ីមែល</th><th>សកម្មភាព</th></tr>
          </thead>
          <tbody>
            <tr v-for="t in filtered" :key="t.id">
              <td>
                <div style="display:flex;align-items:center;gap:10px;">
                  <div class="avatar">
                    <img v-if="t.profile_url" :src="t.profile_url" :alt="t.full_name" style="width:100%;height:100%;object-fit:cover;border-radius:50%;"/>
                    <template v-else>{{ initials(t.full_name) }}</template>
                  </div>
                  <div>
                    <div style="font-weight:600;font-size:13px;">{{ t.full_name }}</div>
                    <div style="font-size:11px;color:var(--text-muted);">{{ formatDate(t.dob) }}</div>
                  </div>
                </div>
              </td>
              <td><span class="badge" :class="t.gender === 'Male' ? 'badge-blue' : 'badge-red'">{{ t.gender === 'Male' ? 'ប្រុស' : (t.gender === 'Female' ? 'ស្រី' : '—') }}</span></td>
              <td style="font-size:13px;">{{ t.phone_number || '—' }}</td>
              <td style="font-size:13px;">{{ t.degree || '—' }}</td>
              <td style="font-size:13px;">{{ t.email || '—' }}</td>
              <td>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(t)">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = t">
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
          <span class="modal-title">{{ isEdit ? 'កែប្រែព័ត៌មានបុគ្គលិក' : 'បន្ថែមបុគ្គលិកថ្មី' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body">
          <div style="display:flex;align-items:center;gap:16px;margin-bottom:20px;padding-bottom:16px;border-bottom:1px solid var(--border-default);">
            <div class="avatar avatar-xl">
              <img v-if="form.profile_url" :src="form.profile_url" style="width:100%;height:100%;object-fit:cover;border-radius:50%;"/>
              <template v-else>{{ initials(form.full_name || 'T') }}</template>
            </div>
            <div>
              <label class="btn btn-ghost btn-sm" style="cursor:pointer;">
                <CameraIcon class="w-4 h-4" /> {{ uploadingPhoto ? 'កំពុងផ្ទុកឡើង...' : 'បង្ហោះរូបភាព' }}
                <input type="file" accept="image/*" style="display:none;" @change="uploadPhoto" :disabled="uploadingPhoto"/>
              </label>
              <p style="font-size:11px;color:var(--text-muted);margin-top:6px;">JPG, PNG — រក្សាទុកក្នុង Supabase Storage</p>
            </div>
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
            <div class="form-group" style="grid-column:1/-1;">
              <label class="form-label">ឈ្មោះពេញ *</label>
              <input class="form-input" v-model="form.full_name" placeholder="ឧ. សុខ ដារ៉ា" />
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
              <label class="form-label">ថ្ងៃខែឆ្នាំកំណើត</label>
              <input class="form-input" type="date" v-model="form.dob" />
            </div>
            <div class="form-group">
              <label class="form-label">លេខទូរស័ព្ទ</label>
              <input class="form-input" v-model="form.phone_number" placeholder="012 345 678" />
            </div>
            <div class="form-group">
              <label class="form-label">អ៊ីមែល</label>
              <input class="form-input" type="email" v-model="form.email" placeholder="teacher@school.edu" />
            </div>
            <div class="form-group" style="grid-column:1/-1;">
              <label class="form-label">សញ្ញាបត្រ / កម្រិតវប្បធម៌</label>
              <input class="form-input" v-model="form.degree" placeholder="ឧ. បរិញ្ញាបត្រអប់រំ" />
            </div>
            <div class="form-group" style="grid-column:1/-1;">
              <label class="form-label">អាសយដ្ឋាន</label>
              <textarea class="form-textarea" v-model="form.address" placeholder="អាសយដ្ឋានផ្ទះ" rows="2"></textarea>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក...' : isEdit ? 'រក្សាទុកការកែប្រែ' : 'បន្ថែមបុគ្គលិក' }}</button>
        </div>
      </div>
    </div>

    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:380px;">
        <div class="modal-body" style="text-align:center;padding:32px 24px;">
          <TrashIcon class="w-10 h-10 text-gray-400" style="margin: 0 auto 12px;" />
          <h3 style="margin-bottom:8px;">លុបបុគ្គលិក?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">អ្នកពិតជាចង់លុប <strong>{{ deleteTarget.full_name }}</strong> មែនទេ? សកម្មភាពនេះមិនអាចបញ្ច្រាសវិញបានទេ។</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រម លុប</button>
        </div>
      </div>
    </div>
  </div>
</template>
