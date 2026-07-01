<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { formatDate, toInputDate } from '@/utils/formatDate'
import { 
  CheckIcon, 
  XCircleIcon, 
  BanknotesIcon, 
  ArrowTrendingUpIcon, 
  ArrowTrendingDownIcon, 
  ScaleIcon, 
  CreditCardIcon, 
  TrashIcon 
} from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'

const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const { showToast } = useToast()
const transactions = ref([])
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)
const filterType = ref('')

// Default form state
const emptyForm = () => ({ 
  id: null, 
  type: 'income', 
  date: new Date().toISOString().substr(0, 10), 
  description: '', 
  category: '', 
  amount: '', 
  note: '', 
  academic_year_id: yearStore.selectedYearId 
})

const form = ref(emptyForm())

// Filter logic
const filtered = computed(() => {
  let list = transactions.value
  if (filterType.value) list = list.filter(t => t.type === filterType.value)
  return list
})

// Financial Calculations
const totalIncome = computed(() => filtered.value.filter(t => t.type === 'income').reduce((a, t) => a + Number(t.amount), 0))
const totalExpense = computed(() => filtered.value.filter(t => t.type === 'expense').reduce((a, t) => a + Number(t.amount), 0))
const balance = computed(() => totalIncome.value - totalExpense.value)

onMounted(async () => { await load() })

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('budget_transactions')
    .select('*, academic_years(year_name)')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('date', { ascending: false })
  transactions.value = data || []
  loading.value = false
}

function openAdd() { 
  isEdit.value = false
  form.value = emptyForm()
  showModal.value = true 
}

function openEdit(t) { 
  isEdit.value = true
  form.value = { ...t, date: toInputDate(t.date) }
  showModal.value = true 
}

async function save() {
  if (!form.value.date || !form.value.amount) { 
    showToast('សូមបំពេញកាលបរិច្ឆេទ និងចំនួនទឹកប្រាក់', 'error')
    return 
  }
  saving.value = true
  const { id, academic_years: _y, ...payload } = form.value
  const { error } = isEdit.value
    ? await supabase.from('budget_transactions').update(payload).eq('id', id)
    : await supabase.from('budget_transactions').insert({ ...payload, school_id: auth.schoolId })
  
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  
  showToast(isEdit.value ? 'បានកែប្រែទិន្នន័យរួចរាល់!' : 'បានបញ្ចូលទិន្នន័យរួចរាល់!', 'success')
  showModal.value = false
  load()
}

async function doDelete() {
  const { error } = await supabase.from('budget_transactions').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបទិន្នន័យរួចរាល់', 'success')
  load()
}

// Format number for Riel (No decimals)
function fmt(n) { 
  return Number(n).toLocaleString('en-US', { 
    minimumFractionDigits: 0, 
    maximumFractionDigits: 0 
  }) 
}
</script>

