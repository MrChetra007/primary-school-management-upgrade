<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { computeMonthlyAverage, computeSemesterAverage, computeRank } from '@/utils/scoreCalculator'
import { 
  ChevronLeftIcon, 
  ArrowDownTrayIcon,
  CheckIcon,
  XCircleIcon,
  PaintBrushIcon
} from '@heroicons/vue/24/outline'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const loading = ref(true)
const classInfo = ref(null)
const topStudents = ref([])
const toast = ref(null)

// Certificate Customization
const selectedBorder = ref('border1') // border1, border2, etc.
const borders = [
  { id: 'border1', name: 'ម៉ូតទី ១ (Classic Gold)' },
  { id: 'border2', name: 'ម៉ូតទី ២ (Modern Blue)' },
  { id: 'border3', name: 'ម៉ូតទី ៣ (Elegant Floral)' },
  { id: 'border4', name: 'ម៉ូតទី ៤ (Official Red)' }
]

const mode = route.query.mode || 'monthly'
const month = Number(route.query.month)
const semester = Number(route.query.semester)

onMounted(async () => {
  if (auth.teacherProfile) await loadTopStudents()
  else {
    setTimeout(async () => {
      if (auth.teacherProfile) await loadTopStudents()
      else loading.value = false
    }, 1000)
  }
})

async function loadTopStudents() {
  loading.value = true
  const teacherId = auth.teacherProfile.id

  const { data: classData } = await supabase
    .from('classes')
    .select('*, academic_years!inner(id, year_name, status)')
    .eq('teacher_id', teacherId)
    .eq('academic_years.status', 'active')
    .maybeSingle()
  
  if (classData) {
    classInfo.value = classData
    
    // Get all students
    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name')
      .eq('class_id', classData.id)
    
    if (stuData && stuData.length > 0) {
      const studentIds = stuData.map(s => s.id)
      let list = []

      if (mode === 'monthly') {
        const { data: scores } = await supabase
          .from('scores')
          .select('*')
          .in('student_id', studentIds)
          .eq('month', month)
          .eq('score_type', 'monthly')
        
        list = stuData.map(student => {
          const s = scores.filter(sc => sc.student_id === student.id).map(sc => ({ score: sc.score }))
          return { full_name: student.full_name, average: computeMonthlyAverage(s) }
        })
      } else {
        const months = semester === 1 ? [1, 2, 3] : [4, 5, 6]
        const [examRes, monthRes] = await Promise.all([
          supabase.from('scores').select('*').in('student_id', studentIds).eq('semester', semester).eq('score_type', 'semester'),
          supabase.from('scores').select('*').in('student_id', studentIds).in('month', months).eq('score_type', 'monthly')
        ])
        
        list = stuData.map(student => {
          const mAvgs = months.map(m => {
            const s = monthRes.data?.filter(sc => sc.student_id === student.id && sc.month === m).map(sc => ({ score: sc.score }))
            return computeMonthlyAverage(s)
          })
          const examScores = examRes.data?.filter(sc => sc.student_id === student.id).map(sc => ({ score: sc.score }))
          const examAvg = computeMonthlyAverage(examScores)
          return { full_name: student.full_name, average: computeSemesterAverage(mAvgs, examAvg) }
        })
      }

      const ranked = computeRank(list).sort((a, b) => a.rank - b.rank)
      topStudents.value = ranked.filter(s => s.rank <= 5)
    }
  }
  loading.value = false
}

const certificateRefs = ref([])

async function downloadCertificates() {
  const pdf = new jsPDF('l', 'mm', 'a4') // Landscape A4
  const pageWidth = pdf.internal.pageSize.getWidth()
  const pageHeight = pdf.internal.pageSize.getHeight()

  showToast('កំពុងរៀបចំទាញយក...', 'info')

  for (let i = 0; i < certificateRefs.value.length; i++) {
    const element = certificateRefs.value[i]
    if (!element) continue

    const canvas = await html2canvas(element, { scale: 2, useCORS: true })
    const imgData = canvas.toDataURL('image/png')
    
    if (i > 0) pdf.addPage('l', 'mm', 'a4')
    pdf.addImage(imgData, 'PNG', 0, 0, pageWidth, pageHeight)
  }

  pdf.save(`Certificates_${classInfo.value?.class_name}_Top5.pdf`)
  showToast('ទាញយកបានជោគជ័យ!', 'success')
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}

