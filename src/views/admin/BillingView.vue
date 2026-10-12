<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useSchoolStore } from '@/stores/school'
import { usePlanStore } from '@/stores/plan'
import KhqrPaymentModal from '@/components/billing/KhqrPaymentModal.vue'

const auth = useAuthStore()
const schoolStore = useSchoolStore()
const planStore = usePlanStore()

const invoices = ref([])
const loadingInvoices = ref(false)
const showPay = ref(false)
const payPlanId = ref('basic')

const schoolId = computed(() => auth.schoolId || schoolStore.schoolId)

const plans = [
  {
    id: 'basic',
    name: 'Basic',
    price: 30,
    tagline: 'សម្រាប់សាលាតូច',
    features: [
      'រហូតដល់ 200 សិស្ស',
      'សិស្ស · វត្តមាន · ពិន្ទុ',
      'របាយការណ៍ · តំណមាតាបិតា',
      'លំហូរការអនុញ្ញាត',
      'ការគ្រប់គ្រងថ្លៃសិក្សា',
    ],
  },
  {
    id: 'pro',
    name: 'Pro',
    price: 50,
    tagline: 'គ្មានដែនកំណត់',
    features: [
      'សិស្សគ្មានដែនកំណត់',
      'អ្វីៗទាំងអស់ក្នុង Basic',
      'បណ្ណាល័យ',
      'ថវិកា · សម្ភារៈ',
      'ក្រុមប្រឹក្សាកិត្តិយស · វិញ្ញាបនបត្រ',
    ],
  },
]

const payPlan = computed(() => plans.find((p) => p.id === payPlanId.value) || plans[0])

const period = computed(() => {
  const start = new Date()
  const base =
    planStore.planExpiresAt && new Date(planStore.planExpiresAt).getTime() > Date.now()
      ? new Date(planStore.planExpiresAt)
      : new Date()
  const end = new Date(base)
  end.setDate(end.getDate() + 30)
  return { start: isoDate(start), end: isoDate(end) }
})

function isoDate(d) {
  return d.toISOString().slice(0, 10)
}

function planLabel(id) {
  return id === 'pro' ? 'Pro' : 'Basic'
}

function statusLabel() {
  if (!planStore.isActive) return 'មិនសកម្ម'
  if (planStore.expiringSoon) return 'ជិតផុតកំណត់'
  return 'សកម្ម'
}

function statusClass() {
  if (!planStore.isActive) return 'badge-red'
  if (planStore.expiringSoon) return 'badge-yellow'
  return 'badge-green'
}

function fmtDate(v) {
  if (!v) return '—'
  return new Date(v).toLocaleDateString('km-KH')
}

async function loadInvoices() {
  if (!schoolId.value) return
  loadingInvoices.value = true
  try {
    const { data, error } = await supabase
      .from('subscription_invoices')
      .select('id, plan_id, period_start, period_end, total_amount, currency, status, paid_at, created_at')
      .eq('school_id', schoolId.value)
      .order('created_at', { ascending: false })
    if (error) throw error
    invoices.value = data || []
  } catch (e) {
    console.error('BillingView: loadInvoices failed', e)
  } finally {
    loadingInvoices.value = false
  }
}

function openPay(planId) {
  payPlanId.value = planId
  showPay.value = true
}

async function onPaid() {
  if (schoolId.value) await planStore.fetchPlan(schoolId.value)
  await loadInvoices()
}

onMounted(() => {
  if (schoolId.value && !planStore.planMeta) planStore.fetchPlan(schoolId.value)
  loadInvoices()
})
</script>

