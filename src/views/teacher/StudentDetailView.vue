<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { CheckIcon, XCircleIcon, HeartIcon, CalendarIcon, StarIcon, ArrowsUpDownIcon, BeakerIcon, FaceFrownIcon, PencilIcon, XMarkIcon } from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { showToast } = useToast()
const studentId = route.params.id
const student = ref(null)
const loading = ref(true)
const activeTab = ref('health')

const attendance = ref([])
const scores = ref([])
const health = ref({ growth: [], vaccinations: [], sickDays: [] })

// Modal state
const showModal = ref(false)
const modalType = ref('') // 'growth', 'vaccine', 'sick'
const isEdit = ref(false)
const saving = ref(false)

const growthForm = ref({ date: new Date().toISOString().split('T')[0], age: '', height: '', weight: '' })
const vaccineForm = ref({ date: new Date().toISOString().split('T')[0], name: '', description: '', completed: true })
const sickForm = ref({ date: new Date().toISOString().split('T')[0], reason: '', duration: 1, notes: '' })
const editId = ref(null)

onMounted(async () => { await loadData() })

async function loadData() {
  loading.value = true
  const { data: stu } = await supabase.from('students').select('*, classes(class_name)').eq('id', studentId).single()
  if (!stu) { router.push('/teacher/students'); return }
  student.value = stu

  await Promise.all([loadAttendance(), loadScores(), loadHealth()])
  loading.value = false
}

async function loadAttendance() {
  const { data } = await supabase.from('attendances').select('*').eq('student_id', studentId).order('date', { ascending: false })
  attendance.value = data || []
}

async function loadScores() {
  const { data } = await supabase.from('scores').select('*, subjects(subject_name)').eq('student_id', studentId).order('month', { ascending: false })
  scores.value = data || []
}

async function loadHealth() {
  const [gr, vac, sick] = await Promise.all([
    supabase.from('student_growth').select('*').eq('student_id', studentId).order('date', { ascending: false }),
    supabase.from('student_vaccinations').select('*').eq('student_id', studentId).order('date', { ascending: false }),
    supabase.from('student_sick_days').select('*').eq('student_id', studentId).order('date', { ascending: false })
  ])
  health.value = { growth: gr.data || [], vaccinations: vac.data || [], sickDays: sick.data || [] }
}

// ── CRUD LOGIC ──────────────────────────────────────────────

function openAdd(type) {
  modalType.value = type
  isEdit.value = false
  editId.value = null
  if (type === 'growth') growthForm.value = { date: new Date().toISOString().split('T')[0], age: '', height: '', weight: '' }
  if (type === 'vaccine') vaccineForm.value = { date: new Date().toISOString().split('T')[0], name: '', description: '', completed: true }
  if (type === 'sick') sickForm.value = { date: new Date().toISOString().split('T')[0], reason: '', duration: 1, notes: '' }
  showModal.value = true
}

function openEdit(type, item) {
  modalType.value = type
  isEdit.value = true
  editId.value = item.id
  if (type === 'growth') growthForm.value = { ...item, date: toInputDate(item.date) }
  if (type === 'vaccine') vaccineForm.value = { ...item, date: toInputDate(item.date) }
  if (type === 'sick') sickForm.value = { ...item, date: toInputDate(item.date) }
  showModal.value = true
}

async function handleSave() {
  saving.value = true
  let table = ''
  let payload = {}
  
  if (modalType.value === 'growth') { table = 'student_growth'; payload = { ...growthForm.value } }
  else if (modalType.value === 'vaccine') { table = 'student_vaccinations'; payload = { ...vaccineForm.value } }
  else if (modalType.value === 'sick') { table = 'student_sick_days'; payload = { ...sickForm.value } }
  
  payload.student_id = studentId
  delete payload.id

  const { error } = isEdit.value 
    ? await supabase.from(table).update(payload).eq('id', editId.value)
    : await supabase.from(table).insert({ ...payload, school_id: auth.schoolId })

  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  
  showToast('រក្សាទុកទិន្នន័យបានជោគជ័យ!', 'success')
  showModal.value = false
  await loadHealth()
}

