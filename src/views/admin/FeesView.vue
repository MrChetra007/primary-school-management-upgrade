<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { useToast } from '@/composables/useToast'
import { formatDate } from '@/utils/formatDate'
import {
  BanknotesIcon,
  ClipboardDocumentListIcon,
  ExclamationTriangleIcon,
  ArrowTrendingUpIcon,
  Cog6ToothIcon,
  PlusIcon,
  ReceiptPercentIcon,
} from '@heroicons/vue/24/outline'

const router = useRouter()
const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const { showToast } = useToast()

const activeTab = ref('invoices')

const invoices = ref([])
const payments = ref([])
const structures = ref([])
const classes = ref([])
const loading = ref(true)
const saving = ref(false)

const statusFilter = ref('')
const classFilter = ref('')
const searchQuery = ref('')

const showGenerate = ref(false)
const generating = ref(false)
const gen = ref({ structure_id: '', month: new Date().getMonth() + 1, semester: 1 })

const payTarget = ref(null)
const payForm = ref({ amount: '', method: 'cash', reference_no: '', receipt_no: '', note: '' })

const khmerMonths = ['មករា','កុម្ភៈ','មីនា','មេសា','ឧសភា','មិថុនា','កក្កដា','សីហា','កញ្ញា','តុលា','វិច្ឆិកា','ធ្នូ']
const payMethods = { cash: 'សាច់ប្រាក់', bank: 'ធនាគារ', khqr: 'KHQR', wing: 'Wing', other: 'ផ្សេងៗ' }

onMounted(async () => {
  await Promise.all([loadInvoices(), loadStructures(), loadClasses(), loadPayments()])
  loading.value = false
})

async function loadInvoices() {
  const { data, error } = await supabase
    .from('student_fees')
    .select('*, students(full_name, class_id, classes(class_name)), fee_structures(name, cycle)')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('due_date', { ascending: true, nullsFirst: false })
  if (error) showToast(error.message, 'error')
  invoices.value = data || []
}

async function loadStructures() {
  const { data } = await supabase
    .from('fee_structures')
    .select('*, classes(class_name)')
    .eq('academic_year_id', yearStore.selectedYearId)
    .eq('is_active', true)
    .order('name')
  structures.value = data || []
}

async function loadClasses() {
  const { data } = await supabase
    .from('classes')
    .select('id, class_name')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('class_name')
  classes.value = data || []
}

async function loadPayments() {
  const { data } = await supabase
    .from('fee_payments')
    .select('*, student_fees(students(full_name), fee_structures(name))')
    .order('paid_at', { ascending: false })
    .limit(200)
  payments.value = data || []
}

// ── Summary ──
const totalDue = computed(() => invoices.value.reduce((a, f) => a + Number(f.amount_due), 0))
const totalPaid = computed(() => invoices.value.reduce((a, f) => a + Number(f.amount_paid), 0))
const outstanding = computed(() => totalDue.value - totalPaid.value)
const overdueCount = computed(() => invoices.value.filter((f) => f.status === 'overdue').length)

const filteredInvoices = computed(() => {
  let list = invoices.value
  if (statusFilter.value) list = list.filter((f) => f.status === statusFilter.value)
  if (classFilter.value) list = list.filter((f) => f.students?.class_id === classFilter.value)
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter((f) => (f.students?.full_name || '').toLowerCase().includes(q))
  }
  return list
})

const selectedStructure = computed(
  () => structures.value.find((s) => s.id === gen.value.structure_id) || null,
)

// ── Generate invoices ──
function openGenerate() {
  gen.value = { structure_id: structures.value[0]?.id || '', month: new Date().getMonth() + 1, semester: 1 }
  showGenerate.value = true
}

