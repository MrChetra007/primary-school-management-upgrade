/**
 * schoolTypes.js
 * Single config map for per-school-type behaviour (Phase 1 of the SaaS plan).
 * Labels MUST come from here — never hardcode "ថ្នាក់ទី" / grade rules in views.
 *
 * school_type lives on `schools.school_type` ('primary' | 'english' | 'computer').
 */

export const SCHOOL_TYPES = {
  primary: {
    id: 'primary',
    labelKm: 'សាលាបឋមសិក្សា',
    defaultFeeCycle: 'monthly',
    defaultScoringMode: 'subject_scores',
    usesGradeParsing: true,
    maxGrade: 6,
    labels: {
      student: 'សិស្ស',
      teacher: 'គ្រូបង្រៀន',
      class: 'ថ្នាក់រៀន',
      grade: 'ថ្នាក់',
      term: 'ឆ្នាំសិក្សា',
      subject: 'មុខវិជ្ជា',
      rollup: 'រុញថ្នាក់',
      rollupComplete: 'បញ្ចប់ការសិក្សា'
    }
  },
  english: {
    id: 'english',
    labelKm: 'សាលាភាសាអង់គ្លេស',
    defaultFeeCycle: 'monthly',
    defaultScoringMode: 'simple_result',
    usesGradeParsing: false,
    maxGrade: null,
    labels: {
      student: 'សិស្ស',
      teacher: 'អ្នកបង្រៀន',
      class: 'កម្រិត',
      grade: 'កម្រិត',
      term: 'វគ្គសិក្សា',
      subject: 'មុខវិជ្ជា',
      rollup: 'បន្តកម្រិត',
      rollupComplete: 'បញ្ចប់វគ្គ'
    }
  },
  computer: {
    id: 'computer',
    labelKm: 'សាលាកុំព្យូទ័រ',
    defaultFeeCycle: 'one_time',
    defaultScoringMode: 'simple_result',
    usesGradeParsing: false,
    maxGrade: null,
    labels: {
      student: 'សិស្ស',
      teacher: 'អ្នកបង្រៀន',
      class: 'វគ្គសិក្សា',
      grade: 'កម្រិត',
      term: 'វគ្គសិក្សា',
      subject: 'មុខវិជ្ជា',
      rollup: 'បន្តវគ្គ',
      rollupComplete: 'បញ្ចប់វគ្គ'
    }
  }
}

export const SCHOOL_TYPE_OPTIONS = Object.values(SCHOOL_TYPES).map(t => ({
  value: t.id,
  label: t.labelKm
}))

export function schoolTypeConfig(type) {
  return SCHOOL_TYPES[type] || SCHOOL_TYPES.primary
}

export function schoolTypeLabels(type) {
  return schoolTypeConfig(type).labels
}

/**
 * Rollup label for a school, based on its rollup_mode + school_type.
 * Mirrors the SQL `schools.rollup_mode` values.
 */
export function rollupLabel(type, rollupMode) {
  const cfg = schoolTypeConfig(type)
  if (rollupMode === 'complete_only') return cfg.labels.rollupComplete
  return cfg.labels.rollup
}
