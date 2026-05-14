<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { CheckIcon, XCircleIcon, BuildingOfficeIcon, SunIcon, MoonIcon, TrashIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const classes = ref([])
const teachers = ref([])
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const toast = ref(null)
const search = ref('')

const emptyForm = () => ({ id: null, class_name: '', teacher_id: '', academic_year_id: yearStore.selectedYearId, turn: 'morning', subjects: [] })
const form = ref(emptyForm())
const allSubjects = ref([])

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return classes.value.filter(c => c.class_name.toLowerCase().includes(q))
})

onMounted(async () => {
  await Promise.all([loadClasses(), loadTeachers(), loadAllSubjects()])
})

async function loadClasses() {
  loading.value = true
  const { data } = await supabase
    .from('classes')
    .select(`
      *,
      teachers(full_name),
      academic_years(year_name),
      class_subjects(subject_id, subjects(subject_name))
    `)
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('class_name')
  classes.value = data || []
  loading.value = false
}

async function loadTeachers() {
  const { data } = await supabase.from('teachers').select('id, full_name').order('full_name')
  teachers.value = data || []
}

async function loadAllSubjects() {
  const { data } = await supabase.from('subjects').select('*').order('subject_name')
  allSubjects.value = data || []
}

function openAdd() { isEdit.value = false; form.value = emptyForm(); showModal.value = true }
async function openEdit(c) { 
  isEdit.value = true; 
  // Get existing subject IDs
  const subjectIds = c.class_subjects?.map(cs => cs.subject_id) || []
  form.value = { ...c, subjects: subjectIds }
  showModal.value = true 
}

async function save() {
  if (!form.value.class_name.trim()) { showToast('សូមបញ្ចូលឈ្មោះថ្នាក់រៀន', 'error'); return }
  saving.value = true
  
  const { id, teachers: _t, academic_years: _y, class_subjects: _cs, subjects: selectedSubjects, ...payload } = form.value
  
  // Sanitize optional UUIDs
  if (!payload.teacher_id) payload.teacher_id = null
  
  try {
    // 1. Save/Update Class
    const { data: classResult, error: classError } = isEdit.value
      ? await supabase.from('classes').update(payload).eq('id', id).select().single()
      : await supabase.from('classes').insert({ ...payload, school_id: auth.schoolId }).select().single()

    if (classError) throw classError

    const classId = classResult.id

    // 2. Sync Subjects
    if (isEdit.value) {
      // Delete old associations
      await supabase.from('class_subjects').delete().eq('class_id', classId)
    }

    if (selectedSubjects.length > 0) {
      const junctionData = selectedSubjects.map(sid => ({
        class_id: classId,
        subject_id: sid,
        school_id: auth.schoolId
      }))
      const { error: syncError } = await supabase.from('class_subjects').insert(junctionData)
      if (syncError) throw syncError
    }

    showToast(isEdit.value ? 'បានកែប្រែថ្នាក់រៀន!' : 'បានបន្ថែមថ្នាក់រៀន!', 'success')
    showModal.value = false
    loadClasses()
  } catch (error) {
    showToast(error.message, 'error')
  } finally {
    saving.value = false
  }
}

async function doDelete() {
  const { error } = await supabase.from('classes').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបថ្នាក់រៀន', 'success')
  loadClasses()
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}
</script>

<template>
  <div>
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`"><CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" /><XCircleIcon v-else class="w-4 h-4" /> {{ toast.msg }}</div>
    </div>
    <div class="page-header">
      <div><h1 class="page-title">ថ្នាក់រៀន</h1><p class="page-subtitle">{{ classes.length }} ថ្នាក់រៀនសកម្ម</p></div>
      <button class="btn btn-primary" @click="openAdd">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        បន្ថែមថ្នាក់រៀន
      </button>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរកថ្នាក់រៀន..." />
      </div>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:44px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <BuildingOfficeIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">មិនទាន់មានថ្នាក់រៀនទេ</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមថ្នាក់រៀន</button>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead><tr><th>ឈ្មោះថ្នាក់</th><th>គ្រូបង្រៀន</th><th>មុខវិជ្ជា</th><th>វេនរៀន</th><th>សកម្មភាព</th></tr></thead>
          <tbody>
            <tr v-for="c in filtered" :key="c.id">
              <td style="font-weight:600;">{{ c.class_name }}</td>
              <td>{{ c.teachers?.full_name || '—' }}</td>
              <td>
                <div class="subject-tags">
                  <span v-for="cs in c.class_subjects" :key="cs.subject_id" class="badge badge-gray" style="font-size:10px;">
                    {{ cs.subjects?.subject_name }}
                  </span>
                  <span v-if="!c.class_subjects?.length" class="text-secondary" style="font-size:11px;">គ្មានមុខវិជ្ជា</span>
                </div>
              </td>
              <td>
                <span class="badge" :class="c.turn === 'morning' ? 'badge-blue' : 'badge-yellow'">
                  <SunIcon v-if="c.turn === 'morning'" class="w-4 h-4" /><MoonIcon v-else class="w-4 h-4" /> {{ c.turn === 'morning' ? 'ព្រឹក' : 'រសៀល' }}
                </span>
              </td>
              <td>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(c)">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = c">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែថ្នាក់រៀន' : 'បន្ថែមថ្នាក់រៀន' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
        </div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group">
            <label class="form-label">ឈ្មោះថ្នាក់រៀន *</label>
            <input class="form-input" v-model="form.class_name" placeholder="ឧ. ថ្នាក់ទី១ (A)" />
          </div>
          <div class="form-group">
            <label class="form-label">គ្រូបង្រៀន</label>
            <select class="form-select" v-model="form.teacher_id">
              <option value="">— គ្មាន —</option>
              <option v-for="t in teachers" :key="t.id" :value="t.id">{{ t.full_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">វេនរៀន</label>
            <select class="form-select" v-model="form.turn">
              <option value="morning">ព្រឹក</option>
              <option value="afternoon">រសៀល</option>
            </select>
          </div>

          <div class="form-group">
            <label class="form-label">មុខវិជ្ជា</label>
            <div class="subject-selection-grid">
              <label v-for="s in allSubjects" :key="s.id" class="subject-checkbox">
                <input type="checkbox" :value="s.id" v-model="form.subjects" />
                <span>{{ s.subject_name }}</span>
              </label>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក...' : isEdit ? 'រក្សាទុកការកែប្រែ' : 'បន្ថែមថ្នាក់' }}</button>
        </div>
      </div>
    </div>

    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:360px;">
        <div class="modal-body" style="text-align:center;padding:28px 24px;">
          <TrashIcon class="w-10 h-10 text-gray-400" style="margin: 0 auto 12px;" />
          <h3 style="margin-bottom:8px;">លុបថ្នាក់រៀននេះ?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">អ្នកពិតជាចង់លុប <strong>{{ deleteTarget.class_name }}</strong> មែនទេ?</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រមលុប</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.subject-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.subject-selection-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 8px;
  max-height: 200px;
  overflow-y: auto;
  padding: 12px;
  background: var(--bg-secondary);
  border-radius: 8px;
  border: 1px solid var(--border-default);
}

.subject-checkbox {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
}

.subject-checkbox:hover {
  background: var(--bg-hover);
}

.subject-checkbox input {
  width: 16px;
  height: 16px;
}
</style>
