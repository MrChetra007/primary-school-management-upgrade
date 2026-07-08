<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { toInputDate, formatDate } from '@/utils/formatDate'
import { getKhmerHolidays } from 'khmer-chhankitek-calendar'
import { BuildingOfficeIcon, CalendarIcon, BookOpenIcon, CalendarDaysIcon, ClockIcon, ArrowDownTrayIcon, CheckIcon, XCircleIcon, SunIcon, InformationCircleIcon, SparklesIcon } from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'

const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const { showToast } = useToast()
const currentTab = ref('school')
const loading = ref(false)
const saving = ref(false)

const monthNames = ['មករា','កុម្ភៈ','មីនា','មេសា','ឧសភា','មិថុនា','កក្កដា','សីហា','កញ្ញា','តុលា','វិច្ឆិកា','ធ្នូ']

const tabs = [
  { id: 'school', label: 'ព័ត៌មានសាលា' },
  { id: 'years', label: 'ឆ្នាំសិក្សា' },
  { id: 'subjects', label: 'មុខវិជ្ជា' },
  { id: 'holidays', label: 'ថ្ងៃឈប់សម្រាក' },
  { id: 'attendance', label: 'ការកំណត់វត្តមាន' },
  { id: 'semester', label: 'ការកំណត់ឆមាស' },
  { id: 'signature', label: 'ហត្ថលេខា និងត្រា' },
]

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
  const { error } = await supabase.storage.from('teacher-profiles').upload(path, file, { upsert: true })
  if (!error) {
    const { data } = supabase.storage.from('teacher-profiles').getPublicUrl(path)
    schoolForm.value.logo_url = data.publicUrl
  } else {
    showToast(error.message, 'error')
  }
  uploadingLogo.value = false
}

async function uploadSignature(e) {
  const file = e.target.files[0]
  if (!file) return
  uploadingLogo.value = true
  const path = `${auth.schoolId}/signature.${file.name.split('.').pop()}`
  const { error } = await supabase.storage.from('school-assets').upload(path, file, { upsert: true })
  if (!error) {
    const { data } = supabase.storage.from('school-assets').getPublicUrl(path)
    schoolForm.value.signature_url = data.publicUrl
  } else {
    showToast(error.message, 'error')
  }
  uploadingLogo.value = false
}

