<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { computeRank } from '@/utils/scoreCalculator'
import { useAuthStore } from '@/stores/auth'
import { useSchoolStore } from '@/stores/school'
import { useAcademicYearStore } from '@/stores/academicYear'
import { useToast } from '@/composables/useToast'
import { PrinterIcon, ArrowLeftIcon } from '@heroicons/vue/24/outline'
import symbol from '@/assets/symbol.png'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const schoolStore = useSchoolStore()
const yearStore = useAcademicYearStore()
const { showToast } = useToast()

const loading = ref(true)
const classInfo = ref(null)
const students = ref([])
const subjects = ref([])
const allScores = ref([])
const attendancesMap = ref({})
const messagesMap = ref({})
const schoolInfo = ref(null)
const teacherName = ref('')

const months = ['មករា','កុម្ភៈ','មីនា','មេសា','ឧសភា','មិថុនា','កក្កដា','សីហា','កញ្ញា','តុលា','វិច្ឆិកា','ធ្នូ']

const classId = route.query.classId
const academicYearId = route.query.academicYearId
const scoreType = route.query.scoreType || 'monthly'
const month = parseInt(route.query.month) || null
const semester = parseInt(route.query.semester) || null

function getGrade(score) {
  if (score >= 9) return 'A'
  if (score >= 8) return 'B'
  if (score >= 7) return 'C'
  if (score >= 6) return 'D'
  if (score >= 5) return 'E'
  return 'F'
}

const periodLabel = computed(() => {
  if (scoreType === 'monthly' && month) return `ប្រចាំខែ${months[month - 1] || ''}`
  if (scoreType === 'semester') return `ឆមាសទី${semester || 1}`
  return ''
})

const rankedList = computed(() => {
  const list = students.value.map(s => {
    const ss = allScores.value.filter(sc => sc.student_id === s.id).map(sc => ({ score: sc.score }))
    return {
      id: s.id,
      full_name: s.full_name,
      gender: s.gender,
      average: ss.length > 0
        ? Number((ss.reduce((a, b) => a + Number(b.score), 0) / ss.length).toFixed(2))
        : 0
    }
  })
  return computeRank(list)
})

onMounted(async () => {
  try {
    const [{ data: classData }, { data: infoData }, { data: teacherData }] = await Promise.all([
      supabase.from('classes').select('*, academic_years!inner(id, year_name)').eq('id', classId).single(),
      supabase.from('school_information').select('*').limit(1).maybeSingle(),
      supabase.from('teachers').select('full_name').eq('user_id', auth.userId).maybeSingle()
    ])

    classInfo.value = classData
    schoolInfo.value = infoData || {}
    teacherName.value = teacherData?.full_name || auth.teacherProfile?.full_name || ''

    if (!classData || !classData.id) {
      loading.value = false
      return
    }

    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name, gender')
      .eq('class_id', classData.id)
      .eq('is_graduated', false)
      .order('full_name')

    students.value = stuData || []
    const studentIds = (stuData || []).map(s => s.id)

    if (studentIds.length > 0) {
      const [{ data: csData }, { data: scoreData }] = await Promise.all([
        supabase.from('class_subjects').select('id, subject_id, subjects(subject_name)').eq('class_id', classData.id),
        (() => {
          let q = supabase.from('scores').select('*, subjects(subject_name)').in('student_id', studentIds).eq('academic_year_id', academicYearId).eq('score_type', scoreType)
          if (scoreType === 'monthly' && month) q = q.eq('month', month)
          return q
        })()
      ])

      subjects.value = csData || []
      allScores.value = scoreData || []

      const year = new Date().getFullYear()
      const m = scoreType === 'monthly' ? month : new Date().getMonth() + 1
      const startDate = `${year}-${String(m).padStart(2, '0')}-01`
      const endMonth = m === 12 ? 1 : m + 1
      const endDate = `${endMonth === 1 ? year + 1 : year}-${String(endMonth).padStart(2, '0')}-01`

      const [{ data: attData }, { data: msgData }] = await Promise.all([
        supabase.from('attendances').select('*').in('student_id', studentIds).gte('date', startDate).lt('date', endDate),
        supabase.from('report_messages').select('student_id, teacher_text').in('student_id', studentIds)
      ])

      const attMap = {}
      for (const att of attData || []) {
        if (!attMap[att.student_id]) attMap[att.student_id] = []
        attMap[att.student_id].push(att)
      }
      attendancesMap.value = attMap

      const msgMap = {}
      for (const m of msgData || []) msgMap[m.student_id] = m.teacher_text
      messagesMap.value = msgMap
    }

    loading.value = false
  } catch (e) {
    showToast(e.message, 'error')
    loading.value = false
  }
})

