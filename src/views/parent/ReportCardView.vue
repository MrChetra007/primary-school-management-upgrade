<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { computeRank } from '@/utils/scoreCalculator'
import { useVoiceRecorder } from '@/composables/useVoiceRecorder'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'

const route = useRoute()
const reportLinkId = route.params.report_link_id
const studentId = route.params.student_id

const loading = ref(true)
const link = ref(null)
const student = ref(null)
const scores = ref([])
const attendances = ref([])
const message = ref(null)
const parentText = ref('')
const saving = ref(false)
const saved = ref(false)
const toast = ref(null)
const rankedList = ref([])
const generating = ref(false)
const certificateRef = ref(null)

const { isRecording, audioUrl, error: voiceError, startRecording, stopRecording, uploadVoice } = useVoiceRecorder()

const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']

onMounted(async () => {
  const { data: linkData } = await supabase
    .from('report_links')
    .select('*, classes!inner(class_name)')
    .eq('id', reportLinkId)
    .single()

  if (!linkData) {
    loading.value = false
    return
  }

  link.value = linkData

  const { data: stuData } = await supabase
    .from('students')
    .select('*')
    .eq('id', studentId)
    .single()

  student.value = stuData

  const scoreQuery = supabase
    .from('scores')
    .select('*, subjects(subject_name)')
    .eq('student_id', studentId)
    .eq('academic_year_id', linkData.academic_year_id)
    .eq('score_type', linkData.score_type)

  if (linkData.score_type === 'monthly') {
    scoreQuery.eq('month', linkData.month)
  }

  const { data: scoreData } = await scoreQuery
  scores.value = scoreData || []

  const now = new Date()
  const year = now.getFullYear()
  let month = linkData.month || now.getMonth() + 1
  const startDate = `${year}-${String(month).padStart(2, '0')}-01`
  const endMonth = month === 12 ? 1 : month + 1
  const endYear = month === 12 ? year + 1 : year
  const endDate = `${endYear}-${String(endMonth).padStart(2, '0')}-01`

  const { data: attData } = await supabase
    .from('attendances')
    .select('*')
    .eq('student_id', studentId)
    .gte('date', startDate)
    .lt('date', endDate)

  attendances.value = attData || []

  const { data: msgData } = await supabase
    .from('report_messages')
    .select('*')
    .eq('report_link_id', reportLinkId)
    .eq('student_id', studentId)
    .maybeSingle()

  message.value = msgData || null
  if (message.value?.parent_text) {
    parentText.value = message.value.parent_text
  }

  // Fetch all class students for ranking
  const { data: classStudents } = await supabase
    .from('students')
    .select('id, full_name, gender')
    .eq('class_id', linkData.class_id)
    .eq('is_graduated', false)

  if (classStudents?.length) {
    const allIds = classStudents.map(s => s.id)
    const rankScoreQuery = supabase
      .from('scores')
      .select('student_id, score')
      .in('student_id', allIds)
      .eq('academic_year_id', linkData.academic_year_id)
      .eq('score_type', linkData.score_type)

    if (linkData.score_type === 'monthly') {
      rankScoreQuery.eq('month', linkData.month)
    }

    const { data: allScores } = await rankScoreQuery

    const list = classStudents.map(s => {
      const ss = (allScores || []).filter(sc => sc.student_id === s.id).map(sc => ({ score: sc.score }))
      return {
        id: s.id,
        full_name: s.full_name,
        gender: s.gender,
        average: ss.length > 0
          ? Number((ss.reduce((a, b) => a + Number(b.score), 0) / ss.length).toFixed(2))
          : 0
      }
    })

    rankedList.value = computeRank(list).sort((a, b) => a.rank - b.rank)
  }

  loading.value = false
})

const average = computed(() => {
  const valid = scores.value.filter(s => s.score !== null && s.score !== undefined)
  if (valid.length === 0) return 0
  const sum = valid.reduce((acc, s) => acc + Number(s.score), 0)
  return (sum / valid.length).toFixed(2)
})

const studentRank = computed(() => {
  return rankedList.value.find(r => r.id === studentId) || null
})

