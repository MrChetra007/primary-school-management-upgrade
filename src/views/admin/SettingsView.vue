<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { toInputDate, formatDate } from '@/utils/formatDate'
import { BuildingOfficeIcon, CalendarIcon, BookOpenIcon, CalendarDaysIcon, ClockIcon, ArrowDownTrayIcon, CheckIcon, XCircleIcon, SunIcon, InformationCircleIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const currentTab = ref('school')
const loading = ref(false)
const saving = ref(false)
const toast = ref(null)

const tabs = [
  { id: 'school', label: 'ព័ត៌មានសាលា' }, // School Info
  { id: 'years', label: 'ឆ្នាំសិក្សា' }, // Academic Years
  { id: 'subjects', label: 'មុខវិជ្ជា' }, // Subjects
  { id: 'holidays', label: 'ថ្ងៃឈប់សម្រាក' }, // Holidays
  { id: 'attendance', label: 'ការកំណត់វត្តមាន' }, // Attendance Config
]

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

// ── SCHOOL INFO ───────────────────────────────────────────
const schoolForm = ref({
  id: null, name_khmer: '', name_english: '', school_code: '',
  director_name: '', address: '', phone: '', email: '', logo_url: ''
})
const uploadingLogo = ref(false)

async function loadSchool() {
  loading.value = true
  const { data, error } = await supabase.from('school_information').select('*').limit(1).maybeSingle()
  if (error) {
    console.error('Error loading school info:', error)
    showToast(error.message, 'error')
  }
  if (data) Object.assign(schoolForm.value, data)
  loading.value = false
}

async function saveSchool() {
  saving.value = true
  const { id, ...payload } = schoolForm.value
  payload.updated_at = new Date().toISOString()
  const { error } = id 
    ? await supabase.from('school_information').update(payload).eq('id', id)
    : await supabase.from('school_information').insert({ ...payload, school_id: auth.schoolId })
  saving.value = false
  if (error) showToast(error.message, 'error')
  else showToast('បានរក្សាទុកព័ត៌មានសាលាដោយជោគជ័យ!')
}

async function uploadLogo(e) {
  const file = e.target.files[0]
  if (!file) return
  uploadingLogo.value = true
  const path = `logos/${Date.now()}.${file.name.split('.').pop()}`
  const { error } = await supabase.storage.from('school-logos').upload(path, file, { upsert: true })
  if (!error) {
    const { data } = supabase.storage.from('school-logos').getPublicUrl(path)
    schoolForm.value.logo_url = data.publicUrl
  } else {
    showToast(error.message, 'error')
  }
  uploadingLogo.value = false
}

// ── ACADEMIC YEARS ────────────────────────────────────────
const years = ref([])
const yearModal = ref(false)
const isYearEdit = ref(false)
const yearForm = ref({ id: null, year_name: '', start_date: '', end_date: '', status: 'active' })
const yearDeleteTarget = ref(null)

async function loadYears() {
  loading.value = true
  const { data } = await supabase.from('academic_years').select('*').order('start_date', { ascending: false })
  years.value = data || []
  loading.value = false
}

function openAddYear() { isYearEdit.value = false; yearForm.value = { id: null, year_name: '', start_date: '', end_date: '', status: 'active' }; yearModal.value = true }
function openEditYear(y) { isYearEdit.value = true; yearForm.value = { ...y, start_date: toInputDate(y.start_date), end_date: toInputDate(y.end_date) }; yearModal.value = true }

async function saveYear() {
  if (!yearForm.value.year_name.trim() || !yearForm.value.start_date || !yearForm.value.end_date) {
    showToast('សូមបំពេញចន្លោះទទេ', 'error'); return
  }
  saving.value = true
  const { id, ...payload } = yearForm.value
  const { error } = isYearEdit.value
    ? await supabase.from('academic_years').update(payload).eq('id', id)
    : await supabase.from('academic_years').insert({ ...payload, school_id: auth.schoolId })
  saving.value = false
  if (error) showToast(error.message, 'error')
  else { showToast('បានរក្សាទុកឆ្នាំសិក្សា!'); yearModal.value = false; loadYears() }
}

async function deleteYear() {
  const { error } = await supabase.from('academic_years').delete().eq('id', yearDeleteTarget.value.id)
  if (error) showToast(error.message, 'error')
  else { showToast('បានលុបឆ្នាំសិក្សា'); yearDeleteTarget.value = null; loadYears() }
}

// ── SUBJECTS ──────────────────────────────────────────────
const subjects = ref([])
const subjectModal = ref(false)
const isSubjectEdit = ref(false)
const subjectForm = ref({ id: null, subject_name: '' })
const subjectDeleteTarget = ref(null)

async function loadSubjects() {
  loading.value = true
  const { data, error } = await supabase.from('subjects').select('*').order('subject_name')
  if (error) {
    console.error('Error loading subjects:', error)
    showToast(error.message, 'error')
  }
  subjects.value = data || []
  loading.value = false
}

function openAddSubject() { isSubjectEdit.value = false; subjectForm.value = { id: null, subject_name: '' }; subjectModal.value = true }
function openEditSubject(s) { isSubjectEdit.value = true; subjectForm.value = { ...s }; subjectModal.value = true }

async function saveSubject() {
  if (!subjectForm.value.subject_name.trim()) { showToast('ទាមទារឈ្មោះមុខវិជ្ជា', 'error'); return }
  saving.value = true
  const { id, ...payload } = subjectForm.value
  const { error } = isSubjectEdit.value
    ? await supabase.from('subjects').update(payload).eq('id', id)
    : await supabase.from('subjects').insert({ ...payload, school_id: auth.schoolId })
  saving.value = false
  if (error) showToast(error.message, 'error')
  else { showToast('បានរក្សាទុកមុខវិជ្ជា!'); subjectModal.value = false; loadSubjects() }
}

async function deleteSubject() {
  const { error } = await supabase.from('subjects').delete().eq('id', subjectDeleteTarget.value.id)
  if (error) showToast(error.message, 'error')
  else { showToast('បានលុបមុខវិជ្ជា'); subjectDeleteTarget.value = null; loadSubjects() }
}

// ── HOLIDAYS ──────────────────────────────────────────────
const holidays = ref([])
const holidayModal = ref(false)
const isHolidayEdit = ref(false)
const holidayForm = ref({ id: null, name: '', start_date: '', end_date: '', academic_year_id: yearStore.selectedYearId })
const holidayDeleteTarget = ref(null)

async function loadHolidays() {
  loading.value = true
  const { data } = await supabase.from('school_holidays').select('*').eq('academic_year_id', yearStore.selectedYearId).order('start_date', { ascending: false })
  holidays.value = data || []
  loading.value = false
}

function openAddHoliday() { isHolidayEdit.value = false; holidayForm.value = { id: null, name: '', start_date: '', end_date: '', academic_year_id: yearStore.selectedYearId }; holidayModal.value = true }
function openEditHoliday(h) { isHolidayEdit.value = true; holidayForm.value = { ...h, start_date: toInputDate(h.start_date), end_date: toInputDate(h.end_date) }; holidayModal.value = true }

async function saveHoliday() {
  if (!holidayForm.value.name.trim() || !holidayForm.value.start_date || !holidayForm.value.end_date) {
    showToast('សូមបំពេញចន្លោះទទេ', 'error'); return
  }
  saving.value = true
  const { id, ...payload } = holidayForm.value
  const { error } = isHolidayEdit.value
    ? await supabase.from('school_holidays').update(payload).eq('id', id)
    : await supabase.from('school_holidays').insert({ ...payload, school_id: auth.schoolId })
  saving.value = false
  if (error) showToast(error.message, 'error')
  else { showToast('បានរក្សាទុកថ្ងៃឈប់សម្រាក!'); holidayModal.value = false; loadHolidays() }
}

async function deleteHoliday() {
  const { error } = await supabase.from('school_holidays').delete().eq('id', holidayDeleteTarget.value.id)
  if (error) showToast(error.message, 'error')
  else { showToast('បានលុបថ្ងៃឈប់សម្រាក'); holidayDeleteTarget.value = null; loadHolidays() }
}

// ── ATTENDANCE CONFIG ─────────────────────────────────────
const attConfig = ref({
  id: null,
  morning_start: '07:00',
  morning_late_threshold: '07:15',
  evening_start: '13:00',
  evening_late_threshold: '13:15'
})

async function loadAttConfig() {
  loading.value = true
  const { data } = await supabase.from('school_settings').select('*').limit(1).single()
  if (data) Object.assign(attConfig.value, data)
  loading.value = false
}

async function saveAttConfig() {
  saving.value = true
  const { id, ...payload } = attConfig.value
  payload.updated_at = new Date().toISOString()
  const { error } = await supabase.from('school_settings').update(payload).eq('id', id)
  saving.value = false
  if (error) showToast(error.message, 'error')
  else showToast('បានរក្សាទុកការកំណត់វត្តមានដោយជោគជ័យ!')
}

// Lifecycle
onMounted(() => {
  loadSchool()
})

function switchTab(id) {
  currentTab.value = id
  if (id === 'school') loadSchool()
  if (id === 'years') loadYears()
  if (id === 'subjects') loadSubjects()
  if (id === 'holidays') loadHolidays()
  if (id === 'attendance') loadAttConfig()
}

</script>

<template>
  <div class="settings-page">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`"><CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" /><XCircleIcon v-else class="w-4 h-4" /> {{ toast.msg }}</div>
    </div>

    <div class="page-header">
      <div><h1 class="page-title">ការកំណត់</h1><p class="page-subtitle">ការកំណត់ព័ត៌មានសាលា ឆ្នាំសិក្សា និងប្រព័ន្ធគ្រប់គ្រង</p></div>
    </div>

    <div class="tabs-nav">
      <button 
        v-for="tab in tabs" :key="tab.id"
        class="tab-btn" :class="{ active: currentTab === tab.id }"
        @click="switchTab(tab.id)"
      >
        {{ tab.label }}
      </button>
    </div>

    <div class="tab-content" style="margin-top:20px;">
      
      <div v-if="currentTab === 'school'" class="tab-pane">
        <div class="card">
          <div class="card-header"><span class="card-title">ព័ត៌មានសាលា</span><button class="btn btn-primary btn-sm" @click="saveSchool" :disabled="saving"><ArrowDownTrayIcon class="w-4 h-4" /> {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}</button></div>
          <div class="card-body" style="display:grid;grid-template-columns:200px 1fr;gap:24px;">
            <div style="display:flex;flex-direction:column;align-items:center;gap:12px;">
              <div class="logo-box">
                <img v-if="schoolForm.logo_url" :src="schoolForm.logo_url" />
                <BuildingOfficeIcon v-else class="w-10 h-10 text-gray-400" />
              </div>
              <label class="btn btn-ghost btn-sm">
                {{ uploadingLogo ? 'កំពុងផ្ទុក...' : 'បញ្ចូលរូបសញ្ញា' }}
                <input type="file" @change="uploadLogo" hidden accept="image/*" />
              </label>
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
              <div class="form-group" style="grid-column:1/-1;"><label class="form-label">ឈ្មោះ (ជាភាសាខ្មែរ)</label><input class="form-input khmer" v-model="schoolForm.name_khmer" /></div>
              <div class="form-group" style="grid-column:1/-1;"><label class="form-label">ឈ្មោះ (ជាភាសាអង់គ្លេស)</label><input class="form-input" v-model="schoolForm.name_english" /></div>
              <div class="form-group"><label class="form-label">កូដសាលា</label><input class="form-input" v-model="schoolForm.school_code" /></div>
              <div class="form-group"><label class="form-label">នាយកសាលា</label><input class="form-input" v-model="schoolForm.director_name" /></div>
              <div class="form-group"><label class="form-label">លេខទូរស័ព្ទ</label><input class="form-input" v-model="schoolForm.phone" /></div>
              <div class="form-group"><label class="form-label">អ៊ីម៉ែល</label><input class="form-input" v-model="schoolForm.email" /></div>
              <div class="form-group" style="grid-column:1/-1;"><label class="form-label">អាសយដ្ឋាន</label><textarea class="form-textarea" v-model="schoolForm.address" rows="2"></textarea></div>
            </div>
          </div>
        </div>
      </div>

      <div v-if="currentTab === 'years'" class="tab-pane">
        <div class="card">
          <div class="card-header"><span class="card-title">ឆ្នាំសិក្សា</span><button class="btn btn-primary btn-sm" @click="openAddYear">+ បន្ថែមឆ្នាំ</button></div>
          <div class="table-wrapper">
            <table>
              <thead><tr><th>ឈ្មោះឆ្នាំសិក្សា</th><th>កាលបរិច្ឆេទ</th><th>ស្ថានភាព</th><th>សកម្មភាព</th></tr></thead>
              <tbody>
                <tr v-for="y in years" :key="y.id">
                  <td><strong>{{ y.year_name }}</strong></td>
                  <td>{{ formatDate(y.start_date) }} - {{ formatDate(y.end_date) }}</td>
                  <td><span class="badge" :class="y.status === 'active' ? 'badge-green' : 'badge-gray'">{{ y.status }}</span></td>
                  <td>
                    <button class="btn btn-ghost btn-sm" @click="openEditYear(y)">កែប្រែ</button>
                    <button class="btn btn-ghost btn-sm text-danger" @click="yearDeleteTarget = y">លុប</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="currentTab === 'subjects'" class="tab-pane">
        <div class="card">
          <div class="card-header"><span class="card-title">មុខវិជ្ជា</span><button class="btn btn-primary btn-sm" @click="openAddSubject">+ បន្ថែមមុខវិជ្ជា</button></div>
          <div class="table-wrapper">
            <table>
              <thead><tr><th>ល.រ</th><th>ឈ្មោះមុខវិជ្ជា</th><th>សកម្មភាព</th></tr></thead>
              <tbody>
                <tr v-for="(s, idx) in subjects" :key="s.id">
                  <td>{{ idx + 1 }}</td>
                  <td><strong>{{ s.subject_name }}</strong></td>
                  <td>
                    <button class="btn btn-ghost btn-sm" @click="openEditSubject(s)">កែប្រែ</button>
                    <button class="btn btn-ghost btn-sm text-danger" @click="subjectDeleteTarget = s">លុប</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="currentTab === 'holidays'" class="tab-pane">
        <div class="card">
          <div class="card-header"><span class="card-title">ថ្ងៃឈប់សម្រាក ({{ yearStore.selectedYearName }})</span><button class="btn btn-primary btn-sm" @click="openAddHoliday">+ បន្ថែមថ្ងៃឈប់សម្រាក</button></div>
          <div class="table-wrapper">
            <table>
              <thead><tr><th>ឈ្មោះ</th><th>ចាប់ផ្តើម</th><th>បញ្ចប់</th><th>សកម្មភាព</th></tr></thead>
              <tbody>
                <tr v-for="h in holidays" :key="h.id">
                  <td><strong><SunIcon class="w-4 h-4 inline-block align-middle" /> {{ h.name }}</strong></td>
                  <td>{{ formatDate(h.start_date) }}</td>
                  <td>{{ formatDate(h.end_date) }}</td>
                  <td>
                    <button class="btn btn-ghost btn-sm" @click="openEditHoliday(h)">កែប្រែ</button>
                    <button class="btn btn-ghost btn-sm text-danger" @click="holidayDeleteTarget = h">លុប</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="currentTab === 'attendance'" class="tab-pane">
        <div class="card" style="max-width:600px;">
          <div class="card-header"><span class="card-title">ការកំណត់ម៉ោងវត្តមាន</span><button class="btn btn-primary btn-sm" @click="saveAttConfig" :disabled="saving"><ArrowDownTrayIcon class="w-4 h-4" /> {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}</button></div>
          <div class="card-body" style="display:grid;grid-template-columns:1fr 1fr;gap:20px;">
            <div class="form-group" style="grid-column:1/-1;margin-bottom:0;"><h4 style="color:var(--primary-color);">វេនព្រឹក</h4></div>
            <div class="form-group"><label class="form-label">ម៉ោងចូលរៀន</label><input type="time" class="form-input" v-model="attConfig.morning_start" /></div>
            <div class="form-group"><label class="form-label">ម៉ោងកំណត់យឺត</label><input type="time" class="form-input" v-model="attConfig.morning_late_threshold" /></div>
            
            <div class="form-group" style="grid-column:1/-1;margin-bottom:0;padding-top:10px;border-top:1px solid var(--border-default);"><h4 style="color:var(--primary-color);">វេនថ្ងៃត្រង់ / រសៀល</h4></div>
            <div class="form-group"><label class="form-label">ម៉ោងចូលរៀន</label><input type="time" class="form-input" v-model="attConfig.evening_start" /></div>
            <div class="form-group"><label class="form-label">ម៉ោងកំណត់យឺត</label><input type="time" class="form-input" v-model="attConfig.evening_late_threshold" /></div>
            
            <div style="grid-column:1/-1;background:var(--primary-50);padding:12px;border-radius:8px;font-size:12px;color:var(--primary-700);">
              <InformationCircleIcon class="w-4 h-4 inline-block align-middle" /> <strong>របៀបដំណើរការ៖</strong> ប្រសិនបើនរណាម្នាក់ចុចចូលរៀន<em>បន្ទាប់ពី</em>ម៉ោងកំណត់ ពួកគេនឹងត្រូវចាត់ទុកថា <strong>យឺត</strong> ដោយស្វ័យប្រវត្ត។ បើពុំនោះទេ ពួកគេត្រូវបានកត់ត្រាថា <strong>មានវត្តមាន</strong>។
            </div>
          </div>
        </div>
      </div>

    </div>

    <div v-if="yearModal" class="modal-overlay" @click.self="yearModal = false">
      <div class="modal" style="max-width:400px;">
        <div class="modal-header"><span class="modal-title">ឆ្នាំសិក្សា</span></div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:12px;">
          <div class="form-group"><label class="form-label">ឈ្មោះ</label><input class="form-input" v-model="yearForm.year_name" /></div>
          <div class="form-group"><label class="form-label">ចាប់ផ្តើម</label><input type="date" class="form-input" v-model="yearForm.start_date" /></div>
          <div class="form-group"><label class="form-label">បញ្ចប់</label><input type="date" class="form-input" v-model="yearForm.end_date" /></div>
          <div class="form-group"><label class="form-label">ស្ថានភាព</label><select class="form-select" v-model="yearForm.status"><option value="active">សកម្ម</option><option value="inactive">មិនសកម្ម</option></select></div>
        </div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="yearModal = false">បោះបង់</button><button class="btn btn-primary" @click="saveYear">រក្សាទុក</button></div>
      </div>
    </div>

    <div v-if="subjectModal" class="modal-overlay" @click.self="subjectModal = false">
      <div class="modal" style="max-width:400px;">
        <div class="modal-header"><span class="modal-title">មុខវិជ្ជា</span></div>
        <div class="modal-body"><div class="form-group"><label class="form-label">ឈ្មោះ</label><input class="form-input" v-model="subjectForm.subject_name" /></div></div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="subjectModal = false">បោះបង់</button><button class="btn btn-primary" @click="saveSubject">រក្សាទុក</button></div>
      </div>
    </div>

    <div v-if="holidayModal" class="modal-overlay" @click.self="holidayModal = false">
      <div class="modal" style="max-width:400px;">
        <div class="modal-header"><span class="modal-title">ថ្ងៃឈប់សម្រាក</span></div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:12px;">
          <div class="form-group"><label class="form-label">ឈ្មោះ</label><input class="form-input" v-model="holidayForm.name" /></div>
          <div class="form-group"><label class="form-label">ចាប់ផ្តើម</label><input type="date" class="form-input" v-model="holidayForm.start_date" /></div>
          <div class="form-group"><label class="form-label">បញ្ចប់</label><input type="date" class="form-input" v-model="holidayForm.end_date" /></div>
        </div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="holidayModal = false">បោះបង់</button><button class="btn btn-primary" @click="saveHoliday">រក្សាទុក</button></div>
      </div>
    </div>

    <div v-if="yearDeleteTarget" class="modal-overlay"><div class="modal" style="max-width:320px;padding:20px;text-align:center;"><h3>លុបឆ្នាំសិក្សានេះ?</h3><div class="modal-footer"><button class="btn btn-ghost" @click="yearDeleteTarget = null">បោះបង់</button><button class="btn btn-danger" @click="deleteYear">លុប</button></div></div></div>
    <div v-if="subjectDeleteTarget" class="modal-overlay"><div class="modal" style="max-width:320px;padding:20px;text-align:center;"><h3>លុបមុខវិជ្ជានេះ?</h3><div class="modal-footer"><button class="btn btn-ghost" @click="subjectDeleteTarget = null">បោះបង់</button><button class="btn btn-danger" @click="deleteSubject">លុប</button></div></div></div>
    <div v-if="holidayDeleteTarget" class="modal-overlay"><div class="modal" style="max-width:320px;padding:20px;text-align:center;"><h3>លុបថ្ងៃឈប់សម្រាកនេះ?</h3><div class="modal-footer"><button class="btn btn-ghost" @click="holidayDeleteTarget = null">បោះបង់</button><button class="btn btn-danger" @click="deleteHoliday">លុប</button></div></div></div>

  </div>
</template>
<style scoped>
.settings-page { padding: 0; }
.tabs-nav {
  display: flex;
  gap: 8px;
  border-bottom: 1px solid var(--border-default);
  padding: 0 4px;
}
.tab-btn {
  padding: 10px 16px;
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
  background: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  transition: all 0.2s;
}
.tab-btn:hover { color: var(--primary-color); }
.tab-btn.active {
  color: var(--primary-color);
  border-bottom-color: var(--primary-color);
}
.logo-box {
  width: 120px;
  height: 120px;
  background: #f1f5f9;
  border: 2px dashed var(--border-default);
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.logo-box img { width: 100%; height: 100%; object-fit: contain; }
.text-danger { color: #dc2626; }
</style>