async function runGenerate() {
  const s = selectedStructure.value
  if (!s) { showToast('សូមជ្រើសរើសរចនាសម្ព័ន្ធថ្លៃ', 'error'); return }
  generating.value = true

  try {
    let studentsQuery = supabase
      .from('students')
      .select('id')
      .eq('is_graduated', false)
    studentsQuery = s.class_id
      ? studentsQuery.eq('class_id', s.class_id)
      : studentsQuery.eq('academic_year_id', yearStore.selectedYearId)
    const { data: studentList, error: sErr } = await studentsQuery
    if (sErr) throw sErr
    if (!studentList?.length) { showToast('មិនមានសិស្សសម្រាប់ចេញវិក័យប័ត្រ', 'error'); generating.value = false; return }

    // existing invoices for this structure + period
    let existQuery = supabase
      .from('student_fees')
      .select('student_id')
      .eq('fee_structure_id', s.id)
    if (s.cycle === 'monthly') existQuery = existQuery.eq('month', gen.value.month)
    if (s.cycle === 'semester') existQuery = existQuery.eq('semester', gen.value.semester)
    const { data: existing } = await existQuery
    const existingIds = new Set((existing || []).map((r) => r.student_id))

    const dueDate = s.cycle === 'monthly'
      ? new Date(new Date().getFullYear(), gen.value.month - 1, s.due_day || 10).toISOString().slice(0, 10)
      : null

    const rows = studentList
      .filter((st) => !existingIds.has(st.id))
      .map((st) => ({
        school_id: auth.schoolId,
        student_id: st.id,
        fee_structure_id: s.id,
        academic_year_id: yearStore.selectedYearId,
        cycle: s.cycle,
        month: s.cycle === 'monthly' ? gen.value.month : null,
        semester: s.cycle === 'semester' ? gen.value.semester : null,
        amount_due: s.amount,
        currency: s.currency,
        due_date: dueDate,
        status: 'due',
      }))

    if (!rows.length) { showToast('វិក័យប័ត្រទាំងអស់មានរួចហើយ', 'info'); generating.value = false; return }

    const { error } = await supabase.from('student_fees').insert(rows)
    if (error) throw error

    showToast(`បានចេញវិក័យប័ត្រ ${rows.length}`, 'success')
    showGenerate.value = false
    await loadInvoices()
  } catch (e) {
    showToast(e.message, 'error')
  } finally {
    generating.value = false
  }
}

// ── Record payment ──
function openPay(fee) {
  payTarget.value = fee
  payForm.value = {
    amount: Number(fee.amount_due) - Number(fee.amount_paid),
    method: 'cash',
    reference_no: '',
    receipt_no: `R${Date.now().toString().slice(-8)}`,
    note: '',
  }
}

async function savePayment() {
  const fee = payTarget.value
  const amount = Number(payForm.value.amount)
  if (!amount || amount <= 0 || !fee) { showToast('សូមបញ្ចូលចំនួនទឹកប្រាក់ត្រឹមត្រូវ', 'error'); return }
  saving.value = true
  const { error } = await supabase.from('fee_payments').insert({
    school_id: auth.schoolId,
    student_fee_id: fee.id,
    amount,
    currency: fee.currency,
    method: payForm.value.method,
    reference_no: payForm.value.reference_no || null,
    receipt_no: payForm.value.receipt_no || null,
    note: payForm.value.note || null,
    paid_at: new Date().toISOString(),
    recorded_by: auth.userId,
  })
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានកត់ត្រាការបង់ប្រាក់', 'success')
  payTarget.value = null
  await Promise.all([loadInvoices(), loadPayments()])
}