const contextName = computed(() => {
  if (mode === 'monthly') {
    const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']
    return `ប្រចាំខែ${months[month - 1]}`
  }
  return `ប្រចាំឆមាសទី ${semester}`
})
</script>

<template>
  <div class="certificate-design-view">
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header no-print">
      <div style="display:flex; align-items:center; gap:16px;">
        <button class="btn btn-ghost btn-sm btn-icon" @click="router.back()">
          <ChevronLeftIcon class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">រចនាលិខិតសរសើរ</h1>
          <p class="page-subtitle">សម្រាប់សិស្សឆ្នើមទាំង ៥ នាក់ក្នុងថ្នាក់</p>
        </div>
      </div>
      
      <button class="btn btn-primary" @click="downloadCertificates" :disabled="loading || topStudents.length === 0">
        <ArrowDownTrayIcon class="w-4 h-4" />
        ទាញយក PDF ទាំងអស់
      </button>
    </div>

    <div class="design-layout">
      <!-- Toolbar -->
      <div class="toolbar card no-print">
        <div class="card-body">
          <div style="display:flex; align-items:center; gap:8px; margin-bottom:16px; color:var(--primary-700);">
            <PaintBrushIcon class="w-5 h-5" />
            <h3 style="font-size:16px; font-weight:700;">ជម្រើសរចនា</h3>
          </div>

          <div class="form-group">
            <label class="form-label">ជ្រើសរើសម៉ូតស៊ុម (Border Styles)</label>
            <div class="border-grid">
              <div 
                v-for="b in borders" 
                :key="b.id" 
                class="border-option"
                :class="{ active: selectedBorder === b.id }"
                @click="selectedBorder = b.id"
              >
                <div class="border-preview" :class="b.id"></div>
                <span>{{ b.name }}</span>
              </div>
            </div>
          </div>

          <div class="info-note" style="margin-top:24px;">
            <p><strong>ចំណាំ៖</strong> រូបភាពស៊ុម ({{ selectedBorder }}.png) នឹងត្រូវបានប្រើជាផ្ទៃខាងក្រោយ។</p>
          </div>
        </div>
      </div>

      <!-- Preview Area -->
      <div class="preview-area">
        <div v-if="loading" class="card card-body">
          <div class="skeleton" style="height:400px; border-radius:12px;"></div>
        </div>

        <div v-else-if="topStudents.length === 0" class="empty-state card">
          <XCircleIcon class="w-12 h-12 text-gray-400" />
          <p class="empty-state-title">មិនមានទិន្នន័យសិស្ស</p>
        </div>

        <div v-else class="certificates-stack">
          <div 
            v-for="(student, idx) in topStudents" 
            :key="student.full_name"
            class="certificate-container"
            :ref="el => certificateRefs[idx] = el"
          >
            <!-- Border Background -->
            <img :src="`/borders/${selectedBorder}.png`" class="cert-border" alt="border" />
            
            <!-- Content -->
            <div class="cert-content">
              <h1 class="cert-title">ព្រះរាជាណាចក្រកម្ពុជា</h1>
              <h2 class="cert-subtitle">ជាតិ សាសនា ព្រះមហាក្សត្រ</h2>
              
              <div class="cert-logo">
                <img src="@/assets/logo.png" alt="logo" v-if="false" />
                <div class="placeholder-logo">🏅</div>
              </div>

              <h2 class="cert-main-heading">លិខិតសរសើរ</h2>
              <p class="cert-text">គណៈគ្រប់គ្រងសាលា និងគ្រូថ្នាក់បឋមសិក្សា</p>
              
              <div class="cert-award-text">
                ជូនចំពោះសិស្សឈ្មោះ
                <div class="student-name">{{ student.full_name }}</div>
              </div>

              <div class="cert-achievement">
                ដែលបានខិតខំប្រឹងប្រែងសិក្សារហូតទទួលបាន <br/>
                <strong style="font-size:24px; color:var(--primary-700);">ចំណាត់ថ្នាក់លេខ {{ student.rank }}</strong>
              </div>

              <div class="cert-meta">
                <span>{{ contextName }}</span>
                <span>មធ្យមភាគ៖ {{ student.average }}</span>
                <span>ឆ្នាំសិក្សា៖ {{ classInfo.academic_years?.year_name }}</span>
              </div>

              <div class="cert-footer">
                <div class="footer-left">
                  <p>បានឃើញ និងឯកភាព</p>
                  <p style="font-weight:700;">នាយកសាលា</p>
                  <div class="signature-space"></div>
                </div>
                <div class="footer-right">
                  <p>ថ្ងៃទី ........ ខែ ........ ឆ្នាំ២០........</p>
                  <p style="font-weight:700;">គ្រូបន្ទុកថ្នាក់</p>
                  <div class="signature-space"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.certificate-design-view {
  max-width: 1400px;
  margin: 0 auto;
}

