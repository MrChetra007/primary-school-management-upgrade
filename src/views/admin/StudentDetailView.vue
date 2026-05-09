<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { HeartIcon, PlusCircleIcon, ArrowsUpDownIcon, BeakerIcon, FaceFrownIcon, ArrowDownTrayIcon, CheckIcon, XCircleIcon, ClockIcon, CalendarIcon, ArrowsRightLeftIcon } from '@heroicons/vue/24/outline'
import { Line } from 'vue-chartjs'
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  Legend,
  LineElement,
  LinearScale,
  PointElement,
  CategoryScale
} from 'chart.js'

ChartJS.register(
  Title,
  Tooltip,
  Legend,
  LineElement,
  LinearScale,
  PointElement,
  CategoryScale
)

const route = useRoute()
const router = useRouter()
const studentId = route.params.id

const student = ref(null)
const health = ref(null)
const checkups = ref([])
const growth = ref([])
const vaccinations = ref([])
const sickDays = ref([])
const loading = ref(true)
const saving = ref(false)
const toast = ref(null)
const activeTab = ref('health')

// Chart Options
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      display: true,
      position: 'top'
    }
  },
  scales: {
    y: {
      beginAtZero: false
    }
  }
}

// Growth Summary & Progress
const latestGrowth = computed(() => {
  if (growth.value.length === 0) return null
  return growth.value[0]
})

const growthHistory = computed(() => {
  return growth.value.map((g, index) => {
    const prev = growth.value[index + 1]
    return {
      ...g,
      heightDelta: prev ? (g.height - prev.height).toFixed(1) : null,
      weightDelta: prev ? (g.weight - prev.weight).toFixed(1) : null
    }
  })
})

// Sick Days form
const showSickDayModal = ref(false)
const sickDayForm = ref({ id: null, date: '', reason: '', duration: 1, notes: '' })

// Health form
const healthForm = ref({ id: null, blood_type: '', allergies: '', medical_conditions: '', emergency_contact_name: '', emergency_contact_phone: '', vaccination_complete: false })
const showCheckupModal = ref(false)
const checkupForm = ref({ id: null, date: '', type: '', result: '', vision: '', hearing: '', dental: '', notes: '' })
const showGrowthModal = ref(false)
const growthForm = ref({ id: null, date: '', age: '', height: '', weight: '' })
const showVaccineModal = ref(false)
const vaccineForm = ref({ id: null, name: '', description: '', completed: false, date: '' })

onMounted(async () => {
  await Promise.all([loadStudent(), loadHealth(), loadCheckups(), loadGrowth(), loadVaccinations(), loadSickDays()])
  loading.value = false
})

async function loadStudent() {
  const { data } = await supabase.from('students').select('*, classes(class_name), academic_years(year_name)').eq('id', studentId).single()
  student.value = data
}
async function loadHealth() {
  const { data } = await supabase.from('student_health').select('*').eq('student_id', studentId).maybeSingle()
  if (data) { health.value = data; Object.assign(healthForm.value, data) }
}
async function loadCheckups() {
  const { data } = await supabase.from('student_checkups').select('*').eq('student_id', studentId).order('date', { ascending: false })
  checkups.value = data || []
}
async function loadGrowth() {
  const { data } = await supabase.from('student_growth').select('*').eq('student_id', studentId).order('date', { ascending: false })
  growth.value = data || []
}
async function loadVaccinations() {
  const { data } = await supabase.from('student_vaccinations').select('*').eq('student_id', studentId).order('date', { ascending: false })
  vaccinations.value = data || []
}
async function loadSickDays() {
  const { data } = await supabase.from('student_sick_days').select('*').eq('student_id', studentId).order('date', { ascending: false })
  sickDays.value = data || []
}

async function saveHealth() {
  saving.value = true
  const payload = { ...healthForm.value, student_id: studentId, updated_at: new Date().toISOString().split('T')[0] }
  const { error } = health.value
    ? await supabase.from('student_health').update(payload).eq('id', health.value.id)
    : await supabase.from('student_health').insert(payload)
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានរក្សាទុកព័ត៌មានសុខភាព!', 'success')
  loadHealth()
}