async function uploadStamp(e) {
  const file = e.target.files[0]
  if (!file) return
  uploadingLogo.value = true
  const path = `${auth.schoolId}/stamp.${file.name.split('.').pop()}`
  const { error } = await supabase.storage.from('school-assets').upload(path, file, { upsert: true })
  if (!error) {
    const { data } = supabase.storage.from('school-assets').getPublicUrl(path)
    schoolForm.value.stamp_url = data.publicUrl
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

const importingHolidays = ref(false)

async function importKhmerHolidays() {
  const { data: year } = await supabase
    .from('academic_years')
    .select('start_date, end_date')
    .eq('id', yearStore.selectedYearId)
    .single()
  if (!year) { showToast('មិនអាចទាញទិន្នន័យឆ្នាំសិក្សា', 'error'); return }

  const startYear = new Date(year.start_date).getFullYear()
  const endYear = new Date(year.end_date).getFullYear()
  const years = []
  for (let y = startYear; y <= endYear; y++) years.push(y)

  importingHolidays.value = true
  const all = years.flatMap(y => getKhmerHolidays(y))
  const seen = new Set()
  const merged = []
  for (const h of all) {
    const key = h.date + '|' + h.nameKm
    if (seen.has(key)) continue
    seen.add(key)
    merged.push(h)
  }

  const existing = new Set(holidays.value.map(h => h.name + '|' + h.start_date))
  const newHolidays = merged.filter(h => !existing.has(h.nameKm + '|' + h.date))

  if (newHolidays.length === 0) {
    showToast('ថ្ងៃឈប់សម្រាកទាំងអស់មានរួចហើយ', 'info')
    importingHolidays.value = false
    return
  }

  const rows = newHolidays.map(h => ({
    school_id: auth.schoolId,
    academic_year_id: yearStore.selectedYearId,
    name: h.nameKm,
    start_date: h.date,
    end_date: h.date
  }))

  const { error } = await supabase.from('school_holidays').insert(rows)
  importingHolidays.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast(`បានបន្ថែមថ្ងៃឈប់សម្រាកចំនួន ${rows.length} ថ្ងៃដោយជោគជ័យ!`, 'success')
  loadHolidays()
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

// ── SEMESTER CONFIG ────────────────────────────────────────
const semesterList = ref([])

async function loadSemesterConfig() {
  if (!yearStore.selectedYearId) {
    semesterList.value = []
    return
  }
  loading.value = true
  const { data } = await supabase
    .from('semester_config')
    .select('*')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('semester')
  const defaults = {
    1: { semester: 1, months: [12, 1, 2], exam_month: 3 },
    2: { semester: 2, months: [5, 6, 7], exam_month: 8 }
  }
  const fromDb = {}
  ;(data || []).forEach(s => { fromDb[s.semester] = { ...s, months: s.months || [] } })
  semesterList.value = [1, 2].map(sem => fromDb[sem] || { ...defaults[sem] })
  loading.value = false
}

async function saveSemesterConfig(sem) {
  saving.value = true
  const { id, school_id, created_at, updated_at, ...payload } = sem
  payload.months = payload.months.map(Number).sort((a, b) => a - b)
  const { error } = id
    ? await supabase.from('semester_config').update(payload).eq('id', id)
    : await supabase.from('semester_config').insert({
        ...payload,
        school_id: auth.schoolId,
        academic_year_id: yearStore.selectedYearId
      })
  saving.value = false
  if (error) showToast(error.message, 'error')
  else { showToast('បានរក្សាទុកការកំណត់ឆមាស!'); loadSemesterConfig() }
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
  if (id === 'semester') loadSemesterConfig()
  if (id === 'signature') loadSchool()
}

</script>

<template>
  <div class="settings-page">
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
          <div class="card-header"><span class="card-title">ថ្ងៃឈប់សម្រាក ({{ yearStore.selectedYearName }})</span><div style="display:flex;gap:8px;"><button class="btn btn-secondary btn-sm" @click="importKhmerHolidays" :disabled="importingHolidays"><SparklesIcon class="w-4 h-4" /> {{ importingHolidays ? 'កំពុងដំណើរការ...' : 'បន្ថែមតាមប្រតិទិនខ្មែរ' }}</button><button class="btn btn-primary btn-sm" @click="openAddHoliday">+ បន្ថែម</button></div></div>
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

      <div v-if="currentTab === 'signature'" class="tab-pane">
        <div class="card">
          <div class="card-header"><span class="card-title">ហត្ថលេខា និងត្រាសាលា</span><button class="btn btn-primary btn-sm" @click="saveSchool" :disabled="saving"><ArrowDownTrayIcon class="w-4 h-4" /> {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}</button></div>
          <div class="card-body" style="display:grid;grid-template-columns:1fr 1fr;gap:24px;">
            <div style="display:flex;flex-direction:column;align-items:center;gap:12px;">
              <label class="form-label" style="align-self:flex-start;">ហត្ថលេខានាយក</label>
              <div class="asset-box">
                <img v-if="schoolForm.signature_url" :src="schoolForm.signature_url" class="asset-preview" />
                <svg v-else viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5" width="40" height="40">
                  <path d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0z"/>
                  <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
              </div>
              <label class="btn btn-ghost btn-sm">
                {{ uploadingLogo ? 'កំពុងផ្ទុក...' : 'បញ្ចូលរូបហត្ថលេខា' }}
                <input type="file" @change="uploadSignature" hidden accept="image/*" />
              </label>
              <p style="font-size:11px;color:var(--text-secondary);text-align:center;">រូបភាពហត្ថលេខារបស់នាយកសាលា នឹងបង្ហាញនៅលើរបាយការណ៍របស់សិស្ស</p>
            </div>
            <div style="display:flex;flex-direction:column;align-items:center;gap:12px;">
              <label class="form-label" style="align-self:flex-start;">ត្រាសាលា</label>
              <div class="asset-box">
                <img v-if="schoolForm.stamp_url" :src="schoolForm.stamp_url" class="asset-preview" />
                <svg v-else viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5" width="40" height="40">
                  <rect x="3" y="11" width="18" height="11" rx="2"/>
                  <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                </svg>
              </div>
              <label class="btn btn-ghost btn-sm">
                {{ uploadingLogo ? 'កំពុងផ្ទុក...' : 'បញ្ចូលរូបត្រា' }}
                <input type="file" @change="uploadStamp" hidden accept="image/*" />
              </label>
              <p style="font-size:11px;color:var(--text-secondary);text-align:center;">ត្រាផ្លូវការរបស់សាលា នឹងបង្ហាញនៅលើរបាយការណ៍របស់សិស្ស</p>
            </div>
          </div>
        </div>
      </div>

      <div v-if="currentTab === 'semester'" class="tab-pane">
        <div v-if="!yearStore.selectedYearId" class="card">
          <div class="card-body" style="text-align:center;padding:40px;color:var(--text-secondary);">
            <InformationCircleIcon class="w-10 h-10 mx-auto mb-3" />
            <p>សូមជ្រើសរើសឆ្នាំសិក្សាជាមុនសិន</p>
            <p style="font-size:13px;">ចូលទៅកាន់ផ្ទាំង "ឆ្នាំសិក្សា" ហើយចុច "មើល" លើឆ្នាំសិក្សាដែលអ្នកចង់កំណត់</p>
          </div>
        </div>
        <div v-else style="display:grid;grid-template-columns:1fr 1fr;gap:20px;align-items:start;">
          <div class="card" v-for="sem in semesterList" :key="sem.semester">
            <div class="card-header">
              <span class="card-title"><CalendarIcon class="w-4 h-4 inline-block align-middle" /> ឆមាសទី {{ sem.semester }}</span>
              <button class="btn btn-primary btn-sm" @click="saveSemesterConfig(sem)" :disabled="saving">
                <ArrowDownTrayIcon class="w-4 h-4" /> {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
              </button>
            </div>
            <div class="card-body" style="display:flex;flex-direction:column;gap:16px;">
              <div>
                <label class="form-label">ខែក្នុងឆមាស</label>
                <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:8px;">
                  <label v-for="m in 12" :key="m" class="month-chk"
                    :class="{ selected: sem.months.includes(m) }">
                    <input type="checkbox" :value="m" v-model="sem.months" class="month-chk-input" />
                    <span>{{ monthNames[m - 1] }}</span>
                  </label>
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">ខែប្រឡង</label>
                <select class="form-select" v-model="sem.exam_month">
                  <option v-for="m in 12" :key="m" :value="m">{{ monthNames[m - 1] }}</option>
                </select>
              </div>
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
.asset-box {
  width: 180px;
  height: 180px;
  background: #f1f5f9;
  border: 2px dashed var(--border-default);
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.asset-preview {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.month-chk {
  display: flex; align-items: center; gap: 6px;
  padding: 6px 10px; border-radius: 8px;
  border: 1px solid var(--border-default);
  cursor: pointer; font-size: 13px;
  transition: all 0.15s;
  user-select: none;
}
.month-chk:hover { border-color: var(--primary-color); background: var(--primary-50); }
.month-chk.selected { border-color: var(--primary-color); background: var(--primary-50); color: var(--primary-color); font-weight: 600; }
.month-chk-input { display: none; }
</style>