const htmlContent = computed(() => {
  if (loading.value || !classInfo.value) return ''
  return buildPrintHtml()
})

function getStudentScores(studentId) {
  const map = {}
  const ss = allScores.value.filter(sc => sc.student_id === studentId)
  for (const cs of subjects.value) {
    const match = ss.find(s => s.subject_id === cs.subject_id)
    map[cs.subject_id] = match ? match.score : '-'
  }
  return map
}

function getAttendance(studentId) {
  const atts = attendancesMap.value[studentId] || []
  const total = atts.length
  const present = atts.filter(a => a.status === 'present').length
  const absent = atts.filter(a => a.status === 'absent' || a.status === 'late').length
  const leave = atts.filter(a => a.status === 'permission').length
  const rate = total > 0 ? Math.round((present / total) * 100) : 0
  return { total, present, absent, leave, rate }
}

// CUT LINE marker, reused between the two halves of a page
const CUT_LINE = '<div class="cut-line">— — — — — — — — កាត់ត្រង់នេះ — — — — — — — —</div>'

function buildPrintHtml() {
  const schoolName = schoolInfo.value?.name_khmer || schoolStore.schoolName || 'សាលាបឋមសិក្សា'
  const schoolAddress = schoolInfo.value?.address || ''
  const logo = schoolInfo.value?.logo_url || schoolStore.logoUrl || ''
  const directorName = schoolInfo.value?.director_name || ''
  const stampUrl = schoolInfo.value?.stamp_url || ''
  const className = classInfo.value?.class_name || ''
  const yearName = classInfo.value?.academic_years?.year_name || yearStore.selectedYearName || ''
  const list = rankedList.value
  const subjCount = subjects.value.length
  const colCount = subjCount <= 5 ? 1 : subjCount <= 10 ? 2 : 3

  // ---- Renders ONE student's card only (no cut-line, no page wrapper) ----
  function buildStudentCard(student) {
    const scores = getStudentScores(student.id)
    const att = getAttendance(student.id)
    const teacherMsg = messagesMap.value[student.id] || ''

    const cells = subjects.value.map(cs => {
      const score = scores[cs.subject_id]
      const grade = typeof score === 'number' ? getGrade(score) : '-'
      const subjName = cs.subjects?.subject_name || ''
      return `
        <div class="subj-cell">
          <span class="subj-name">${subjName}</span>
          <span class="subj-score">${score}</span>
          <span class="grade-chip chip-${grade}">${grade}</span>
        </div>`
    })

    let subjectsHtml
    if (colCount === 1) {
      subjectsHtml = cells.join('')
    } else {
      const perCol = Math.ceil(cells.length / colCount)
      const cols = Array.from({ length: colCount }, (_, ci) => {
        const start = ci * perCol
        return `<div class="subj-col">${cells.slice(start, start + perCol).join('')}</div>`
      })
      subjectsHtml = cols.join('')
    }

    return `
      <div class="card-container">
        <div class="report-card">
          <div class="letterhead">
            <div class="lh-left">
              ${logo ? `<img src="${logo}" class="lh-logo" />` : '<div class="lh-logo-placeholder">🏫</div>'}
              <div class="lh-text">
                <div class="lh-school-name">${schoolName}</div>
                <div class="lh-address">${schoolAddress}</div>
              </div>
            </div>
            <div class="lh-right">
              <div class="lh-label">សន្លឹកលទ្ធផលសិក្សា</div>
            </div>
          </div>

          <div class="student-info-bar">
            <div class="si-row">
              <span class="si-label">ឈ្មោះ:</span>
              <span class="si-value">${student.full_name}</span>
            </div>
            <div class="si-row">
              <span class="si-label">ថ្នាក់:</span>
              <span class="si-value">${className}</span>
              <span class="si-label" style="margin-left:24px;">ភេទ:</span>
              <span class="si-value">${student.gender === 'female' ? 'ស្រី' : 'ប្រុស'}</span>
            </div>
            <div class="si-row">
              <span class="si-label">កាលបរិច្ឆេទ:</span>
              <span class="si-value">${periodLabel.value} • ឆ្នាំសិក្សា ${yearName}</span>
            </div>
          </div>

          <div class="subjects-section ${colCount > 1 ? 'multi-col' : 'single-col'}">
            ${subjectsHtml}
          </div>

          <div class="attendance-note-section">
            <div class="attendance-block">
              <div class="att-title">វត្តមាន</div>
              <div class="att-grid">
                <div class="att-item">
                  <span class="att-num">${att.present}</span>
                  <span class="att-label">វត្តមាន</span>
                </div>
                <div class="att-item">
                  <span class="att-num att-absent">${att.absent}</span>
                  <span class="att-label">អវត្តមាន</span>
                </div>
                <div class="att-item">
                  <span class="att-num att-leave">${att.leave}</span>
                  <span class="att-label">សុំច្បាប់</span>
                </div>
                <div class="att-item">
                  <span class="att-num">${att.total}</span>
                  <span class="att-label">សរុប</span>
                </div>
              </div>
              <div class="att-rate">${att.rate}%</div>
            </div>
            <div class="note-block">
              <div class="note-title">សារគ្រូ</div>
              <div class="note-text">${teacherMsg || '—'}</div>
            </div>
          </div>

          <div class="signature-block">
            <div class="sig-side">
              <div class="sig-date">ថ្ងៃទី ________ ខែ ________ ឆ្នាំ ________</div>
              <div class="sig-role">នាយក</div>
              <div class="sig-line"></div>
              <div class="sig-name">${directorName}</div>
              ${stampUrl ? `<img src="${stampUrl}" class="sig-stamp" />` : `<div class="sig-stamp-placeholder">(ត្រា និងហត្ថលេខា)</div>`}
            </div>
            <div class="sig-side">
              <div class="sig-date">ថ្ងៃទី ________ ខែ ________ ឆ្នាំ ________</div>
              <div class="sig-role">គ្រូប្រចាំថ្នាក់</div>
              <div class="sig-line"></div>
              <div class="sig-name">${teacherName.value}</div>
            </div>
          </div>
        </div>
      </div>`
  }

  // ---- Group students into pairs, one <div class="report-page"> per A4 sheet ----
  const pages = []
  for (let i = 0; i < list.length; i += 2) {
    pages.push(list.slice(i, i + 2))
  }

  const pagesHtml = pages.map(pair => {
    const first = buildStudentCard(pair[0])
    const second = pair[1] ? buildStudentCard(pair[1]) : '<div class="card-container card-blank"></div>'
    return `<div class="report-page">${first}${CUT_LINE}${second}</div>`
  }).join('')

  return `<!DOCTYPE html>
<html lang="km">
<head>
  <meta charset="UTF-8"/>
  <title>Report Card - ${className}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Khmer:wght@400;600;700;800&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Noto Sans Khmer', 'Khmer OS', sans-serif;
      font-size: 11px;
      color: #1e293b;
      background: #fff;
      padding: 0;
      width: 210mm;
    }

    /* One A4 sheet = one .report-page, holding exactly two cards */
    .report-page {
      display: flex;
      flex-direction: column;
      justify-content: flex-start;
      min-height: 297mm;
      page-break-after: always;
      break-after: page;
    }
    .report-page:last-child {
      page-break-after: auto;
      break-after: auto;
    }

    .card-container {
      page-break-inside: avoid;
      break-inside: avoid;
      padding: 6mm 10mm;
    }

    .card-blank { visibility: hidden; }

    .report-card {
      border: 1.5px solid #cbd5e1;
      border-radius: 6px;
      overflow: hidden;
    }

    .cut-line {
      text-align: center;
      font-size: 10px;
      color: #94a3b8;
      padding: 4px 0;
      letter-spacing: 1px;
    }

    .letterhead {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 14px;
      border-bottom: 2px solid #1d4ed8;
    }

    .lh-left {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .lh-logo {
      width: 48px;
      height: 48px;
      object-fit: contain;
      border-radius: 4px;
    }

    .lh-logo-placeholder {
      width: 48px;
      height: 48px;
      background: #f1f5f9;
      border-radius: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
    }

    .lh-school-name {
      font-size: 16px;
      font-weight: 800;
      line-height: 1.2;
    }

    .lh-address {
      font-size: 10px;
      color: #6b7280;
      margin-top: 2px;
    }

    .lh-right {
      text-align: right;
    }

    .lh-label {
      font-size: 12px;
      font-weight: 700;
      color: #1d4ed8;
    }

    .student-info-bar {
      background: #f1f5f9;
      padding: 8px 14px;
      border-bottom: 1px solid #e2e8f0;
    }

    .si-row {
      font-size: 11px;
      line-height: 1.6;
    }

    .si-label {
      font-weight: 700;
      color: #475569;
    }

    .si-value {
      font-weight: 600;
    }

    .subjects-section {
      padding: 10px 14px;
      border-bottom: 1px solid #e2e8f0;
    }

    .subjects-section.multi-col {
      display: flex;
      gap: 8px;
    }

    .subj-col {
      flex: 1;
      min-width: 0;
    }

    .subj-cell {
      display: grid;
      grid-template-columns: 1fr auto auto;
      gap: 6px;
      align-items: center;
      padding: 3px 0;
      border-bottom: 1px dashed #f1f5f9;
      font-size: 10px;
    }

    .subj-cell:last-child {
      border-bottom: none;
    }

    .subj-name {
      font-weight: 600;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .subj-score {
      text-align: center;
      font-weight: 700;
      min-width: 24px;
    }

    .grade-chip {
      display: inline-block;
      padding: 1px 6px;
      border-radius: 4px;
      font-size: 9px;
      font-weight: 800;
      text-align: center;
      min-width: 20px;
    }

    .chip-A { background: #dcfce7; color: #166534; }
    .chip-B { background: #dbeafe; color: #1e40af; }
    .chip-C { background: #fef9c3; color: #854d0e; }
    .chip-D { background: #ffedd5; color: #9a3412; }
    .chip-E { background: #f1f5f9; color: #475569; }
    .chip-F { background: #fee2e2; color: #991b1b; }

    .attendance-note-section {
      display: flex;
      border-bottom: 1px solid #e2e8f0;
    }

    .attendance-block {
      width: 35%;
      background: #eff6ff;
      padding: 8px 12px;
      border-right: 1px solid #e2e8f0;
    }

    .att-title {
      font-size: 10px;
      font-weight: 700;
      color: #1d4ed8;
      margin-bottom: 6px;
    }

    .att-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 4px;
    }

    .att-item {
      text-align: center;
    }

    .att-num {
      display: block;
      font-size: 16px;
      font-weight: 800;
    }

    .att-absent { color: #dc2626; }
    .att-leave { color: #d97706; }

    .att-label {
      font-size: 9px;
      color: #64748b;
    }

    .att-rate {
      text-align: center;
      font-size: 18px;
      font-weight: 800;
      color: #16a34a;
      margin-top: 6px;
    }

    .note-block {
      flex: 1;
      padding: 8px 12px;
      background: #eff6ff;
    }

    .note-title {
      font-size: 10px;
      font-weight: 700;
      color: #1d4ed8;
      margin-bottom: 4px;
    }

    .note-text {
      font-size: 10px;
      line-height: 1.5;
      white-space: pre-wrap;
      color: #334155;
    }

    .signature-block {
      display: flex;
      padding: 10px 14px;
      gap: 24px;
    }

    .sig-side {
      flex: 1;
      text-align: center;
      position: relative;
    }

    .sig-date {
      font-size: 10px;
      color: #6b7280;
      margin-bottom: 6px;
    }

    .sig-role {
      font-weight: 700;
      font-size: 11px;
      margin-bottom: 4px;
    }

    .sig-line {
      border-top: 1px solid #64748b;
      margin: 24px 20px 4px;
    }

    .sig-name {
      font-size: 10px;
      color: #475569;
    }

    .sig-stamp {
      position: absolute;
      bottom: 18px;
      right: 10px;
      width: 60px;
      height: 60px;
      object-fit: contain;
      opacity: 0.8;
      pointer-events: none;
    }

    .sig-stamp-placeholder {
      font-size: 9px;
      color: #94a3b8;
      margin-top: 4px;
    }

    @media print {
      @page {
        size: A4;
        margin: 0;
      }
      body {
        width: 100%;
        padding: 0;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
    }
  </style>
</head>
<body>
  ${pagesHtml}
  <script>
    document.fonts.ready.then(function() {
      setTimeout(function() {
        window.focus();
        window.print();
      }, 400);
    });
    window.addEventListener('afterprint', function() {
      window.close();
    });
  <\/script>
</body>
</html>`
}