// ── Helpers ──
function periodLabel(f) {
  if (f.cycle === 'monthly') return khmerMonths[(f.month || 1) - 1]
  if (f.cycle === 'semester') return `ឆមាស ${f.semester}`
  return 'ប្រចាំឆ្នាំ'
}
const statusMeta = {
  paid: { label: 'បានបង់', cls: 'badge-green' },
  partial: { label: 'បង់មួយផ្នែក', cls: 'badge-yellow' },
  due: { label: 'ត្រូវបង់', cls: 'badge-blue' },
  overdue: { label: 'ហួសកំណត់', cls: 'badge-red' },
  waived: { label: 'លើកលែង', cls: 'badge-gray' },
}
function fmt(n, currency = 'KHR') {
  return `${Number(n).toLocaleString('en-US')} ${currency === 'USD' ? '$' : '៛'}`
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">ថ្លៃសិក្សា</h1>
        <p class="page-subtitle">ចេញវិក័យប័ត្រ តាមដានការបង់ប្រាក់ និងសមតុល្យសិស្ស</p>
      </div>
      <div style="display:flex;gap:10px;">
        <button class="btn btn-ghost" @click="router.push('/admin/fees/structures')">
          <Cog6ToothIcon class="w-4 h-4" />
          រចនាសម្ព័ន្ធថ្លៃ
        </button>
        <button class="btn btn-primary" @click="openGenerate">
          <PlusIcon class="w-4 h-4" />
          ចេញវិក័យប័ត្រ
        </button>
      </div>
    </div>

    <!-- Summary Cards -->
    <div class="grid-cols-4" style="margin-bottom:20px;">
      <div class="stat-card">
        <div class="stat-icon" style="background:#dbeafe;"><ClipboardDocumentListIcon class="w-6 h-6" style="color:#1d4ed8;" /></div>
        <div class="stat-info">
          <div class="stat-label">ត្រូវបង់សរុប</div>
          <div class="stat-value" style="font-size:18px;">{{ fmt(totalDue) }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:#d1fae5;"><BanknotesIcon class="w-6 h-6" style="color:#059669;" /></div>
        <div class="stat-info">
          <div class="stat-label">បានបង់សរុប</div>
          <div class="stat-value" style="color:#059669;font-size:18px;">{{ fmt(totalPaid) }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:#fef3c7;"><ArrowTrendingUpIcon class="w-6 h-6" style="color:#b45309;" /></div>
        <div class="stat-info">
          <div class="stat-label">នៅសល់</div>
          <div class="stat-value" style="color:#b45309;font-size:18px;">{{ fmt(outstanding) }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:#fee2e2;"><ExclamationTriangleIcon class="w-6 h-6" style="color:#dc2626;" /></div>
        <div class="stat-info">
          <div class="stat-label">ហួសកំណត់</div>
          <div class="stat-value" style="color:#dc2626;font-size:18px;">{{ overdueCount }}</div>
        </div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="tabs" style="display:flex;gap:6px;margin-bottom:16px;">
      <button class="btn" :class="activeTab === 'invoices' ? 'btn-primary' : 'btn-ghost'" @click="activeTab = 'invoices'">
        វិក័យប័ត្រ ({{ invoices.length }})
      </button>
      <button class="btn" :class="activeTab === 'payments' ? 'btn-primary' : 'btn-ghost'" @click="activeTab = 'payments'">
        ការបង់ប្រាក់ ({{ payments.length }})
      </button>
    </div>

    <!-- Invoices -->
    <template v-if="activeTab === 'invoices'">
      <div class="filters-bar">
        <input class="form-input" style="width:220px;" v-model="searchQuery" placeholder="ស្វែងរកសិស្ស..." />
        <select class="form-select" style="width:170px;" v-model="statusFilter">
          <option value="">ស្ថានភាពទាំងអស់</option>
          <option value="due">ត្រូវបង់</option>
          <option value="partial">បង់មួយផ្នែក</option>
          <option value="paid">បានបង់</option>
          <option value="overdue">ហួសកំណត់</option>
          <option value="waived">លើកលែង</option>
        </select>
        <select class="form-select" style="width:170px;" v-model="classFilter">
          <option value="">ថ្នាក់ទាំងអស់</option>
          <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
        </select>
      </div>

      <div class="card">
        <div v-if="loading" class="card-body">
          <div v-for="i in 5" :key="i" class="skeleton" style="height:44px;margin-bottom:10px;border-radius:8px;"></div>
        </div>

        <div v-else-if="filteredInvoices.length === 0" class="empty-state">
          <ReceiptPercentIcon class="w-12 h-12 text-gray-400" />
          <p class="empty-state-title">មិនមានវិក័យប័ត្រទេ</p>
          <button class="btn btn-primary" @click="openGenerate">ចេញវិក័យប័ត្រ</button>
        </div>

        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>សិស្ស</th>
                <th>ថ្នាក់</th>
                <th>រចនាសម្ព័ន្ធ</th>
                <th>កំឡុងពេល</th>
                <th>ត្រូវបង់</th>
                <th>បានបង់</th>
                <th>ស្ថានភាព</th>
                <th>ថ្ងៃកំណត់</th>
                <th>សកម្មភាព</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="f in filteredInvoices" :key="f.id">
                <td style="font-weight:700;">{{ f.students?.full_name || '—' }}</td>
                <td>{{ f.students?.classes?.class_name || '—' }}</td>
                <td style="font-size:13px;">{{ f.fee_structures?.name || '—' }}</td>
                <td style="font-size:13px;">{{ periodLabel(f) }}</td>
                <td style="font-weight:600;">{{ fmt(f.amount_due, f.currency) }}</td>
                <td style="font-weight:600;color:#059669;">{{ fmt(f.amount_paid, f.currency) }}</td>
                <td>
                  <span class="badge" :class="statusMeta[f.status]?.cls">
                    {{ statusMeta[f.status]?.label || f.status }}
                  </span>
                </td>
                <td style="font-size:13px;">{{ f.due_date ? formatDate(f.due_date) : '—' }}</td>
                <td>
                  <button
                    v-if="f.status !== 'paid' && f.status !== 'waived'"
                    class="btn btn-primary btn-sm"
                    @click="openPay(f)"
                  >
                    បង់ប្រាក់
                  </button>
                  <span v-else style="color:var(--text-secondary);font-size:12px;">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- Payments history -->
    <template v-else>
      <div class="card">
        <div v-if="payments.length === 0" class="empty-state">
          <BanknotesIcon class="w-12 h-12 text-gray-400" />
          <p class="empty-state-title">មិនទាន់មានការបង់ប្រាក់ទេ</p>
        </div>
        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>កាលបរិច្ឆេទ</th>
                <th>សិស្ស</th>
                <th>រចនាសម្ព័ន្ធ</th>
                <th>ចំនួនទឹកប្រាក់</th>
                <th>វិធីសាស្ត្រ</th>
                <th>លេខបង្កាន់ដៃ</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in payments" :key="p.id">
                <td>{{ formatDate(p.paid_at) }}</td>
                <td style="font-weight:700;">{{ p.student_fees?.students?.full_name || '—' }}</td>
                <td style="font-size:13px;">{{ p.student_fees?.fee_structures?.name || '—' }}</td>
                <td style="font-weight:700;color:#059669;">{{ fmt(p.amount, p.currency) }}</td>
                <td><span class="badge badge-gray">{{ payMethods[p.method] || p.method }}</span></td>
                <td style="font-size:13px;">{{ p.receipt_no || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- Generate Modal -->
    <div v-if="showGenerate" class="modal-overlay" @click.self="showGenerate = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">ចេញវិក័យប័ត្រ</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showGenerate = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">រចនាសម្ព័ន្ធថ្លៃ *</label>
            <select class="form-select" v-model="gen.structure_id">
              <option value="">— ជ្រើសរើស —</option>
              <option v-for="s in structures" :key="s.id" :value="s.id">
                {{ s.name }} · {{ fmt(s.amount, s.currency) }}{{ s.classes ? ' · ' + s.classes.class_name : ' · គ្រប់ថ្នាក់' }}
              </option>
            </select>
          </div>
          <div v-if="selectedStructure?.cycle === 'monthly'" class="form-group">
            <label class="form-label">ខែ</label>
            <select class="form-select" v-model.number="gen.month">
              <option v-for="(m, i) in khmerMonths" :key="i" :value="i + 1">{{ m }}</option>
            </select>
          </div>
          <div v-if="selectedStructure?.cycle === 'semester'" class="form-group">
            <label class="form-label">ឆមាស</label>
            <select class="form-select" v-model.number="gen.semester">
              <option :value="1">ឆមាស ១</option>
              <option :value="2">ឆមាស ២</option>
            </select>
          </div>
          <p style="grid-column:1/-1;color:var(--text-secondary);font-size:13px;margin:0;">
            វិក័យប័ត្រនឹងត្រូវចេញសម្រាប់សិស្សទាំងអស់
            {{ selectedStructure?.class_id ? 'ក្នុងថ្នាក់ដែលបានជ្រើស' : 'ក្នុងឆ្នាំសិក្សានេះ' }}។
            វិក័យប័ត្រដែលមានរួចនឹងមិនត្រូវបានចេញស្ទួនទេ។
          </p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showGenerate = false">បោះបង់</button>
          <button class="btn btn-primary" @click="runGenerate" :disabled="generating">
            {{ generating ? 'កំពុងចេញ...' : 'ចេញវិក័យប័ត្រ' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Payment Modal -->
    <div v-if="payTarget" class="modal-overlay" @click.self="payTarget = null">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">កត់ត្រាការបង់ប្រាក់</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="payTarget = null">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div style="grid-column:1/-1;background:var(--bg-secondary,#f8fafc);padding:12px 14px;border-radius:10px;font-size:13px;">
            <b>{{ payTarget.students?.full_name }}</b> · {{ payTarget.fee_structures?.name }} ·
            {{ periodLabel(payTarget) }}
            <div style="color:var(--text-secondary);margin-top:4px;">
              ត្រូវបង់ {{ fmt(payTarget.amount_due, payTarget.currency) }} ·
              បានបង់ {{ fmt(payTarget.amount_paid, payTarget.currency) }}
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">ចំនួនទឹកប្រាក់ *</label>
            <input class="form-input" type="number" v-model="payForm.amount" min="0" />
          </div>
          <div class="form-group">
            <label class="form-label">វិធីសាស្ត្រ</label>
            <select class="form-select" v-model="payForm.method">
              <option value="cash">សាច់ប្រាក់</option>
              <option value="bank">ធនាគារ</option>
              <option value="khqr">KHQR</option>
              <option value="wing">Wing</option>
              <option value="other">ផ្សេងៗ</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">លេខបង្កាន់ដៃ</label>
            <input class="form-input" v-model="payForm.receipt_no" />
          </div>
          <div class="form-group">
            <label class="form-label">លេខយោង</label>
            <input class="form-input" v-model="payForm.reference_no" placeholder="ឧ. លេខប្រតិបត្តិការធនាគារ" />
          </div>
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">កំណត់ចំណាំ</label>
            <textarea class="form-textarea" v-model="payForm.note" rows="2"></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="payTarget = null">បោះបង់</button>
          <button class="btn btn-primary" @click="savePayment" :disabled="saving">
            {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