const classStats = computed(() => {
  const list = rankedList.value
  if (list.length === 0) return null
  const avg = list.reduce((a, b) => a + b.average, 0) / list.length
  return {
    total: list.length,
    classAverage: Number(avg.toFixed(2)),
    highest: Math.max(...list.map(p => p.average)),
    lowest: Math.min(...list.map(p => p.average)),
    passed: list.filter(p => p.average >= 5).length
  }
})

const attendanceStats = computed(() => {
  const total = attendances.value.length
  const present = attendances.value.filter(a => a.status === 'present').length
  const absent = attendances.value.filter(a => a.status === 'absent').length
  const late = attendances.value.filter(a => a.status === 'late').length
  const permission = attendances.value.filter(a => a.status === 'permission').length
  const rate = total > 0 ? Math.round((present / total) * 100) : 0
  return { total, present, absent, late, permission, rate }
})

function contextLabel() {
  if (!link.value) return ''
  if (link.value.score_type === 'monthly') {
    return `ប្រចាំខែ${months[link.value.month - 1] || ''}`
  }
  return `ឆមាសទី${link.value.semester || 1}`
}

function getGrade(score) {
  if (score >= 9) return 'A'
  if (score >= 8) return 'B'
  if (score >= 7) return 'C'
  if (score >= 6) return 'D'
  if (score >= 5) return 'E'
  return 'F'
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

function getImageUrl(name) {
  return new URL(`../../assets/${name}.png`, import.meta.url).href
}

function toKhmerNum(num) {
  if (num === null || num === undefined) return ''
  const khmerNums = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩']
  return num.toString().replace(/\d/g, d => khmerNums[d])
}

function contextPeriodLabel() {
  if (!link.value) return ''
  if (link.value.score_type === 'monthly') {
    const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']
    return `ប្រចាំខែ${months[link.value.month - 1] || ''}`
  }
  return `ប្រចាំឆមាសទី ${toKhmerNum(link.value.semester || 1)}`
}

async function generateCertificate() {
  generating.value = true
  showToast('កំពុងរៀបចំប័ណ្ណសរសើរ...', 'info')

  await new Promise(resolve => setTimeout(resolve, 200))

  const element = certificateRef.value
  if (!element) {
    generating.value = false
    return
  }

  try {
    const canvas = await html2canvas(element, { scale: 2, useCORS: true })
    const imgData = canvas.toDataURL('image/png')
    const pdf = new jsPDF('l', 'mm', 'a4')
    const pageWidth = pdf.internal.pageSize.getWidth()
    const pageHeight = pdf.internal.pageSize.getHeight()
    pdf.addImage(imgData, 'PNG', 0, 0, pageWidth, pageHeight)
    pdf.save(`ប័ណ្ណសរសើរ_${student.value?.full_name}.pdf`)
    showToast('ទាញយកប័ណ្ណសរសើរបានជោគជ័យ!', 'success')
  } catch (e) {
    showToast('មិនអាចបង្កើតប័ណ្ណសរសើរបានទេ', 'error')
  }

  generating.value = false
}

async function submitParentReply() {
  if (!parentText.value.trim() && !audioUrl.value) return
  saving.value = true
  saved.value = false

  let parentVoiceUrl = message.value?.parent_voice_url || null
  if (audioUrl.value) {
    parentVoiceUrl = await uploadVoice(reportLinkId, studentId, 'parent')
  }

  const { error: upsertError } = await supabase
    .from('report_messages')
    .upsert({
      report_link_id: reportLinkId,
      student_id: studentId,
      school_id: link.value.school_id,
      parent_text: parentText.value.trim(),
      parent_voice_url: parentVoiceUrl
    }, { onConflict: 'report_link_id,student_id' })

  saving.value = false

  if (upsertError) {
    showToast('បរាជ័យក្នុងការផ្ញើសារ', 'error')
    return
  }

  saved.value = true
  showToast('បានផ្ញើសារដោយជោគជ័យ', 'success')
}
</script>

<template>
  <div class="report-card-page">
    <div v-if="loading" style="text-align: center; padding: 80px 20px;">
      <div class="spinner"></div>
      <p style="margin-top: 12px; color: var(--text-secondary);">កំពុងផ្ទុក...</p>
    </div>

    <div v-else-if="!link || !student" style="text-align: center; padding: 80px 20px;">
      <p style="color: var(--danger-color); font-weight: 700;">ព័ត៌មានមិនត្រឹមត្រូវ</p>
    </div>

    <template v-else>
      <div class="toast-container">
        <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
          {{ toast.msg }}
        </div>
      </div>

      <!-- Student Header -->
      <div class="card student-header">
        <div class="card-body" style="display: flex; align-items: center; gap: 16px;">
          <div class="student-avatar">{{ (student.full_name || '')[0] }}</div>
          <div>
            <h2 style="font-size: 20px; font-weight: 800; margin: 0;">{{ student.full_name }}</h2>
            <p style="color: var(--text-secondary); font-size: 13px; margin: 4px 0 0;">
              ថ្នាក់ {{ link.classes?.class_name }} · {{ contextLabel() }}
            </p>
          </div>
        </div>
      </div>

      <!-- Ranking -->
      <div class="card" v-if="studentRank">
        <div class="card-header">
          <h3 class="card-title">ចំណាត់ថ្នាក់</h3>
        </div>
        <div class="card-body">
          <div class="rank-hero">
            <div class="rank-big-circle" :class="'rank-tier-' + Math.min(studentRank.rank, 5)">
              <span class="rank-big-num">{{ studentRank.rank }}</span>
              <span class="rank-big-label">ក្នុងចំណោម {{ classStats?.total }}</span>
            </div>
            <div class="rank-hero-stats">
              <div class="rh-stat">
                <span class="rh-val">{{ studentRank.average }}</span>
                <span class="rh-label">មធ្យមភាគ</span>
              </div>
              <div class="rh-stat">
                <span class="rh-val">{{ classStats?.classAverage }}</span>
                <span class="rh-label">មធ្យមភាគថ្នាក់</span>
              </div>
              <div class="rh-stat">
                <span class="rh-val">{{ classStats?.highest }}</span>
                <span class="rh-label">ខ្ពស់បំផុត</span>
              </div>
            </div>
          </div>
          <div class="rank-bars">
            <div class="rank-bar-row">
              <span class="rank-bar-label">សិស្សសរុប</span>
              <span class="rank-bar-val">{{ classStats?.total }} នាក់</span>
            </div>
            <div class="rank-bar-row">
              <span class="rank-bar-label">ជាប់មធ្យមភាគ</span>
              <span class="rank-bar-val success">{{ classStats?.passed }} នាក់</span>
            </div>
            <div class="rank-bar-row">
              <span class="rank-bar-label">ធ្លាក់មធ្យមភាគ</span>
              <span class="rank-bar-val danger">{{ (classStats?.total || 0) - (classStats?.passed || 0) }} នាក់</span>
            </div>
          </div>

          <button
            v-if="studentRank.rank <= 3"
            class="btn btn-primary"
            style="width: 100%; margin-top: 16px;"
            :disabled="generating"
            @click="generateCertificate"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M12 2L2 7l10 5 10-5-10-5z"/>
              <path d="M2 17l10 5 10-5"/>
              <path d="M2 12l10 5 10-5"/>
            </svg>
            {{ generating ? 'កំពុងបង្កើត...' : 'ទាញយកប័ណ្ណសរសើរ' }}
          </button>
        </div>
      </div>

      <!-- Scores -->
      <div class="card">
        <div class="card-header">
          <h3 class="card-title">ពិន្ទុសិក្សា</h3>
          <span class="badge badge-blue">មធ្យមភាគ {{ average }}</span>
        </div>
        <div class="card-body" style="padding: 0;">
          <table v-if="scores.length > 0" class="data-table">
            <thead>
              <tr>
                <th>មុខវិជ្ជា</th>
                <th style="text-align: center;">ពិន្ទុ</th>
                <th style="text-align: center;">កម្រិត</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in scores" :key="s.id">
                <td>{{ s.subjects?.subject_name }}</td>
                <td style="text-align: center; font-weight: 700;">{{ s.score ?? '-' }}</td>
                <td style="text-align: center;">
                  <span class="grade-chip" :class="'chip-' + getGrade(s.score)">{{ getGrade(s.score) }}</span>
                </td>
              </tr>
            </tbody>
          </table>
          <div v-else style="padding: 24px; text-align: center; color: var(--text-secondary);">
            គ្មានទិន្នន័យពិន្ទុ
          </div>
        </div>
      </div>

      <!-- Attendance -->
      <div class="card">
        <div class="card-header">
          <h3 class="card-title">វត្តមាន</h3>
        </div>
        <div class="card-body">
          <div class="att-stats">
            <div class="att-stat">
              <span class="att-num">{{ attendanceStats.present }}</span>
              <span class="att-label">វត្តមាន</span>
            </div>
            <div class="att-stat">
              <span class="att-num text-orange">{{ attendanceStats.late }}</span>
              <span class="att-label">យឺត</span>
            </div>
            <div class="att-stat">
              <span class="att-num text-red">{{ attendanceStats.absent }}</span>
              <span class="att-label">អវត្តមាន</span>
            </div>
            <div class="att-stat">
              <span class="att-num text-blue">{{ attendanceStats.permission }}</span>
              <span class="att-label">សុំច្បាប់</span>
            </div>
          </div>
          <div style="margin-top: 12px;">
            <div class="att-rate-bar">
              <div class="att-rate-fill" :style="{ width: attendanceStats.rate + '%' }"></div>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">
              អត្រាវត្តមាន {{ attendanceStats.rate }}% ({{ attendanceStats.total }} ថ្ងៃ)
            </p>
          </div>
        </div>
      </div>

      <!-- Teacher Message -->
      <div class="card" v-if="message?.teacher_text || message?.teacher_voice_url">
        <div class="card-header">
          <h3 class="card-title">សារពីគ្រូ</h3>
        </div>
        <div class="card-body">
          <p v-if="message.teacher_text" style="white-space: pre-wrap; line-height: 1.6;">{{ message.teacher_text }}</p>
          <audio v-if="message.teacher_voice_url" :src="message.teacher_voice_url" controls style="width: 100%; margin-top: 8px;"></audio>
        </div>
      </div>

      <!-- Parent Reply -->
      <div class="card">
        <div class="card-header">
          <h3 class="card-title">ការឆ្លើយតបរបស់អ្នក</h3>
        </div>
        <div class="card-body">
          <div v-if="message?.parent_text || message?.parent_voice_url" style="margin-bottom: 16px; padding: 12px; background: var(--gray-50); border-radius: 8px;">
            <p v-if="message.parent_text" style="white-space: pre-wrap; line-height: 1.6; margin-bottom: 8px;">{{ message.parent_text }}</p>
            <audio v-if="message.parent_voice_url" :src="message.parent_voice_url" controls style="width: 100%;"></audio>
          </div>

          <div class="form-group">
            <label class="form-label">សរសេរសារ</label>
            <textarea
              class="form-textarea"
              v-model="parentText"
              placeholder="សរសេរសារទៅកាន់គ្រូ..."
              rows="3"
            ></textarea>
          </div>

          <div style="display: flex; gap: 8px; margin-bottom: 16px;">
            <button
              v-if="!isRecording"
              class="btn btn-secondary btn-sm"
              @click="startRecording"
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <circle cx="12" cy="12" r="6"/>
                <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
              </svg>
              ថតសំឡេង
            </button>
            <button
              v-else
              class="btn btn-danger btn-sm"
              @click="stopRecording"
            >
              <svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16">
                <rect x="6" y="6" width="12" height="12" rx="2"/>
              </svg>
              ឈប់ថត
            </button>
          </div>

          <div v-if="isRecording" style="display: flex; align-items: center; gap: 8px; color: var(--danger-color); font-weight: 700; font-size: 13px;">
            <span class="recording-dot"></span>
            កំពុងថត...
          </div>

          <audio v-if="audioUrl && !isRecording" :src="audioUrl" controls style="width: 100%; margin-top: 8px;"></audio>

          <p v-if="voiceError" style="color: var(--danger-color); font-size: 13px; margin-top: 8px;">{{ voiceError }}</p>

          <button
            class="btn btn-primary"
            style="width: 100%; margin-top: 16px;"
            :disabled="saving || (!parentText.trim() && !audioUrl)"
            @click="submitParentReply"
          >
            {{ saving ? 'កំពុងផ្ញើ...' : 'ផ្ញើសារ' }}
          </button>

          <p v-if="saved" style="color: var(--success-color); font-size: 13px; margin-top: 8px; text-align: center; font-weight: 600;">
            បានផ្ញើសារដោយជោគជ័យ
          </p>
        </div>
      </div>
      <!-- Certificate (hidden, rendered to PDF) -->
      <div ref="certificateRef" class="certificate-hidden">
        <img :src="getImageUrl('border1')" class="cert-border" />
        <div class="cert-watermark">
          <img :src="getImageUrl('watermark')" />
        </div>
        <div class="cert-content">
          <div class="cert-header">
            <div class="cert-header-left">
              <div class="cert-logo">
                <img :src="getImageUrl('logo')" />
              </div>
              <div class="cert-header-text">
                <p class="font-muol">ក្រសួងអប់រំ យុវជន និងកីឡា</p>
                <p class="font-muol">សាលាបឋមសិក្សា</p>
              </div>
            </div>
            <div class="cert-header-right">
              <h3 class="font-muol text-blue">ព្រះរាជាណាចក្រកម្ពុជា</h3>
              <h4 class="font-muol text-blue">ជាតិ សាសនា ព្រះមហាក្សត្រ</h4>
            </div>
          </div>
          <div class="cert-title-section">
            <h1 class="cert-main-title">ប័ណ្ណសរសើរ</h1>
          </div>
          <div class="cert-body">
            <p>សូមធ្វើការសរសើរចំពោះសិស្សឈ្មោះ <span class="text-red font-muol">{{ student?.full_name }}</span></p>
            <p>ភេទ <span class="text-red">{{ student?.gender === 'female' ? 'ស្រី' : 'ប្រុស' }}</span></p>
            <p>ដែលទទួលបានលទ្ធផលល្អក្នុងការសិក្សា {{ contextPeriodLabel() }}</p>
            <p>និងទទួលបានចំណាត់ថ្នាក់លេខ <span class="text-red font-muol">{{ toKhmerNum(studentRank?.rank) }}</span></p>
            <p>ក្នុងចំណោមសិស្សសរុប <span class="text-red font-muol">{{ toKhmerNum(classStats?.total || 0) }}</span> នាក់</p>
            <p>ដោយទទួលបានពិន្ទុមធ្យមភាគ <span class="text-red font-muol">{{ studentRank?.average }}</span></p>
          </div>
          <div class="cert-footer">
            <div class="cert-footer-col">
              <p>ថ្ងៃទី ........ ខែ ........ ឆ្នាំ........</p>
              <p class="font-muol">នាយកសាលា</p>
              <div class="cert-sign-space"></div>
            </div>
            <div class="cert-stamp-box"></div>
            <div class="cert-footer-col">
              <p>ថ្ងៃទី ........ ខែ ........ ឆ្នាំ........</p>
              <p class="font-muol">គ្រូបន្ទុកថ្នាក់</p>
              <div class="cert-sign-space"></div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.report-card-page {
  max-width: 640px;
  margin: 0 auto;
  padding: 24px 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--border-default);
  border-top-color: var(--primary-500);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  margin: 0 auto;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.student-avatar {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  background: linear-gradient(135deg, var(--primary-500), var(--primary-700));
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  font-weight: 800;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
}

.data-table th {
  padding: 12px 16px;
  font-size: 12px;
  color: var(--text-secondary);
  background: var(--gray-50);
  text-align: left;
}

.data-table td {
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-default);
  font-size: 14px;
}