<template>
  <div class="billing-page">
    <div class="page-header">
      <div>
        <h1 class="page-title">ការជាវប្រើប្រាស់</h1>
        <p class="page-subtitle">គ្រប់គ្រងគម្រោង និងការទូទាត់របស់សាលារៀន</p>
      </div>
    </div>

    <div v-if="!planStore.isActive" class="alert alert-danger">
      គម្រោងរបស់អ្នកមិនសកម្ម។ សូមបង់ប្រាក់ដើម្បីបន្តប្រើប្រាស់ប្រព័ន្ធ។
    </div>
    <div v-else-if="planStore.expiringSoon" class="alert alert-warning">
      គម្រោងនឹងផុតកំណត់ក្នុង {{ planStore.daysLeft }} ថ្ងៃ។ សូមបន្តការជាវជាមុន។
    </div>

    <div class="card current-plan">
      <div class="card-body current-plan-body">
        <div>
          <div class="current-plan-label">គម្រោងបច្ចុប្បន្ន</div>
          <div class="current-plan-name">
            {{ planStore.plan ? planLabel(planStore.plan) : '—' }}
            <span class="badge" :class="statusClass()">{{ statusLabel() }}</span>
          </div>
          <div class="current-plan-meta">
            ផុតកំណត់៖ {{ fmtDate(planStore.planExpiresAt) }}
            <template v-if="planStore.planExpiresAt && planStore.daysLeft !== null">
              ({{ planStore.daysLeft }} ថ្ងៃ)
            </template>
          </div>
        </div>
      </div>
    </div>

    <div class="plans-grid">
      <div
        v-for="p in plans"
        :key="p.id"
        class="plan-card"
        :class="{ 'plan-card-current': planStore.plan === p.id }"
      >
        <div class="plan-card-head">
          <div class="plan-card-name">{{ p.name }}</div>
          <div class="plan-card-tagline">{{ p.tagline }}</div>
          <div class="plan-card-price">
            <span class="plan-price-num">${{ p.price }}</span>
            <span class="plan-price-per">/ ខែ</span>
          </div>
        </div>
        <ul class="plan-card-features">
          <li v-for="f in p.features" :key="f">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M20 6L9 17l-5-5" />
            </svg>
            {{ f }}
          </li>
        </ul>
        <button
          class="btn"
          :class="planStore.plan === p.id ? 'btn-secondary' : 'btn-primary'"
          @click="openPay(p.id)"
        >
          {{ planStore.plan === p.id ? 'បន្តការជាវ' : planStore.plan === 'pro' && p.id === 'basic' ? 'ប្តូរទៅ Basic' : 'ជ្រើសរើស ' + p.name }}
        </button>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <h2 class="card-title">ប្រវត្តិវិក្កយបត្រ</h2>
        <button class="btn btn-ghost btn-sm" @click="loadInvoices">ផ្ទុកឡើងវិញ</button>
      </div>
      <div class="card-body">
        <div v-if="loadingInvoices" class="table-empty">កំពុងផ្ទុក…</div>
        <div v-else-if="invoices.length === 0" class="table-empty">មិនទាន់មានវិក្កយបត្រ</div>
        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>កាលបរិច្ឆេទ</th>
                <th>គម្រោង</th>
                <th>កំឡុងពេល</th>
                <th>ចំនួនទឹកប្រាក់</th>
                <th>ស្ថានភាព</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="inv in invoices" :key="inv.id">
                <td>{{ fmtDate(inv.created_at) }}</td>
                <td>{{ planLabel(inv.plan_id) }}</td>
                <td>{{ fmtDate(inv.period_start) }} → {{ fmtDate(inv.period_end) }}</td>
                <td>${{ Number(inv.total_amount).toFixed(2) }}</td>
                <td>
                  <span
                    class="badge"
                    :class="{
                      'badge-green': inv.status === 'paid',
                      'badge-yellow': inv.status === 'pending',
                      'badge-gray': inv.status === 'expired' || inv.status === 'void',
                    }"
                  >
                    {{ inv.status }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <KhqrPaymentModal
      v-model="showPay"
      :school-id="schoolId"
      :plan-id="payPlanId"
      :plan-name="payPlan.name"
      :period-start="period.start"
      :period-end="period.end"
      @paid="onPaid"
    />
  </div>
</template>

<style scoped>
.billing-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.alert {
  padding: 12px 16px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
}
.alert-danger {
  background: #fee2e2;
  color: #b91c1c;
}
.alert-warning {
  background: #fef3c7;
  color: #b45309;
}
.current-plan-body {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.current-plan-label {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-secondary);
  font-weight: 600;
}
.current-plan-name {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 22px;
  font-weight: 700;
  color: var(--text-primary);
  margin-top: 4px;
}
.current-plan-meta {
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 6px;
}
.plans-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
}
.plan-card {
  background: #fff;
  border: 1px solid var(--border-default);
  border-radius: 12px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.plan-card-current {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 1px var(--primary-color);
}
.plan-card-name {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
}
.plan-card-tagline {
  font-size: 12px;
  color: var(--text-secondary);
}
.plan-card-price {
  margin-top: 8px;
  display: flex;
  align-items: baseline;
  gap: 4px;
}
.plan-price-num {
  font-size: 32px;
  font-weight: 800;
  color: var(--text-primary);
}
.plan-price-per {
  font-size: 13px;
  color: var(--text-secondary);
}
.plan-card-features {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}
.plan-card-features li {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-primary);
}
.plan-card-features svg {
  width: 14px;
  height: 14px;
  color: var(--primary-color);
  flex-shrink: 0;
}
.table-empty {
  padding: 24px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13px;
}
</style>