<template>
  <div>
    <!-- Page Header -->
    <div class="page-header">
      <div>
        <h1 class="page-title">ថវិកា និងចំណាយ</h1>
        <p class="page-subtitle">ការតាមដានចំណូល និងចំណាយផ្សេងៗប្រចាំឆ្នាំសិក្សា</p>
      </div>
      <button class="btn btn-primary" @click="openAdd">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        បន្ថែមប្រតិបត្តិការ
      </button>
    </div>

    <!-- Summary Cards -->
    <div class="grid-cols-3" style="margin-bottom:20px;">
      <div class="stat-card">
        <div class="stat-icon" style="background:#d1fae5;"><BanknotesIcon class="w-6 h-6" style="color:#059669;" /></div>
        <div class="stat-info">
          <div class="stat-label">ចំណូលសរុប</div>
          <div class="stat-value" style="color:#059669;font-size:20px;">{{ fmt(totalIncome) }} ៛</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:#fee2e2;"><ArrowTrendingDownIcon class="w-6 h-6" style="color:#dc2626;" /></div>
        <div class="stat-info">
          <div class="stat-label">ចំណាយសរុប</div>
          <div class="stat-value" style="color:#dc2626;font-size:20px;">{{ fmt(totalExpense) }} ៛</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" :style="`background:${balance >= 0 ? '#dbeafe' : '#fee2e2'}`">
          <ScaleIcon class="w-6 h-6" :style="`color:${balance >= 0 ? '#1d4ed8' : '#dc2626'}`" />
        </div>
        <div class="stat-info">
          <div class="stat-label">សមតុល្យ (នៅសល់)</div>
          <div class="stat-value" :style="`color:${balance >= 0 ? '#1d4ed8' : '#dc2626'};font-size:20px;` ">
            {{ fmt(balance) }} ៛
          </div>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="filters-bar">
      <select class="form-select" v-model="filterType" style="width:160px;">
        <option value="">ប្រភេទទាំងអស់</option>
        <option value="income">ចំណូល</option>
        <option value="expense">ចំណាយ</option>
      </select>
    </div>

    <!-- Table Card -->
    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:44px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      
      <div v-else-if="filtered.length === 0" class="empty-state">
        <CreditCardIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">មិនមានទិន្នន័យប្រតិបត្តិការទេ</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមប្រតិបត្តិការ</button>
      </div>

      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>កាលបរិច្ឆេទ</th>
              <th>ប្រភេទ</th>
              <th>ការពណ៌នា</th>
              <th>ប្រភេទទូទៅ</th>
              <th>ចំនួនទឹកប្រាក់</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in filtered" :key="t.id">
              <td>{{ formatDate(t.date) }}</td>
              <td>
                <span class="badge" :class="t.type === 'income' ? 'badge-green' : 'badge-red'">
                  <template v-if="t.type === 'income'">
                    <ArrowTrendingUpIcon class="w-3 h-3 inline-block align-middle" /> ចំណូល
                  </template>
                  <template v-else>
                    <ArrowTrendingDownIcon class="w-3 h-3 inline-block align-middle" /> ចំណាយ
                  </template>
                </span>
              </td>
              <td style="font-size:13px;">{{ t.description || '—' }}</td>
              <td><span v-if="t.category" class="badge badge-gray">{{ t.category }}</span><span v-else>—</span></td>
              <td style="font-weight:700;" :style="`color:${t.type === 'income' ? '#059669' : '#dc2626'}`">
                {{ t.type === 'income' ? '+' : '-' }}{{ fmt(t.amount) }} ៛
              </td>
              <td>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(t)">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = t">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal modal-lg">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែប្រតិបត្តិការ' : 'បន្ថែមប្រតិបត្តិការ' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group">
            <label class="form-label">ប្រភេទ</label>
            <select class="form-select" v-model="form.type">
              <option value="income">ចំណូល</option>
              <option value="expense">ចំណាយ</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">កាលបរិច្ឆេទ *</label>
            <input class="form-input" type="date" v-model="form.date" />
          </div>
          <div class="form-group">
            <label class="form-label">ចំនួនទឹកប្រាក់ (៛) *</label>
            <input class="form-input" type="number" v-model="form.amount" placeholder="0" min="0" />
          </div>
          <div class="form-group">
            <label class="form-label">ប្រភេទទូទៅ</label>
            <input class="form-input" v-model="form.category" placeholder="ឧ. សម្ភារៈសិក្សា, ជួសជុល..." />
          </div>
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">ការពណ៌នា</label>
            <input class="form-input" v-model="form.description" placeholder="បញ្ជាក់ព័ត៌មានខ្លីៗ" />
          </div>
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">សម្គាល់ផ្សេងៗ</label>
            <textarea class="form-textarea" v-model="form.note" rows="2" placeholder="កំណត់ចំណាំបន្ថែម (ប្រសិនបើមាន)"></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">
            {{ saving ? 'កំពុងរក្សាទុក...' : isEdit ? 'រក្សាទុកការផ្លាស់ប្តូរ' : 'រក្សាទុកទិន្នន័យ' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:360px;">
        <div class="modal-body" style="text-align:center;padding:28px 24px;">
          <TrashIcon class="w-12 h-12 text-red-400" style="margin: 0 auto 12px;" />
          <h3 style="margin-bottom:8px;">លុបប្រតិបត្តិការនេះ?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">តើអ្នកពិតជាចង់លុបទិន្នន័យនេះមែនទេ? សកម្មភាពនេះមិនអាចត្រឡប់ក្រោយវិញបានឡើយ។</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រម លុប</button>
        </div>
      </div>
    </div>
  </div>
</template>