async function saveCheckup() {
  saving.value = true
  const { id, ...payload } = { ...checkupForm.value, student_id: studentId }
  const { error } = id
    ? await supabase.from('student_checkups').update(payload).eq('id', id)
    : await supabase.from('student_checkups').insert(payload)
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានរក្សាទុកការពិនិត្យសុខភាព!', 'success')
  showCheckupModal.value = false
  loadCheckups()
}

async function saveGrowth() {
  saving.value = true
  const { id, ...payload } = { ...growthForm.value, student_id: studentId }
  const { error } = id
    ? await supabase.from('student_growth').update(payload).eq('id', id)
    : await supabase.from('student_growth').insert(payload)
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានរក្សាទុកកំណត់ត្រាកំណើន!', 'success')
  showGrowthModal.value = false
  loadGrowth()
}

async function saveVaccine() {
  saving.value = true
  const { id, ...payload } = { ...vaccineForm.value, student_id: studentId }
  const { error } = id
    ? await supabase.from('student_vaccinations').update(payload).eq('id', id)
    : await supabase.from('student_vaccinations').insert(payload)
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានរក្សាទុកវ៉ាក់សាំង!', 'success')
  showVaccineModal.value = false
  loadVaccinations()
}

async function saveSickDay() {
  saving.value = true
  const { id, ...payload } = { ...sickDayForm.value, student_id: studentId }
  const { error } = id
    ? await supabase.from('student_sick_days').update(payload).eq('id', id)
    : await supabase.from('student_sick_days').insert(payload)
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានរក្សាទុកថ្ងៃឈឺ!', 'success')
  showSickDayModal.value = false
  loadSickDays()
}

async function deleteSickDay(id) {
  if (!confirm('តើអ្នកពិតជាចង់លុបកំណត់ត្រាថ្ងៃឈឺនេះមែនទេ?')) return
  const { error } = await supabase.from('student_sick_days').delete().eq('id', id)
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបថ្ងៃឈឺ', 'success')
  loadSickDays()
}