.design-layout {
  display: grid;
  grid-template-columns: 320px 1fr;
  gap: 24px;
  align-items: flex-start;
}

.toolbar {
  position: sticky;
  top: 24px;
}

.border-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 12px;
  margin-top: 12px;
}

.border-option {
  padding: 12px;
  border: 2px solid var(--border-default);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 12px;
}

.border-option:hover {
  background: var(--gray-50);
}

.border-option.active {
  border-color: var(--primary-color);
  background: var(--primary-50);
}

.border-preview {
  width: 60px;
  height: 40px;
  border-radius: 4px;
  background: #f8fafc;
  border: 1px solid #cbd5e1;
  position: relative;
}

.border-preview::after {
  content: '';
  position: absolute;
  inset: 4px;
  border: 2px solid #94a3b8;
}

.border1::after { border-color: #fbbf24; }
.border2::after { border-color: #3b82f6; }
.border3::after { border-color: #10b981; }
.border4::after { border-color: #ef4444; }

.info-note {
  background: #fffbeb;
  border-left: 4px solid #fbbf24;
  padding: 12px;
  border-radius: 0 8px 8px 0;
  font-size: 13px;
  color: #92400e;
}

/* Certificate Styles */
.certificates-stack {
  display: flex;
  flex-direction: column;
  gap: 40px;
}

.certificate-container {
  width: 297mm; /* A4 Landscape width */
  height: 210mm; /* A4 Landscape height */
  background: white;
  position: relative;
  overflow: hidden;
  box-shadow: 0 10px 30px rgba(0,0,0,0.1);
  margin: 0 auto;
  flex-shrink: 0;
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

.cert-content {
  position: relative;
  z-index: 2;
  height: 100%;
  padding: 60px 80px;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  color: #1e293b;
}

.cert-title { font-size: 20px; font-weight: 700; margin-bottom: 4px; }
.cert-subtitle { font-size: 16px; font-weight: 500; margin-bottom: 20px; }

.cert-logo { margin: 10px 0; }
.placeholder-logo { font-size: 60px; }

.cert-main-heading {
  font-size: 52px;
  font-weight: 800;
  color: #b45309;
  margin: 20px 0;
  font-family: var(--font-khmer);
}

.cert-text { font-size: 18px; margin-bottom: 30px; }

.cert-award-text {
  font-size: 22px;
  margin-bottom: 20px;
}

.student-name {
  font-size: 40px;
  font-weight: 800;
  color: var(--primary-700);
  margin-top: 10px;
  text-decoration: underline;
  text-underline-offset: 8px;
}

.cert-achievement {
  font-size: 20px;
  line-height: 1.6;
  margin-bottom: 40px;
}

.cert-meta {
  display: flex;
  gap: 40px;
  font-size: 16px;
  color: #475569;
  margin-bottom: 60px;
}

.cert-footer {
  width: 100%;
  display: flex;
  justify-content: space-between;
  margin-top: auto;
  padding: 0 40px;
}

.signature-space { height: 60px; }

@media (max-width: 1300px) {
  .design-layout { grid-template-columns: 1fr; }
  .toolbar { position: static; }
  .certificate-container { transform: scale(0.6); transform-origin: top center; margin-bottom: -150px; }
}
</style>
