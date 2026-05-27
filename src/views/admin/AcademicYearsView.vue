<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { toInputDate, formatDate } from '@/utils/formatDate'
import { 
  CheckIcon, 
  XCircleIcon, 
  BuildingOfficeIcon, 
  CalendarIcon, 
  TrashIcon, 
  ArrowPathRoundedSquareIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon
} from '@heroicons/vue/24/outline'

const router = useRouter()
const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const years = ref([])
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const toast = ref(null)

// Student Rollup State
const showRollupModal = ref(false)
const rollupSource = ref(null)
const targetYearId = ref('')
const rollupSummary = ref(null)
const rollingUp = ref(false)
const cloningClasses = ref(false)
const targetClassesCount = ref(0)
const rollupStudentCount = ref(0)
const rollupProgress = ref(0)

const schoolInfo = ref({ name_khmer: 'សាលាបឋមសិក្សា ចំការមន', logo_url: null })

const emptyForm = () => ({ id: null, year_name: '', start_date: '', end_date: '', status: 'active' })
const form = ref(emptyForm())

async function loadSchoolInfo() {
  const { data } = await supabase.from('school_information').select('*').limit(1).single()
  if (data) schoolInfo.value = data
}

async function enterYear(y) {
  yearStore.setYear(y.id, y.year_name)
  router.push('/admin/dashboard')
}

async function handleLogout() {
  await auth.logout()
  yearStore.clearYear()
  router.push('/login')
}

onMounted(async () => {
  await Promise.all([load(), loadSchoolInfo()])
})

async function load() {
  loading.value = true
  const { data } = await supabase.from('academic_years').select('*').order('start_date', { ascending: false })
  years.value = data || []
  loading.value = false
}

function openAdd() { isEdit.value = false; form.value = emptyForm(); showModal.value = true }
function openEdit(y) { isEdit.value = true; form.value = { ...y, start_date: toInputDate(y.start_date), end_date: toInputDate(y.end_date) }; showModal.value = true }

async function save() {
  if (!form.value.year_name.trim() || !form.value.start_date || !form.value.end_date) {
    showToast('Name, start date, and end date are required', 'error'); return
  }
  saving.value = true
  const { id, ...payload } = form.value
  const { data, error } = isEdit.value
    ? await supabase.from('academic_years').update(payload).eq('id', id).select()
    : await supabase.from('academic_years').insert({ ...payload, school_id: auth.schoolId }).select()
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  
  const createdYear = data?.[0]
  showToast(isEdit.value ? 'Year updated!' : 'Year added!', 'success')
  showModal.value = false
  
  // If we just added a new year, and there are previous years, ask for rollup
  if (!isEdit.value && years.value.length > 0) {
    const prevYear = years.value[0] // Latest one
    rollupSource.value = prevYear
    targetYearId.value = createdYear.id
    rollupSummary.value = null
    showRollupModal.value = true
  }
  
  load()
}