function openCheckup(c = null) {
  checkupForm.value = c ? { ...c, date: toInputDate(c.date) } : { id: null, date: '', type: '', result: '', vision: '', hearing: '', dental: '', notes: '' }
  showCheckupModal.value = true
}
function openGrowth(g = null) {
  growthForm.value = g ? { ...g, date: toInputDate(g.date) } : { id: null, date: '', age: '', height: '', weight: '' }
  showGrowthModal.value = true
}
function openVaccine(v = null) {
  vaccineForm.value = v ? { ...v, date: toInputDate(v.date) } : { id: null, name: '', description: '', completed: false, date: '' }
  showVaccineModal.value = true
}
function openSickDay(s = null) {
  sickDayForm.value = s ? { ...s, date: toInputDate(s.date) } : { id: null, date: '', reason: '', duration: 1, notes: '' }
  showSickDayModal.value = true
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

function initials(name) {
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()
}
</script>

<template>
  <div>
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`"><component :is="toast.type === 'success' ? CheckIcon : XCircleIcon" class="w-4 h-4" /> {{ toast.msg }}</div>
    </div>

    <div style="margin-bottom:16px;">
      <button class="btn btn-ghost btn-sm" @click="router.back()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:14px;height:14px"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
        ត្រឡប់ក្រោយ
      </button>
    </div>

    <div v-if="loading" class="card card-body">
      <div v-for="i in 4" :key="i" class="skeleton" style="height:48px;margin-bottom:14px;border-radius:8px;"></div>
    </div>

    <template v-else-if="student">
      <div class="card" style="margin-bottom:20px;">
        <div class="card-body" style="display:flex;align-items:center;gap:20px;">
          <div class="avatar avatar-xl">{{ initials(student.full_name) }}</div>
          <div style="flex:1;">
            <h2 style="font-size:22px;font-weight:700;margin-bottom:4px;">{{ student.full_name }}</h2>
            <div style="display:flex;gap:8px;flex-wrap:wrap;">
              <span class="badge" :class="student.gender === 'Male' ? 'badge-blue' : 'badge-red'">{{ student.gender === 'Male' ? 'ប្រុស' : (student.gender === 'Female' ? 'ស្រី' : '—') }}</span>
              <span class="badge badge-gray">{{ formatDate(student.dob) }}</span>
              <span class="badge badge-purple">{{ student.classes?.class_name || 'គ្មានថ្នាក់' }}</span>
              <span v-if="student.is_scholarship" class="badge badge-green">អាហារូបករណ៍</span>
              <span v-if="student.is_disability" class="badge badge-yellow">មានពិការភាព</span>
            </div>
          </div>
          <div style="text-align:right;font-size:12px;color:var(--text-muted);">
            <div>អត្តលេខ: {{ student.real_id || '—' }}</div>
            <div>{{ student.academic_years?.year_name || '' }}</div>
          </div>
        </div>
      </div>

      <div class="tabs">
        <div class="tab-item" :class="{ active: activeTab === 'health' }" @click="activeTab = 'health'"><HeartIcon class="w-4 h-4" /> សុខភាព</div>
        <div class="tab-item" :class="{ active: activeTab === 'checkups' }" @click="activeTab = 'checkups'"><PlusCircleIcon class="w-4 h-4" /> ការពិនិត្យ</div>
        <div class="tab-item" :class="{ active: activeTab === 'growth' }" @click="activeTab = 'growth'"><ArrowsUpDownIcon class="w-4 h-4" /> កំណើន</div>
        <div class="tab-item" :class="{ active: activeTab === 'vaccinations' }" @click="activeTab = 'vaccinations'"><BeakerIcon class="w-4 h-4" /> វ៉ាក់សាំង</div>
        <div class="tab-item" :class="{ active: activeTab === 'sickdays' }" @click="activeTab = 'sickdays'"><FaceFrownIcon class="w-4 h-4" /> ថ្ងៃឈឺ</div>
      </div>

      <div v-if="activeTab === 'health'" class="card">
        <div class="card-header"><span class="card-title">ប្រវត្តិសុខភាព</span><button class="btn btn-primary btn-sm" @click="saveHealth" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក…' : '' }} <ArrowDownTrayIcon class="w-4 h-4" style="display:inline;vertical-align:middle;" /> រក្សាទុក</button></div>
        <div class="card-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group">
            <label class="form-label">គ្រុបឈាម</label>
            <select class="form-select" v-model="healthForm.blood_type">
              <option value="">— ជ្រើសរើស —</option>
              <option v-for="t in ['A+','A-','B+','B-','AB+','AB-','O+','O-']" :key="t">{{ t }}</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">ចាក់វ៉ាក់សាំងរួចរាល់</label>
            <select class="form-select" v-model="healthForm.vaccination_complete">
              <option :value="true">បាទ/ចាស៎</option>
              <option :value="false">ទេ</option>
            </select>
          </div>
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">អាឡែស៊ី</label>
            <textarea class="form-textarea" v-model="healthForm.allergies" rows="2" placeholder="ឧ. សណ្ដែកដី, ថ្នាំផ្សះ..."></textarea>
          </div>
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">ស្ថានភាពជំងឺប្រចាំកាយ</label>
            <textarea class="form-textarea" v-model="healthForm.medical_conditions" rows="2" placeholder="ជំងឺប្រចាំកាយ..."></textarea>
          </div>
          <div class="form-group">
            <label class="form-label">ឈ្មោះទំនាក់ទំនងពេលមានអាសន្ន</label>
            <input class="form-input" v-model="healthForm.emergency_contact_name" />
          </div>
          <div class="form-group">
            <label class="form-label">លេខទូរស័ព្ទទំនាក់ទំនងពេលមានអាសន្ន</label>
            <input class="form-input" v-model="healthForm.emergency_contact_phone" />
          </div>
        </div>
      </div>

      <div v-if="activeTab === 'checkups'">
        <div style="display:flex;justify-content:flex-end;margin-bottom:12px;">
          <button class="btn btn-primary btn-sm" @click="openCheckup()">+ បន្ថែមការពិនិត្យ</button>
        </div>
        <div class="card">
          <div v-if="checkups.length === 0" class="empty-state"><PlusCircleIcon class="w-12 h-12 text-gray-400" /><p class="empty-state-title">មិនទាន់មានការពិនិត្យ</p></div>
          <div v-else class="table-wrapper">
            <table>
              <thead><tr><th>កាលបរិច្ឆេទ</th><th>ប្រភេទ</th><th>លទ្ធផល</th><th>ភ្នែក</th><th>ត្រចៀក</th><th>ធ្មេញ</th><th>កំណត់សម្គាល់</th><th></th></tr></thead>
              <tbody>
                <tr v-for="c in checkups" :key="c.id">
                  <td>{{ formatDate(c.date) }}</td>
                  <td>{{ c.type || '—' }}</td>
                  <td>{{ c.result || '—' }}</td>
                  <td>{{ c.vision || '—' }}</td>
                  <td>{{ c.hearing || '—' }}</td>
                  <td>{{ c.dental || '—' }}</td>
                  <td>{{ c.notes || '—' }}</td>
                  <td><button class="btn btn-ghost btn-sm btn-icon" @click="openCheckup(c)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="activeTab === 'growth'">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
          <h3 class="card-title">ការតាមដានកំណើន</h3>
          <button class="btn btn-primary btn-sm" @click="openGrowth()">+ បន្ថែមទិន្នន័យ</button>
        </div>

        <div v-if="latestGrowth" class="grid-cols-3" style="margin-bottom:20px; gap:16px;">
          <div class="stat-card">
            <div class="stat-icon" style="background:#eff6ff;color:#3b82f6;"><ArrowsUpDownIcon class="w-6 h-6" /></div>
            <div class="stat-info">
              <div class="stat-label">កម្ពស់ចុងក្រោយ</div>
              <div class="stat-value">{{ latestGrowth.height }} <span style="font-size:14px;font-weight:500;">cm</span></div>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon" style="background:#ecfdf5;color:#10b981;"><ArrowsRightLeftIcon class="w-6 h-6" /></div>
            <div class="stat-info">
              <div class="stat-label">ទម្ងន់ចុងក្រោយ</div>
              <div class="stat-value">{{ latestGrowth.weight }} <span style="font-size:14px;font-weight:500;">kg</span></div>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon" style="background:#fff7ed;color:#f97316;"><CalendarIcon class="w-6 h-6" /></div>
            <div class="stat-info">
              <div class="stat-label">ថ្ងៃពិនិត្យចុងក្រោយ</div>
              <div class="stat-value" style="font-size:18px;margin-top:8px;">{{ formatDate(latestGrowth.date) }}</div>
            </div>
          </div>
        </div>

        <div class="card">
          <div v-if="growth.length === 0" class="empty-state"><ArrowsUpDownIcon class="w-12 h-12 text-gray-400" /><p class="empty-state-title">មិនមានកំណត់ត្រាកំណើន</p></div>
          <div v-else class="table-wrapper">
            <table>
              <thead><tr><th>កាលបរិច្ឆេទ</th><th>អាយុ</th><th>កម្ពស់ (cm)</th><th>ទម្ងន់ (kg)</th><th>សកម្មភាព</th></tr></thead>
              <tbody>
                <tr v-for="g in growthHistory" :key="g.id">
                  <td>{{ formatDate(g.date) }}</td>
                  <td>{{ g.age || '—' }}</td>
                  <td>
                    <div style="font-weight:600;display:flex;align-items:center;gap:8px;">
                      {{ g.height }}
                      <span v-if="g.heightDelta" :style="{ color: g.heightDelta > 0 ? '#10b981' : '#ef4444', fontSize: '11px' }">
                        ({{ g.heightDelta > 0 ? '+' : '' }}{{ g.heightDelta }})
                      </span>
                    </div>
                  </td>
                  <td>
                    <div style="font-weight:600;display:flex;align-items:center;gap:8px;">
                      {{ g.weight }}
                      <span v-if="g.weightDelta" :style="{ color: g.weightDelta > 0 ? '#10b981' : '#ef4444', fontSize: '11px' }">
                        ({{ g.weightDelta > 0 ? '+' : '' }}{{ g.weightDelta }})
                      </span>
                    </div>
                  </td>
                  <td><button class="btn btn-ghost btn-sm btn-icon" @click="openGrowth(g)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="activeTab === 'vaccinations'">
        <div style="display:flex;justify-content:flex-end;margin-bottom:12px;">
          <button class="btn btn-primary btn-sm" @click="openVaccine()">+ បន្ថែមវ៉ាក់សាំង</button>
        </div>
        <div class="card">
          <div v-if="vaccinations.length === 0" class="empty-state"><BeakerIcon class="w-12 h-12 text-gray-400" /><p class="empty-state-title">មិនមានកំណត់ត្រាវ៉ាក់សាំងទេ</p></div>
          <div v-else class="table-wrapper">
            <table>
              <thead><tr><th>វ៉ាក់សាំង</th><th>ការពិពណ៌នា</th><th>កាលបរិច្ឆេទ</th><th>ស្ថានភាព</th><th></th></tr></thead>
              <tbody>
                <tr v-for="v in vaccinations" :key="v.id">
                  <td style="font-weight:600;">{{ v.name }}</td>
                  <td>{{ v.description || '—' }}</td>
                  <td>{{ formatDate(v.date) }}</td>
                  <td><span class="badge" :class="v.completed ? 'badge-green' : 'badge-yellow'"><component :is="v.completed ? CheckIcon : ClockIcon" class="w-3 h-3" /> {{ v.completed ? 'រួចរាល់' : 'រង់ចាំ' }}</span></td>
                  <td><button class="btn btn-ghost btn-sm btn-icon" @click="openVaccine(v)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="activeTab === 'sickdays'">
        <div style="display:flex;justify-content:flex-end;margin-bottom:12px;">
          <button class="btn btn-primary btn-sm" @click="openSickDay()">+ បន្ថែមថ្ងៃឈឺ</button>
        </div>
        <div class="card">
          <div v-if="sickDays.length === 0" class="empty-state"><FaceFrownIcon class="w-12 h-12 text-gray-400" /><p class="empty-state-title">មិនមានកំណត់ត្រាថ្ងៃឈឺទេ</p></div>
          <div v-else class="table-wrapper">
            <table>
              <thead><tr><th>កាលបរិច្ឆេទ</th><th>មូលហេតុ</th><th>រយៈពេល (ថ្ងៃ)</th><th>កំណត់សម្គាល់</th><th></th></tr></thead>
              <tbody>
                <tr v-for="s in sickDays" :key="s.id">
                  <td>{{ formatDate(s.date) }}</td>
                  <td>{{ s.reason || '—' }}</td>
                  <td><span class="badge badge-red">{{ s.duration || 1 }} ថ្ងៃ</span></td>
                  <td>{{ s.notes || '—' }}</td>
                  <td>
                    <div class="table-actions">
                      <button class="btn btn-ghost btn-sm btn-icon" @click="openSickDay(s)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>
                      <button class="btn btn-danger btn-sm btn-icon" @click="deleteSickDay(s.id)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg></button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </template>

    <div v-if="showCheckupModal" class="modal-overlay" @click.self="showCheckupModal=false">
      <div class="modal modal-lg">
        <div class="modal-header"><span class="modal-title">{{ checkupForm.id ? 'កែប្រែ' : 'បន្ថែម' }} ការពិនិត្យ</span><button class="btn btn-ghost btn-sm btn-icon" @click="showCheckupModal=false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group"><label class="form-label">កាលបរិច្ឆេទ</label><input class="form-input" type="date" v-model="checkupForm.date"/></div>
          <div class="form-group"><label class="form-label">ប្រភេទ</label><input class="form-input" v-model="checkupForm.type" placeholder="ឧ. ប្រចាំឆ្នាំ, ធ្មេញ"/></div>
          <div class="form-group"><label class="form-label">លទ្ធផល</label><input class="form-input" v-model="checkupForm.result"/></div>
          <div class="form-group"><label class="form-label">ភ្នែក</label><input class="form-input" v-model="checkupForm.vision" placeholder="ឧ. 20/20"/></div>
          <div class="form-group"><label class="form-label">ត្រចៀក</label><input class="form-input" v-model="checkupForm.hearing"/></div>
          <div class="form-group"><label class="form-label">ធ្មេញ</label><input class="form-input" v-model="checkupForm.dental"/></div>
          <div class="form-group" style="grid-column:1/-1;"><label class="form-label">កំណត់សម្គាល់</label><textarea class="form-textarea" v-model="checkupForm.notes" rows="2"></textarea></div>
        </div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="showCheckupModal=false">បោះបង់</button><button class="btn btn-primary" @click="saveCheckup" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក…' : 'រក្សាទុក' }}</button></div>
      </div>
    </div>

    <div v-if="showGrowthModal" class="modal-overlay" @click.self="showGrowthModal=false">
      <div class="modal" style="max-width:420px;">
        <div class="modal-header"><span class="modal-title">{{ growthForm.id ? 'កែប្រែ' : 'បន្ថែម' }} កំណត់ត្រាកំណើន</span><button class="btn btn-ghost btn-sm btn-icon" @click="showGrowthModal=false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group" style="grid-column:1/-1;"><label class="form-label">កាលបរិច្ឆេទ</label><input class="form-input" type="date" v-model="growthForm.date"/></div>
          <div class="form-group"><label class="form-label">អាយុ</label><input class="form-input" type="number" v-model="growthForm.age"/></div>
          <div class="form-group"><label class="form-label">កម្ពស់ (cm)</label><input class="form-input" type="number" step="0.1" v-model="growthForm.height"/></div>
          <div class="form-group"><label class="form-label">ទម្ងន់ (kg)</label><input class="form-input" type="number" step="0.1" v-model="growthForm.weight"/></div>
        </div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="showGrowthModal=false">បោះបង់</button><button class="btn btn-primary" @click="saveGrowth" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក…' : 'រក្សាទុក' }}</button></div>
      </div>
    </div>

    <div v-if="showVaccineModal" class="modal-overlay" @click.self="showVaccineModal=false">
      <div class="modal" style="max-width:420px;">
        <div class="modal-header"><span class="modal-title">{{ vaccineForm.id ? 'កែប្រែ' : 'បន្ថែម' }} វ៉ាក់សាំង</span><button class="btn btn-ghost btn-sm btn-icon" @click="showVaccineModal=false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group"><label class="form-label">ឈ្មោះវ៉ាក់សាំង *</label><input class="form-input" v-model="vaccineForm.name" placeholder="ឧ. ជំងឺរលាកថ្លើមប្រភេទ B"/></div>
          <div class="form-group"><label class="form-label">ការពិពណ៌នា</label><input class="form-input" v-model="vaccineForm.description"/></div>
          <div class="form-group"><label class="form-label">កាលបរិច្ឆេទ</label><input class="form-input" type="date" v-model="vaccineForm.date"/></div>
          <label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-size:13px;"><input type="checkbox" v-model="vaccineForm.completed" style="width:15px;height:15px;"/> រួចរាល់</label>
        </div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="showVaccineModal=false">បោះបង់</button><button class="btn btn-primary" @click="saveVaccine" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក…' : 'រក្សាទុក' }}</button></div>
      </div>
    </div>

    <div v-if="showSickDayModal" class="modal-overlay" @click.self="showSickDayModal=false">
      <div class="modal" style="max-width:420px;">
        <div class="modal-header"><span class="modal-title">{{ sickDayForm.id ? 'កែប្រែ' : 'បន្ថែម' }} ថ្ងៃឈឺ</span><button class="btn btn-ghost btn-sm btn-icon" @click="showSickDayModal=false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group"><label class="form-label">កាលបរិច្ឆេទ</label><input class="form-input" type="date" v-model="sickDayForm.date"/></div>
          <div class="form-group"><label class="form-label">មូលហេតុ *</label><input class="form-input" v-model="sickDayForm.reason" placeholder="ឧ. ផ្ដាសាយ, ឈឺពោះ"/></div>
          <div class="form-group"><label class="form-label">រយៈពេល (ថ្ងៃ)</label><input class="form-input" type="number" v-model="sickDayForm.duration"/></div>
          <div class="form-group"><label class="form-label">កំណត់សម្គាល់</label><textarea class="form-textarea" v-model="sickDayForm.notes" rows="2"></textarea></div>
        </div>
        <div class="modal-footer"><button class="btn btn-ghost" @click="showSickDayModal=false">បោះបង់</button><button class="btn btn-primary" @click="saveSickDay" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក…' : 'រក្សាទុក' }}</button></div>
      </div>
    </div>
  </div>
</template>