.grade-chip {
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 800;
  font-size: 11px;
}

.chip-A { background: #dcfce7; color: #15803d; }
.chip-B { background: #dbeafe; color: #1d4ed8; }
.chip-C { background: #fef3c7; color: #b45309; }
.chip-D { background: #fef9c3; color: #a16207; }
.chip-E { background: #ffedd5; color: #c2410c; }
.chip-F { background: #f1f5f9; color: #475569; }

.att-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

.att-stat {
  text-align: center;
  padding: 12px;
  background: var(--gray-50);
  border-radius: 10px;
}

.att-num {
  display: block;
  font-size: 24px;
  font-weight: 800;
  color: var(--primary-600);
}

.att-label {
  display: block;
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.text-orange { color: #f59e0b; }
.text-red { color: #ef4444; }
.text-blue { color: #3b82f6; }

.att-rate-bar {
  height: 8px;
  background: var(--gray-100);
  border-radius: 4px;
  overflow: hidden;
}

.att-rate-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--primary-500), #10b981);
  border-radius: 4px;
  transition: width 0.3s;
}

.rank-hero {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-bottom: 16px;
}

.rank-big-circle {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.rank-tier-1 { background: #fef3c7; border: 3px solid #fbbf24; }
.rank-tier-2 { background: #f1f5f9; border: 3px solid #94a3b8; }
.rank-tier-3 { background: #ffedd5; border: 3px solid #d97706; }
.rank-tier-4 { background: #e0f2fe; border: 3px solid #38bdf8; }
.rank-tier-5 { background: #fce7f3; border: 3px solid #f472b6; }

.rank-big-num {
  font-size: 28px;
  font-weight: 900;
  line-height: 1;
}

.rank-tier-1 .rank-big-num { color: #b45309; }
.rank-tier-2 .rank-big-num { color: #475569; }
.rank-tier-3 .rank-big-num { color: #9a3412; }
.rank-tier-4 .rank-big-num { color: #0369a1; }
.rank-tier-5 .rank-big-num { color: #be185d; }

.rank-big-label {
  font-size: 10px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.rank-hero-stats {
  display: flex;
  gap: 16px;
  flex: 1;
}

.rh-stat {
  text-align: center;
  flex: 1;
  padding: 8px;
  background: var(--gray-50);
  border-radius: 10px;
}

.rh-val {
  display: block;
  font-size: 20px;
  font-weight: 800;
  color: var(--primary-600);
}

.rh-label {
  display: block;
  font-size: 10px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.rank-bars {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.rank-bar-row {
  display: flex;
  justify-content: space-between;
  padding: 8px 12px;
  background: var(--gray-50);
  border-radius: 8px;
  font-size: 13px;
}

.rank-bar-label {
  color: var(--text-secondary);
  font-weight: 500;
}

.rank-bar-val {
  font-weight: 700;
}

.rank-bar-val.success { color: var(--color-success); }
.rank-bar-val.danger { color: var(--color-danger); }

.recording-dot {
  width: 8px;
  height: 8px;
  background: var(--danger-color);
  border-radius: 50%;
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.3; }
}

.certificate-hidden {
  position: fixed;
  top: -9999px;
  left: -9999px;
  width: 297mm;
  height: 210mm;
  background: white;
  overflow: hidden;
}

.cert-border {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: fill;
  pointer-events: none;
  z-index: 1;
}

.cert-watermark {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2;
  opacity: 0.12;
  pointer-events: none;
}

.cert-watermark img {
  width: 320px;
  height: auto;
}

.cert-content {
  position: relative;
  z-index: 3;
  height: 100%;
  padding: 60px 80px;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  color: #1e293b;
}

.cert-header {
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
}

.cert-header-left {
  display: flex;
  gap: 12px;
  text-align: left;
}

.cert-logo img {
  width: 80px;
  height: auto;
}

.cert-header-text p {
  font-size: 12px;
  margin-bottom: 2px;
  color: #1e293b;
}

.cert-header-right {
  text-align: center;
}

.cert-header-right h3 {
  font-size: 16px;
  margin-bottom: 4px;
}

.cert-header-right h4 {
  font-size: 12px;
}

.cert-title-section {
  text-align: center;
  margin-bottom: 24px;
}

.cert-main-title {
  font-family: 'Khmer OS Muol Light', 'Hanuman', serif;
  font-size: 56px;
  color: #d92b34;
  margin-bottom: 8px;
  text-shadow: 1px 1px 1px rgba(0,0,0,0.1);
}

.cert-body {
  text-align: center;
  font-size: 18px;
  line-height: 2.2;
  color: #1e293b;
  max-width: 750px;
}

.text-red { color: #d92b34; font-weight: 700; }

.cert-footer {
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-top: auto;
  padding: 0 30px 10px;
}

.cert-footer-col {
  text-align: center;
  flex: 1;
  font-size: 13px;
  color: #475569;
}

.cert-footer-col p {
  margin-bottom: 6px;
}

.cert-sign-space {
  height: 70px;
}

.cert-stamp-box {
  width: 90px;
  height: 110px;
  border: 2px solid #d92b34;
  margin: 0 30px 10px;
  flex-shrink: 0;
}

.font-muol {
  font-family: 'Khmer OS Muol Light', 'Hanuman', serif;
  font-weight: normal;
}

.text-blue { color: #1a3b8e; }

@media (max-width: 480px) {
  .att-stats {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
