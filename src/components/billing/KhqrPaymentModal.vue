<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { supabase } from '@/lib/supabase'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  schoolId: { type: String, default: null },
  planId: { type: String, default: 'basic' },
  planName: { type: String, default: '' },
  periodStart: { type: String, default: null },
  periodEnd: { type: String, default: null },
})
const emit = defineEmits(['update:modelValue', 'paid'])

const loading = ref(false)
const error = ref(null)
const qrImageUrl = ref(null)
const invoiceId = ref(null)
const amount = ref(null)
const remaining = ref(0)

let pollTimer = null
let countdownTimer = null

const mmss = computed(() => {
  const s = Math.max(0, Number(remaining.value) || 0)
  const m = Math.floor(s / 60)
  const r = s % 60
  return `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`
})

const expired = computed(() => qrImageUrl.value && remaining.value <= 0)

function stopTimers() {
  if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
  if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null }
}

function close() {
  stopTimers()
  emit('update:modelValue', false)
}

function reset() {
  stopTimers()
  error.value = null
  qrImageUrl.value = null
  invoiceId.value = null
  amount.value = null
  remaining.value = 0
}

async function createPayment() {
  loading.value = true
  error.value = null
  try {
    const { data, error: fnErr } = await supabase.functions.invoke('khqr-payment', {
      body: {
        school_id: props.schoolId,
        plan_id: props.planId,
        period_start: props.periodStart,
        period_end: props.periodEnd,
        force_new: false,
      },
    })
    if (fnErr) throw fnErr
    if (data?.error) throw new Error(data.error)

    qrImageUrl.value = data.qr_image_url
    invoiceId.value = data.invoice?.id ?? null
    amount.value = data.amount ?? null
    remaining.value = data.remaining_seconds ?? 600
    startPolling()
    startCountdown()
  } catch (e) {
    error.value = e?.message || 'មិនអាចបង្កើតការទូទាត់បានទេ'
  } finally {
    loading.value = false
  }
}

function startPolling() {
  pollTimer = setInterval(async () => {
    if (!invoiceId.value) return
    const { data } = await supabase
      .from('subscription_invoices')
      .select('status')
      .eq('id', invoiceId.value)
      .single()
    if (data?.status === 'paid') {
      stopTimers()
      emit('paid')
      emit('update:modelValue', false)
    }
  }, 3000)
}

function startCountdown() {
  countdownTimer = setInterval(() => {
    if (remaining.value > 0) remaining.value -= 1
    else stopTimers()
  }, 1000)
}

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      reset()
      createPayment()
    } else {
      stopTimers()
    }
  },
)

onUnmounted(stopTimers)
</script>

<template>
  <div v-if="modelValue" class="modal-overlay" @click.self="close">
    <div class="modal khqr-modal">
      <div class="modal-header">
        <h3 class="modal-title">ទូទាត់ប្រាក់តាម KHQR — {{ planName }}</h3>
        <button class="btn btn-ghost btn-icon btn-sm" @click="close" aria-label="close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M18 6L6 18M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="modal-body khqr-body">
        <div v-if="loading" class="khqr-center">
          <div class="spinner"></div>
          <p>កំពុងបង្កើត QR…</p>
        </div>

        <div v-else-if="error" class="khqr-center">
          <p class="khqr-error">{{ error }}</p>
          <button class="btn btn-primary" @click="createPayment">ព្យាយាមម្តងទៀត</button>
        </div>

        <div v-else class="khqr-center">
          <p class="khqr-hint">ស្កេន QR ដោយកម្មវិធីធនាគារណាមួយ (Bakong)</p>
          <div class="khqr-frame">
            <img v-if="qrImageUrl" :src="qrImageUrl" alt="KHQR" class="khqr-img" />
          </div>
          <div v-if="amount != null" class="khqr-amount">${{ Number(amount).toFixed(2) }}</div>
          <div class="khqr-timer" :class="{ 'khqr-timer-expired': expired }">
            <template v-if="expired">QR ផុតកំណត់</template>
            <template v-else>នៅសល់ {{ mmss }}</template>
          </div>
          <button class="btn btn-secondary btn-sm" @click="createPayment">បង្កើត QR ថ្មី</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.khqr-modal {
  max-width: 420px;
}
.khqr-body {
  display: flex;
  justify-content: center;
}
.khqr-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  text-align: center;
  width: 100%;
}
.khqr-hint {
  font-size: 13px;
  color: var(--text-secondary);
}
.khqr-frame {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 240px;
  height: 240px;
  border: 1px solid var(--border-default);
  border-radius: 12px;
  padding: 10px;
  background: #fff;
}
.khqr-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.khqr-amount {
  font-size: 22px;
  font-weight: 700;
  color: var(--text-primary);
}
.khqr-timer {
  font-size: 14px;
  font-weight: 600;
  color: var(--primary-color);
}
.khqr-timer-expired {
  color: #ef4444;
}
.khqr-error {
  color: #ef4444;
  font-size: 13px;
}
.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--border-default);
  border-top-color: var(--primary-color);
  border-radius: 50%;
  animation: khqr-spin 0.8s linear infinite;
}
@keyframes khqr-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