async function doDelete() {
  const targetId = deleteTarget.value.id
  
  // If we are deleting the year currently in use, clear it from the store
  if (targetId === yearStore.selectedYearId) {
    yearStore.clearYear()
  }

  const { error } = await supabase.from('academic_years').delete().eq('id', targetId)
  deleteTarget.value = null
  
  if (error) { 
    showToast(error.message, 'error')
    return 
  }
  
  showToast('បានលុបឆ្នាំសិក្សា!', 'success')
  load()
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

// Student Rollup Actions
async function openRollup(y) {
  rollupSource.value = y
  // If targetYearId was already set by "Add Year", keep it, else clear it
  if (!targetYearId.value) targetYearId.value = ''
  rollupSummary.value = null
  showRollupModal.value = true
  
  if (targetYearId.value) {
    checkTargetClasses()
  }
}

async function checkTargetClasses() {
  if (!targetYearId.value || !rollupSource.value) return
  const [clsRes, stuRes] = await Promise.all([
    supabase.from('classes').select('*', { count: 'exact', head: true }).eq('academic_year_id', targetYearId.value),
    supabase.from('students').select('*', { count: 'exact', head: true }).eq('academic_year_id', rollupSource.value.id).eq('is_graduated', false)
  ])
  targetClassesCount.value = clsRes.count || 0
  rollupStudentCount.value = stuRes.count || 0
}

async function handleCloneClasses() {
  cloningClasses.value = true
  try {
    const { data, error } = await supabase.rpc('clone_classes_structure', {
      p_old_year_id: rollupSource.value.id,
      p_new_year_id: targetYearId.value
    })
    if (error) throw error
    showToast(`បានបង្កើតថ្នាក់ថ្មីចំនួន ${data} រួចរាល់!`, 'success')
    await checkTargetClasses()
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    cloningClasses.value = false
  }
}

async function executeRollup() {
  if (!targetYearId.value) return
  
  rollingUp.value = true
  rollupProgress.value = 0
  const total = rollupStudentCount.value

  const progressInterval = setInterval(() => {
    if (rollupProgress.value < 90) {
      rollupProgress.value += Math.floor(Math.random() * 8) + 2
      if (rollupProgress.value > 90) rollupProgress.value = 90
    }
  }, 300)

  try {
    const { data, error } = await supabase.rpc('perform_student_rollup', {
      p_old_year_id: rollupSource.value.id,
      p_new_year_id: targetYearId.value
    })

    clearInterval(progressInterval)
    rollupProgress.value = 100

    if (error) throw error
    rollupSummary.value = data
    showToast('បញ្ជូនសិស្សទៅឆ្នាំថ្មីបានសម្រេច!', 'success')
  } catch (err) {
    clearInterval(progressInterval)
    console.error('Rollup error:', err)
    showToast(err.message || 'Error during rollup', 'error')
  } finally {
    rollingUp.value = false
  }
}
</script>

<template>
  <div class="standalone-page">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`"><CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" /><XCircleIcon v-else class="w-4 h-4" /> {{ toast.msg }}</div>
    </div>

    <!-- Standalone Header -->
    <header class="standalone-header">
      <div class="header-content">
        <div class="school-brand">
          <div class="school-logo"><BuildingOfficeIcon class="w-6 h-6" /></div>
          <h1 class="school-name">{{ schoolInfo.name_khmer }}</h1>
        </div>
        <button class="btn btn-ghost logout-btn" @click="handleLogout">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
          ចាកចេញ
        </button>
      </div>
    </header>

    <main class="standalone-main">
      <div class="content-wrapper">
        <div class="selection-header">
          <h2 class="selection-title">សូមជ្រើសរើសឆ្នាំសិក្សា</h2>
          <p class="selection-subtitle">Select an academic year to manage school data</p>
          <button class="btn btn-primary add-btn" @click="openAdd">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            បន្ថែមឆ្នាំសិក្សា
          </button>
        </div>

        <div v-if="loading" class="year-grid">
          <div v-for="i in 3" :key="i" class="skeleton year-card-skeleton"></div>
        </div>

        <div v-else-if="years.length === 0" class="empty-state">
          <CalendarIcon class="w-12 h-12 text-gray-400" />
          <p class="empty-state-title">មិនទាន់មានឆ្នាំសិក្សានៅឡើយទេ</p>
          <button class="btn btn-primary" @click="openAdd">បង្កើតឆ្នាំសិក្សាដំបូង</button>
        </div>

        <div v-else class="year-grid">
          <div v-for="y in years" :key="y.id" class="year-card" :class="{ 'active': y.id === yearStore.selectedYearId }">
            <div class="year-card-header">
              <span class="year-name">{{ y.year_name }}</span>
              <span class="badge" :class="y.status === 'active' ? 'badge-green' : 'badge-gray'">{{ y.status === 'active' ? 'កំពុងដំណើរការ' : 'បានបញ្ចប់' }}</span>
            </div>
            <div class="year-card-body">
              <div class="date-info">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
                <span>{{ formatDate(y.start_date) }} - {{ formatDate(y.end_date) }}</span>
              </div>
            </div>
            <div class="year-card-footer">
              <div class="card-actions">
                <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(y)" title="កែប្រែ">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                </button>
                <button class="btn btn-ghost btn-sm btn-icon btn-danger-hover" @click="deleteTarget = y" title="លុប">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
                </button>
                <button 
                  v-if="y.status === 'active'"
                  class="btn btn-ghost btn-sm btn-icon text-primary-600" 
                  @click="openRollup(y)" 
                  title="បញ្ជូនសិស្សទៅឆ្នាំថ្មី"
                >
                  <ArrowPathRoundedSquareIcon class="w-5 h-5" />
                </button>
              </div>
              <button class="btn btn-primary" @click="enterYear(y)">
                ចូលទៅកាន់ទិន្នន័យ
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="9 18 15 12 9 6"/></svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែឆ្នាំសិក្សា' : 'បន្ថែមឆ្នាំសិក្សា' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
        </div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group">
            <label class="form-label">ឈ្មោះឆ្នាំសិក្សា *</label>
            <input class="form-input" v-model="form.year_name" placeholder="e.g. ឆ្នាំសិក្សា 2024-2025" />
          </div>
          <div class="form-group">
            <label class="form-label">ថ្ងៃចាប់ផ្តើម *</label>
            <input class="form-input" type="date" v-model="form.start_date" />
          </div>
          <div class="form-group">
            <label class="form-label">ថ្ងៃបញ្ចប់ *</label>
            <input class="form-input" type="date" v-model="form.end_date" />
          </div>
          <div class="form-group">
            <label class="form-label">ស្ថានភាព</label>
            <select class="form-select" v-model="form.status">
              <option value="active">Active (កំពុងដំណើរការ)</option>
              <option value="inactive">Inactive (បានបញ្ចប់)</option>
            </select>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'កំពុងរក្សាទុក…' : isEdit ? 'រក្សាទុក' : 'បន្ថែម' }}</button>
        </div>
      </div>
    </div>

    <!-- Delete Confirm -->
    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:380px;">
        <div class="modal-body" style="text-align:center;padding:28px 24px;">
          <ExclamationTriangleIcon class="w-12 h-12 text-red-500" style="margin: 0 auto 16px;" />
          <h3 style="margin-bottom:8px;font-size:18px;font-weight:700;">តើអ្នកពិតជាចង់លុបមែនទេ?</h3>
          <p style="color:var(--text-secondary);font-size:14px;line-height:1.6;">
            ការលុបឆ្នាំសិក្សា <strong>{{ deleteTarget.year_name }}</strong> នឹងធ្វើឱ្យបាត់បង់ទិន្នន័យដូចជា៖
          </p>
          <ul style="text-align:left;font-size:13px;color:var(--text-secondary);margin:12px 0;padding-left:20px;">
            <li>ថ្នាក់រៀន និងកាលវិភាគទាំងអស់</li>
            <li>ពិន្ទុ និងមធ្យមភាគសិស្សទាំងអស់</li>
            <li>វត្តមានសិស្ស និងគ្រូប្រចាំឆ្នាំ</li>
            <li>របាយការណ៍ចំណូល-ចំណាយប្រចាំឆ្នាំ</li>
          </ul>
          <p style="color:#dc2626;font-size:12px;font-weight:600;margin-top:8px;">* កំណត់ត្រាសិស្ស និងគ្រូនឹងមិនត្រូវបានលុបឡើយ។</p>
        </div>
        <div class="modal-footer" style="background:var(--bg-secondary);border-top:none;">
          <button class="btn btn-ghost" @click="deleteTarget = null" style="background:white;border:1px solid var(--border-default);">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete" style="flex:1;">បាទ ខ្ញុំយល់ព្រមលុប</button>
        </div>
      </div>
    </div>

    <!-- Student Rollup Modal -->
    <div v-if="showRollupModal" class="modal-overlay" @click.self="!rollingUp && (showRollupModal = false)">
      <div class="modal" style="max-width: 550px;">
        <div class="modal-header">
          <span class="modal-title">បញ្ជូនសិស្សទៅឆ្នាំថ្មី (Student Rollup)</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showRollupModal = false" :disabled="rollingUp">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>

        <div v-if="rollingUp" class="modal-body" style="text-align:center;padding:48px 32px;">
          <h3 style="margin-bottom:12px;font-size:18px;font-weight:700;">កំពុងបញ្ជូនសិស្ស...</h3>
          <div style="background:#e2e8f0;border-radius:8px;height:28px;overflow:hidden;margin:0 auto 12px;max-width:400px;">
            <div style="height:100%;background:linear-gradient(90deg,#3b82f6,#8b5cf6);border-radius:8px;transition:width 0.3s;display:flex;align-items:center;justify-content:center;min-width:40px;"
                 :style="{ width: rollupProgress + '%' }">
              <span v-if="rollupProgress > 5" style="font-size:12px;font-weight:700;color:white;">{{ rollupProgress }}%</span>
            </div>
          </div>
          <p style="color:var(--text-secondary);font-size:14px;">
            កំពុងដំណើរការសិស្សចំនួន <strong>{{ rollupStudentCount }}</strong> នាក់។ សូមរង់ចាំមួយភ្លែត...
          </p>
        </div>

        <template v-else>
          <div class="modal-body">
            <div v-if="!rollupSummary">
              <div class="alert alert-info mb-4">
                <ExclamationTriangleIcon class="w-5 h-5" />
                <p>មុខងារនេះនឹងរុញសិស្សពី <strong>{{ rollupSource.year_name }}</strong> ទៅកាន់ថ្នាក់ខ្ពស់ជាងនេះក្នុងឆ្នាំសិក្សាថ្មី។</p>
              </div>

              <div class="form-group">
                <label class="form-label">ជ្រើសរើសឆ្នាំសិក្សាគោលដៅ (Target Year)</label>
                <select class="form-select" v-model="targetYearId" @change="checkTargetClasses">
                  <option value="">-- សូមជ្រើសរើស --</option>
                  <option 
                    v-for="y in years.filter(y => y.id !== rollupSource.id)" 
                    :key="y.id" 
                    :value="y.id"
                  >
                    {{ y.year_name }}
                  </option>
                </select>
              </div>

              <div v-if="targetYearId && rollupStudentCount > 0" class="alert" style="background:#eff6ff;border:1px solid #bfdbfe;color:#1e40af;margin-top:12px;">
                <ArrowPathRoundedSquareIcon class="w-5 h-5" />
                <div>
                  <p class="font-bold">សិស្សសរុបចំនួន <strong>{{ rollupStudentCount }}</strong> នាក់ នឹងត្រូវបានបញ្ជូនបន្ត</p>
                  <p style="font-size:12px;margin-top:4px;">ថ្នាក់ទី១ → ទី២, ទី២ → ទី៣, ... , ទី៦ → បញ្ចប់ការសិក្សា</p>
                </div>
              </div>

              <div v-if="targetYearId && targetClassesCount === 0" class="alert alert-warning mb-4 mt-2">
                <ExclamationTriangleIcon class="w-5 h-5" />
                <div style="flex:1;">
                  <p class="font-bold">មិនទាន់មានថ្នាក់រៀន!</p>
                  <p>ឆ្នាំសិក្សាគោលដៅមិនទាន់មានថ្នាក់រៀននៅឡើយទេ។ អ្នកត្រូវបង្កើតថ្នាក់មុននឹងបញ្ជូនសិស្ស។</p>
                  <button 
                    class="btn btn-sm btn-primary mt-2" 
                    @click="handleCloneClasses"
                    :disabled="cloningClasses"
                  >
                    {{ cloningClasses ? 'កំពុងចម្លង...' : 'ចម្លងរចនាសម្ព័ន្ធថ្នាក់ពីឆ្នាំចាស់' }}
                  </button>
                </div>
              </div>

              <p v-if="targetYearId && targetClassesCount > 0 && rollupStudentCount === 0" class="form-hint mt-2">
                សិស្សថ្នាក់ទី១ នឹងទៅថ្នាក់ទី២, ថ្នាក់ទី៥ ទៅថ្នាក់ទី៦ និងថ្នាក់ទី៦ នឹងត្រូវបញ្ចប់ការសិក្សា។
              </p>
            </div>

            <!-- Rollup Results Summary -->
            <div v-else class="rollup-results">
              <div class="result-header">
                <CheckCircleIcon class="w-12 h-12 text-green-500" />
                <h3>ការបញ្ជូនសិស្សបានសម្រេច!</h3>
              </div>
              
              <div class="stats-grid mt-4">
                <div class="stat-box">
                  <span class="stat-label">សិស្សឡើងថ្នាក់</span>
                  <span class="stat-value text-primary-600">{{ rollupSummary.total_promoted }}</span>
                </div>
                <div class="stat-box">
                  <span class="stat-label">សិស្សបញ្ចប់ការសិក្សា</span>
                  <span class="stat-value text-green-600">{{ rollupSummary.total_graduated }}</span>
                </div>
              </div>

              <div class="details-list mt-6">
                <h4 class="details-title">សេចក្តីលម្អិតតាមកម្រិតថ្នាក់៖</h4>
                <div class="table-mini-wrapper">
                  <table class="table-mini">
                    <thead>
                      <tr>
                        <th>ថ្នាក់ទី</th>
                        <th>សកម្មភាព</th>
                        <th>ចំនួនសិស្ស</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="item in rollupSummary.details" :key="item.grade">
                        <td>ថ្នាក់ទី {{ item.grade }}</td>
                        <td>
                          <span class="badge" :class="item.action === 'skipped' ? 'badge-red' : 'badge-gray'">
                            {{ 
                              item.action === 'paired' ? 'ឡើងថ្នាក់ (ស្មើគ្នា)' : 
                              item.action === 'merged' ? 'ឡើងថ្នាក់ (បញ្ចូលគ្នា)' :
                              item.action === 'merged_mismatch' ? 'ឡើងថ្នាក់ (បញ្ចូលគ្នា - ចំនួនមិនស្មើ)' :
                              item.action === 'graduated' ? 'បញ្ចប់ការសិក្សា' :
                              'មិនមានថ្នាក់គោលដៅ'
                            }}
                          </span>
                        </td>
                        <td class="text-right font-bold">
                          {{ item.students_moved || item.students_graduated || 0 }} នាក់
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button v-if="!rollupSummary" class="btn btn-ghost" @click="showRollupModal = false" :disabled="rollingUp">បោះបង់</button>
            <button 
              v-if="!rollupSummary" 
              class="btn btn-primary" 
              @click="executeRollup" 
              :disabled="!targetYearId || rollingUp || targetClassesCount === 0"
            >
              <ArrowPathRoundedSquareIcon v-if="!rollingUp" class="w-4 h-4 mr-2" />
              {{ rollingUp ? 'កំពុងបញ្ជូន...' : 'បញ្ជូនសិស្សឥឡូវនេះ' }}
            </button>
            <button v-else class="btn btn-primary" @click="showRollupModal = false">យល់ព្រម</button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.standalone-page {
  min-height: 100vh;
  background-color: var(--bg-secondary);
  display: flex;
  flex-direction: column;
}

.standalone-header {
  background-color: white;
  border-bottom: 1px solid var(--border-default);
  padding: 0 24px;
  height: 64px;
  display: flex;
  align-items: center;
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-content {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.school-brand {
  display: flex;
  align-items: center;
  gap: 12px;
}

.school-logo {
  font-size: 24px;
  background: var(--primary-50);
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
}

.school-name {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
}

.logout-btn {
  color: var(--text-secondary);
  gap: 8px;
}

.standalone-main {
  flex: 1;
  padding: 48px 24px;
}

.content-wrapper {
  max-width: 1000px;
  margin: 0 auto;
}

.selection-header {
  text-align: center;
  margin-bottom: 40px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.selection-title {
  font-size: 28px;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 8px;
}

.selection-subtitle {
  color: var(--text-secondary);
  font-size: 15px;
  margin-bottom: 24px;
}

.year-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 24px;
}

.year-card {
  background: white;
  border-radius: 16px;
  border: 1px solid var(--border-default);
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  transition: all 0.2s ease;
  box-shadow: var(--shadow-sm);
}

.year-card:hover {
  border-color: var(--primary-color);
  transform: translateY(-4px);
  box-shadow: var(--shadow-md);
}

.year-card.active {
  border-color: var(--primary-color);
  background: var(--primary-50);
}

.year-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.year-name {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary);
}

.date-info {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--text-secondary);
  font-size: 14px;
}

.year-card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 8px;
}

.card-actions {
  display: flex;
  gap: 4px;
}

.btn-danger-hover:hover {
  background: #fee2e2;
  color: #dc2626;
}

.year-card-skeleton {
  height: 200px;
}

/* Rollup Styles */
.alert {
  padding: 12px 16px;
  border-radius: 8px;
  display: flex;
  gap: 12px;
  align-items: flex-start;
  font-size: 14px;
}

.alert-info {
  background: var(--primary-50);
  border: 1px solid var(--primary-200);
  color: var(--primary-700);
}

.alert-warning {
  background: #fffbeb;
  border: 1px solid #fde68a;
  color: #92400e;
}

.font-bold { font-weight: 700; }

.form-hint {
  font-size: 12px;
  color: var(--text-secondary);
}

.rollup-results {
  text-align: center;
}

.result-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-bottom: 24px;
}

.result-header h3 {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
}

.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.stat-box {
  background: var(--bg-secondary);
  padding: 16px;
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.stat-label {
  font-size: 12px;
  color: var(--text-secondary);
}

.stat-value {
  font-size: 24px;
  font-weight: 800;
}

.details-list {
  text-align: left;
}

.details-title {
  font-size: 14px;
  font-weight: 700;
  margin-bottom: 12px;
}

.table-mini-wrapper {
  background: white;
  border: 1px solid var(--border-default);
  border-radius: 8px;
  overflow: hidden;
}

.table-mini {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.table-mini th {
  background: var(--bg-secondary);
  padding: 8px 12px;
  text-align: left;
  font-weight: 600;
  border-bottom: 1px solid var(--border-default);
}

.table-mini td {
  padding: 8px 12px;
  border-bottom: 1px solid var(--border-default);
}

.table-mini tr:last-child td {
  border-bottom: none;
}

.text-right { text-align: right; }

@media (max-width: 640px) {
  .selection-title { font-size: 24px; }
  .year-grid { grid-template-columns: 1fr; }
  .header-content .school-name { display: none; }
  .stats-grid { grid-template-columns: 1fr; }
}
</style>
