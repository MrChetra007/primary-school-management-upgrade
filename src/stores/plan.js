import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'

export const usePlanStore = defineStore('plan', () => {
  const plan = ref(null)              // 'basic' | 'pro'
  const planExpiresAt = ref(null)     // timestamptz | null (never paid)
  const gracePeriodEndsAt = ref(null) // timestamptz | null
  const schoolStatus = ref(null)      // 'active' | 'inactive'
  const planMeta = ref(null)          // { display_name, monthly_fee, max_students, features }
  const loading = ref(false)
  const error = ref(null)

  const isActive = computed(() => {
    if (schoolStatus.value !== 'active') return false
    const now = Date.now()
    const exp = planExpiresAt.value ? new Date(planExpiresAt.value).getTime() : null
    const grace = gracePeriodEndsAt.value ? new Date(gracePeriodEndsAt.value).getTime() : null
    return Boolean((exp && now < exp) || (grace && now < grace))
  })

  const daysLeft = computed(() => {
    if (!planExpiresAt.value) return null
    const diff = new Date(planExpiresAt.value).getTime() - Date.now()
    return Math.ceil(diff / (1000 * 60 * 60 * 24))
  })

  // 7-day (or fewer) warning window before the plan ends
  const expiringSoon = computed(
    () => isActive.value && daysLeft.value !== null && daysLeft.value <= 7,
  )

  const daysOverdue = computed(() => {
    if (isActive.value || !planExpiresAt.value) return 0
    const diff = Date.now() - new Date(planExpiresAt.value).getTime()
    return Math.floor(diff / (1000 * 60 * 60 * 24))
  })

  const features = computed(() => planMeta.value?.features || {})
  const studentCap = computed(() => planMeta.value?.max_students ?? null) // null = unlimited

  function hasFeature(feature) {
    return isActive.value && features.value[feature] === true
  }

  async function fetchPlan(schoolId) {
    if (!schoolId) {
      clearPlan()
      return
    }
    loading.value = true
    error.value = null
    try {
      const { data, error: err } = await supabase
        .from('schools')
        .select(
          'plan, plan_expires_at, grace_period_ends_at, status, plans(display_name, monthly_fee, max_students, features)',
        )
        .eq('id', schoolId)
        .single()
      if (err) throw err

      plan.value = data.plan
      planExpiresAt.value = data.plan_expires_at
      gracePeriodEndsAt.value = data.grace_period_ends_at
      schoolStatus.value = data.status
      planMeta.value = data.plans || null
    } catch (e) {
      console.error('PlanStore: fetchPlan failed', e)
      error.value = e
    } finally {
      loading.value = false
    }
  }

  function clearPlan() {
    plan.value = null
    planExpiresAt.value = null
    gracePeriodEndsAt.value = null
    schoolStatus.value = null
    planMeta.value = null
    error.value = null
  }

  return {
    plan,
    planExpiresAt,
    gracePeriodEndsAt,
    schoolStatus,
    planMeta,
    loading,
    error,
    isActive,
    daysLeft,
    expiringSoon,
    daysOverdue,
    features,
    studentCap,
    hasFeature,
    fetchPlan,
    clearPlan,
  }
})