async function handleDelete(type, id) {
  if (!confirm('តើអ្នកពិតជាចង់លុបទិន្នន័យនេះមែនទេ?')) return
  let table = ''
  if (type === 'growth') table = 'student_growth'
  else if (type === 'vaccine') table = 'student_vaccinations'
  else if (type === 'sick') table = 'student_sick_days'
  
  const { error } = await supabase.from(table).delete().eq('id', id)
  if (error) { showToast(error.message, 'error'); return }
  showToast('លុបទិន្នន័យបានជោគជ័យ', 'success')
  await loadHealth()
}

function initials(name) { 
  return (name || '').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() 
}
</script>

<template>
  <div class="student-detail-page">
    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:200px; margin-bottom:20px;"></div>
      <div class="skeleton" style="height:400px;"></div>
    </div>

    <div v-else-if="student">
      <!-- Profile Header -->
      <div class="card profile-header-card" style="margin-bottom:24px;">
        <div class="profile-header-content">
          <div class="avatar-large">{{ initials(student.full_name) }}</div>
          <div class="profile-info">
            <h1 class="student-name">{{ student.full_name }}</h1>
            <div class="profile-badges">
              <span class="badge badge-blue">លេខកូដ៖ {{ student.real_id || '—' }}</span>
              <span class="badge badge-indigo">{{ student.classes?.class_name }}</span>
              <span class="badge badge-gray">{{ student.gender === 'Male' ? 'ប្រុស' : 'ស្រី' }}</span>
            </div>
          </div>
          <button class="btn btn-ghost" @click="router.back()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="15 18 9 12 15 6"/></svg>
            ត្រឡប់ក្រោយ
          </button>
        </div>
      </div>

      <!-- Tabs Navigation -->
      <div class="tabs">
        <div class="tab-item" :class="{ active: activeTab === 'health' }" @click="activeTab = 'health'">
          <HeartIcon class="w-4 h-4" /> សុខភាព & កំណើន
        </div>
        <div class="tab-item" :class="{ active: activeTab === 'attendance' }" @click="activeTab = 'attendance'">
          <CalendarIcon class="w-4 h-4" /> វត្តមាន
        </div>
        <div class="tab-item" :class="{ active: activeTab === 'scores' }" @click="activeTab = 'scores'">
          <StarIcon class="w-4 h-4" /> ពិន្ទុ
        </div>
      </div>

      <!-- Tab Content -->
      <div class="card tab-content-card">
        <!-- Health Tab -->
        <div v-if="activeTab === 'health'" class="card-body">
          <div class="health-grid">
            <!-- Growth Section -->
            <section class="health-section">
              <div class="section-header">
                <h3 class="section-title"><ArrowsUpDownIcon class="w-4 h-4" /> កំណត់ត្រាកំណើន</h3>
                <button class="btn btn-primary btn-xs" @click="openAdd('growth')">+ បញ្ចូលថ្មី</button>
              </div>
              <div class="table-wrapper mini-table">
                <table>
                  <thead><tr><th>កាលបរិច្ឆេទ</th><th>កម្ពស់ (សម)</th><th>ទម្ងន់ (គក)</th><th>សកម្មភាព</th></tr></thead>
                  <tbody>
                    <tr v-for="g in health.growth" :key="g.id">
                      <td>{{ formatDate(g.date) }}</td>
                      <td style="font-weight:700;">{{ g.height }}</td>
                      <td style="font-weight:700;">{{ g.weight }}</td>
                      <td>
                        <div class="table-actions">
                          <button class="btn btn-ghost btn-xs btn-icon" @click="openEdit('growth', g)"><PencilIcon class="w-3 h-3" /></button>
                          <button class="btn btn-ghost btn-xs btn-icon text-danger" @click="handleDelete('growth', g.id)"><XMarkIcon class="w-3 h-3" /></button>
                        </div>
                      </td>
                    </tr>
                    <tr v-if="health.growth.length === 0"><td colspan="4" class="text-center py-4 text-muted">មិនទាន់មានកំណត់ត្រា</td></tr>
                  </tbody>
                </table>
              </div>
            </section>

            <!-- Vaccinations Section -->
            <section class="health-section">
              <div class="section-header">
                <h3 class="section-title"><BeakerIcon class="w-4 h-4" /> ការចាក់វ៉ាក់សាំង</h3>
                <button class="btn btn-primary btn-xs" @click="openAdd('vaccine')">+ បញ្ចូលថ្មី</button>
              </div>
              <div class="table-wrapper mini-table">
                <table>
                  <thead><tr><th>ឈ្មោះវ៉ាក់សាំង</th><th>កាលបរិច្ឆេទ</th><th>ស្ថានភាព</th><th>សកម្មភាព</th></tr></thead>
                  <tbody>
                    <tr v-for="v in health.vaccinations" :key="v.id">
                      <td style="font-weight:600;">{{ v.name }}</td>
                      <td>{{ formatDate(v.date) }}</td>
                      <td><span class="badge badge-xs" :class="v.completed ? 'badge-green' : 'badge-yellow'">{{ v.completed ? 'បានចាក់' : 'មិនទាន់' }}</span></td>
                      <td>
                        <div class="table-actions">
                          <button class="btn btn-ghost btn-xs btn-icon" @click="openEdit('vaccine', v)"><PencilIcon class="w-3 h-3" /></button>
                          <button class="btn btn-ghost btn-xs btn-icon text-danger" @click="handleDelete('vaccine', v.id)"><XMarkIcon class="w-3 h-3" /></button>
                        </div>
                      </td>
                    </tr>
                    <tr v-if="health.vaccinations.length === 0"><td colspan="4" class="text-center py-4 text-muted">មិនទាន់មានកំណត់ត្រា</td></tr>
                  </tbody>
                </table>
              </div>
            </section>

            <!-- Sick Days Section -->
            <section class="health-section" style="grid-column: span 2;">
              <div class="section-header">
                <h3 class="section-title"><FaceFrownIcon class="w-4 h-4" /> ប្រវត្តិជំងឺ</h3>
                <button class="btn btn-primary btn-xs" @click="openAdd('sick')">+ បញ្ចូលថ្មី</button>
              </div>
              <div class="table-wrapper">
                <table>
                  <thead><tr><th>កាលបរិច្ឆេទ</th><th>រយៈពេល</th><th>មូលហេតុ</th><th>កំណត់ចំណាំ</th><th>សកម្មភាព</th></tr></thead>
                  <tbody>
                    <tr v-for="s in health.sickDays" :key="s.id">
                      <td>{{ formatDate(s.date) }}</td>
                      <td><span class="badge badge-red badge-xs">{{ s.duration }} ថ្ងៃ</span></td>
                      <td style="font-weight:600;">{{ s.reason }}</td>
                      <td style="font-size:12px;">{{ s.notes || '—' }}</td>
                      <td>
                        <div class="table-actions">
                          <button class="btn btn-ghost btn-xs btn-icon" @click="openEdit('sick', s)"><PencilIcon class="w-3 h-3" /></button>
                          <button class="btn btn-ghost btn-xs btn-icon text-danger" @click="handleDelete('sick', s.id)"><XMarkIcon class="w-3 h-3" /></button>
                        </div>
                      </td>
                    </tr>
                    <tr v-if="health.sickDays.length === 0"><td colspan="5" class="text-center py-4 text-muted">មិនទាន់មានកំណត់ត្រាជំងឺ</td></tr>
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        </div>

        <!-- Attendance Tab -->
        <div v-if="activeTab === 'attendance'" class="table-wrapper">
          <table>
            <thead><tr><th>កាលបរិច្ឆេទ</th><th>ស្ថានភាព</th><th>មូលហេតុ</th></tr></thead>
            <tbody>
              <tr v-for="a in attendance" :key="a.id">
                <td>{{ formatDate(a.date) }}</td>
                <td><span class="badge" :class="a.status === 'present' ? 'badge-green' : 'badge-red'">{{ a.status === 'present' ? 'មានវត្តមាន' : 'អវត្តមាន' }}</span></td>
                <td>{{ a.reason || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Scores Tab -->
        <div v-if="activeTab === 'scores'">
          <div class="scores-tab-header">
            <h3>បញ្ជីពិន្ទុ</h3>
            <div style="display:flex; gap:8px;">
              <button class="btn btn-secondary btn-sm" @click="router.push(`/teacher/scores/summary/${studentId}?mode=monthly`)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
                ប្រចាំខែ
              </button>
              <button class="btn btn-secondary btn-sm" @click="router.push(`/teacher/scores/summary/${studentId}?mode=semester`)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                  <path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c0 1.1 2.2 2 6 2s6-.9 6-2v-5"/>
                </svg>
                ឆមាស
              </button>
            </div>
          </div>
        </div>
      </div>

    <!-- Modals -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal" style="max-width:400px;">
        <div class="modal-header">
          <span class="modal-title">
            {{ isEdit ? 'កែប្រែ' : 'បញ្ចូលថ្មី' }} 
            {{ modalType === 'growth' ? 'កំណត់ត្រាកំណើន' : modalType === 'vaccine' ? 'ការចាក់វ៉ាក់សាំង' : 'ថ្ងៃជំងឺ' }}
          </span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false"><XMarkIcon class="w-4 h-4" /></button>
        </div>
        <div class="modal-body" style="display:flex; flex-direction:column; gap:16px;">
          <!-- Date -->
          <div class="form-group">
            <label class="form-label">កាលបរិច្ឆេទ</label>
            <input v-if="modalType === 'growth'" type="date" class="form-input" v-model="growthForm.date" />
            <input v-if="modalType === 'vaccine'" type="date" class="form-input" v-model="vaccineForm.date" />
            <input v-if="modalType === 'sick'" type="date" class="form-input" v-model="sickForm.date" />
          </div>

          <!-- Growth -->
          <template v-if="modalType === 'growth'">
            <div class="form-group"><label class="form-label">កម្ពស់ (សម)</label><input type="number" step="0.1" class="form-input" v-model="growthForm.height" /></div>
            <div class="form-group"><label class="form-label">ទម្ងន់ (គក)</label><input type="number" step="0.1" class="form-input" v-model="growthForm.weight" /></div>
            <div class="form-group"><label class="form-label">អាយុ (ឆ្នាំ)</label><input type="number" step="0.1" class="form-input" v-model="growthForm.age" /></div>
          </template>

          <!-- Vaccine -->
          <template v-if="modalType === 'vaccine'">
            <div class="form-group"><label class="form-label">ឈ្មោះវ៉ាក់សាំង</label><input class="form-input" v-model="vaccineForm.name" /></div>
            <div class="form-group"><label class="form-label">ការពិពណ៌នា</label><input class="form-input" v-model="vaccineForm.description" /></div>
            <div class="form-group">
              <label class="form-label">ស្ថានភាព</label>
              <div style="display:flex; gap:12px;">
                <label style="cursor:pointer;"><input type="radio" :value="true" v-model="vaccineForm.completed" /> បានចាក់</label>
                <label style="cursor:pointer;"><input type="radio" :value="false" v-model="vaccineForm.completed" /> មិនទាន់</label>
              </div>
            </div>
          </template>

          <!-- Sick -->
          <template v-if="modalType === 'sick'">
            <div class="form-group"><label class="form-label">មូលហេតុ</label><input class="form-input" v-model="sickForm.reason" /></div>
            <div class="form-group"><label class="form-label">រយៈពេល (ថ្ងៃ)</label><input type="number" class="form-input" v-model="sickForm.duration" /></div>
            <div class="form-group"><label class="form-label">កំណត់ចំណាំ</label><textarea class="form-textarea" v-model="sickForm.notes" rows="2"></textarea></div>
          </template>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="handleSave" :disabled="saving">
            {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<style scoped>
.student-detail-page { max-width: 1000px; margin: 0 auto; }
.profile-header-card { padding: 32px; border: none; background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%); }
.profile-header-content { display: flex; align-items: center; gap: 32px; }
.avatar-large { width: 90px; height: 90px; border-radius: 24px; background: var(--primary-color); color: white; display: flex; align-items: center; justify-content: center; font-size: 32px; font-weight: 800; box-shadow: 0 8px 16px rgba(var(--primary-rgb), 0.2); }
.profile-info { flex: 1; }
.student-name { font-size: 28px; font-weight: 800; color: #1e293b; margin-bottom: 8px; }
.profile-badges { display: flex; gap: 8px; }

.health-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.health-section { background: #fdfdfd; border: 1px solid #f1f5f9; border-radius: 12px; padding: 16px; }
.section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
.section-title { font-size: 14px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; }

.mini-table table th { padding: 8px 12px; font-size: 11px; }
.mini-table table td { padding: 8px 12px; font-size: 13px; }

.text-danger { color: #ef4444 !important; }
.btn-xs { padding: 4px 8px; font-size: 11px; }
.badge-xs { padding: 2px 6px; font-size: 10px; }

.scores-tab-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid #f1f5f9;
}
.scores-tab-header h3 {
  font-size: 15px;
  font-weight: 700;
  color: #374151;
  margin: 0;
}
</style>