function handlePrint() {
  const html = htmlContent.value
  if (!html) {
    showToast('គ្មានទិន្នន័យសម្រាប់បោះពុម្ព', 'error')
    return
  }
  const win = window.open('', '_blank', 'width=900,height=1100,scrollbars=yes')
  if (!win) {
    showToast('សូមអនុញ្ញាត Pop-up សម្រាប់គេហទំព័រនេះ', 'error')
    return
  }
  win.document.open()
  win.document.write(html)
  win.document.close()
}

function goBack() {
  router.push('/teacher/scores/report-link')
}
</script>

<template>
  <div class="print-wrapper no-print">
    <div class="print-toolbar">
      <button class="btn btn-ghost" @click="goBack">
        <ArrowLeftIcon class="w-4 h-4" />
        ត្រឡប់
      </button>
      <h2 class="print-title">បោះពុម្ពរបាយការណ៍សិក្សា</h2>
      <button class="btn btn-primary" @click="handlePrint" :disabled="loading">
        <PrinterIcon class="w-4 h-4" />
        {{ loading ? 'កំពុងផ្ទុក...' : 'បោះពុម្ព' }}
      </button>
    </div>

    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>កំពុងផ្ទុកទិន្នន័យ...</p>
    </div>

    <div v-else-if="!classInfo || rankedList.length === 0" class="loading-state">
      <p style="color:var(--text-secondary);font-weight:700;">រកមិនឃើញទិន្នន័យ</p>
    </div>

    <div v-else class="print-preview">
      <div class="preview-info">
        <p>ថ្នាក់ <strong>{{ classInfo?.class_name }}</strong> · {{ periodLabel }} · ឆ្នាំសិក្សា {{ classInfo?.academic_years?.year_name }}</p>
        <p>សិស្សសរុប <strong>{{ rankedList.length }}</strong> នាក់ · មធ្យមភាគថ្នាក់ <strong>{{ (rankedList.reduce((a,b) => a + b.average, 0) / rankedList.length).toFixed(2) }}</strong></p>
      </div>

      <div class="minimap">
        <div v-for="(student, idx) in rankedList" :key="student.id" class="mini-card" :class="{ 'odd': idx % 2 === 1 }">
          <div class="mini-rank">{{ idx + 1 }}</div>
          <div class="mini-name">{{ student.full_name }}</div>
          <div class="mini-avg">{{ student.average.toFixed(1) }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.print-wrapper {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
}

.print-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 2px solid var(--border-default);
}

.print-title {
  font-size: 18px;
  font-weight: 800;
}

.loading-state {
  text-align: center;
  padding: 80px 20px;
}

.spinner {
  width: 32px; height: 32px;
  border: 3px solid var(--border-default);
  border-top-color: var(--primary-500);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  margin: 0 auto 12px;
}

@keyframes spin { to { transform: rotate(360deg); } }

.preview-info {
  background: #f8fafc;
  border-radius: 8px;
  padding: 12px 16px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.6;
  color: var(--text-secondary);
}

.minimap {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.mini-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  background: white;
  border: 1px solid var(--border-default);
  border-radius: 6px;
  font-size: 13px;
}

.mini-card.odd {
  border-left: 3px solid var(--primary-300);
}

.mini-rank {
  width: 28px;
  font-weight: 700;
  color: var(--text-secondary);
}

.mini-name {
  flex: 1;
  font-weight: 600;
}

.mini-avg {
  font-weight: 700;
  color: var(--primary-600);
}

@media print {
  .no-print { display: none !important; }
}
</style>