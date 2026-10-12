import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { schoolTypeConfig, schoolTypeLabels, rollupLabel } from '@/config/schoolTypes'

export const useSchoolStore = defineStore('school', () => {
  const schoolId = ref(localStorage.getItem('current_school_id') || null)
  const schoolName = ref(localStorage.getItem('current_school_name') || null)
  const schoolCode = ref(localStorage.getItem('current_school_code') || null)
  const logoUrl = ref(localStorage.getItem('current_school_logo') || null)
  const schoolType = ref(localStorage.getItem('current_school_type') || 'primary')
  const rollupMode = ref(localStorage.getItem('current_school_rollup_mode') || 'grade_promotion')

  function readSchedule() {
    try {
      return JSON.parse(localStorage.getItem('current_school_weekly_schedule') || 'null')
        || { days: [], start: '', end: '' }
    } catch {
      return { days: [], start: '', end: '' }
    }
  }
  const defaultScoringMode = ref(
    localStorage.getItem('current_school_scoring_mode') || 'subject_scores'
  )
  const defaultWeeklySchedule = ref(readSchedule())

  // ── Configurable labels (Phase 1) ─────────────────────────────────────────
  const typeConfig = computed(() => schoolTypeConfig(schoolType.value))
  const labels = computed(() => schoolTypeLabels(schoolType.value))
  const rollupButtonLabel = computed(() => rollupLabel(schoolType.value, rollupMode.value))

  async function fetchSchool(id) {
    if (!id) return
    
    try {
      const { data, error } = await supabase
        .from('schools')
        .select('*')
        .eq('id', id)
        .single()
      
      if (error) throw error
      
      schoolId.value = data.id
      schoolName.value = data.name_khmer
      schoolCode.value = data.school_code
      logoUrl.value = data.logo_url
      schoolType.value = data.school_type || 'primary'
      rollupMode.value = data.rollup_mode || 'grade_promotion'

      localStorage.setItem('current_school_id', data.id)
      localStorage.setItem('current_school_name', data.name_khmer)
      localStorage.setItem('current_school_code', data.school_code)
      localStorage.setItem('current_school_type', schoolType.value)
      localStorage.setItem('current_school_rollup_mode', rollupMode.value)
      if (data.logo_url) localStorage.setItem('current_school_logo', data.logo_url)

      // school-level scoring + weekly-schedule defaults (migration v15)
      const { data: settings } = await supabase
        .from('school_settings')
        .select('default_scoring_mode, default_weekly_schedule')
        .eq('school_id', id)
        .maybeSingle()

      if (settings) {
        defaultScoringMode.value = settings.default_scoring_mode || 'subject_scores'
        defaultWeeklySchedule.value = settings.default_weekly_schedule
          || { days: [], start: '', end: '' }
        localStorage.setItem('current_school_scoring_mode', defaultScoringMode.value)
        localStorage.setItem(
          'current_school_weekly_schedule',
          JSON.stringify(defaultWeeklySchedule.value)
        )
      }

    } catch (e) {
      console.error('SchoolStore: Error fetching school info:', e)
    }
  }

  function setDefaults({ scoringMode, weeklySchedule } = {}) {
    if (scoringMode) {
      defaultScoringMode.value = scoringMode
      localStorage.setItem('current_school_scoring_mode', scoringMode)
    }
    if (weeklySchedule) {
      defaultWeeklySchedule.value = weeklySchedule
      localStorage.setItem('current_school_weekly_schedule', JSON.stringify(weeklySchedule))
    }
  }

  function clearSchool() {
    schoolId.value = null
    schoolName.value = null
    schoolCode.value = null
    logoUrl.value = null
    schoolType.value = 'primary'
    rollupMode.value = 'grade_promotion'
    defaultScoringMode.value = 'subject_scores'
    defaultWeeklySchedule.value = { days: [], start: '', end: '' }
    localStorage.removeItem('current_school_id')
    localStorage.removeItem('current_school_name')
    localStorage.removeItem('current_school_code')
    localStorage.removeItem('current_school_logo')
    localStorage.removeItem('current_school_type')
    localStorage.removeItem('current_school_rollup_mode')
    localStorage.removeItem('current_school_scoring_mode')
    localStorage.removeItem('current_school_weekly_schedule')
  }

  return {
    schoolId,
    schoolName,
    schoolCode,
    logoUrl,
    schoolType,
    rollupMode,
    defaultScoringMode,
    defaultWeeklySchedule,
    typeConfig,
    labels,
    rollupButtonLabel,
    fetchSchool,
    setDefaults,
    clearSchool
  }
})
