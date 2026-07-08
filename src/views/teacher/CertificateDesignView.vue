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
import { genderLabel } from '@/utils/gender'
import { useToast } from '@/composables/useToast'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const { showToast } = useToast()
const loading = ref(true)
const classInfo = ref(null)
const topStudents = ref([])
const semesterConfigs = ref([])

// Certificate Customization
const selectedBorder = ref('border1')
const borders = [
  { id: 'border1', name: 'ម៉ូតទី ១' },
  { id: 'border2', name: 'ម៉ូតទី ២' },
  { id: 'border3', name: 'ម៉ូតទី ៣' },
  { id: 'border4', name: 'ម៉ូតទី ៤' }
]

const assetImages = import.meta.glob('../../assets/*.png', {
  eager: true,
  query: '?url',
  import: 'default',
})

function getImageUrl(name) {
  return assetImages[`../../assets/${name}.png`] || ''
}

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
    .eq('academic_years.status', 'active').is('academic_years.deleted_at', null)
    .maybeSingle()
  
  if (classData) {
    classInfo.value = classData
    
    // Get all students
    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name, gender')
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
          return { 
            id: student.id,
            full_name: student.full_name, 
            gender: student.gender,
            average: computeMonthlyAverage(s) 
          }
        })
      } else {
        const { data: configs } = await supabase
          .from('semester_config')
          .select('*')
          .eq('academic_year_id', classData.academic_year_id)
          .eq('semester', semester)
          .maybeSingle()
        const months = configs?.months || (semester === 1 ? [12, 1, 2] : [5, 6, 7])
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
          return { 
            id: student.id,
            full_name: student.full_name, 
            gender: student.gender,
            average: computeSemesterAverage(mAvgs, examAvg) 
          }
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

    const canvas = await html2canvas(element, { scale: 2, useCORS: true, allowTaint: true })
    const imgData = canvas.toDataURL('image/png')
    
    if (i > 0) pdf.addPage('l', 'mm', 'a4')
    pdf.addImage(imgData, 'PNG', 0, 0, pageWidth, pageHeight)
  }

  pdf.save(`Certificates_${classInfo.value?.class_name}_Top5.pdf`)
  showToast('ទាញយកបានជោគជ័យ!', 'success')
}

function toKhmerNum(num) {
  if (num === null || num === undefined) return ''
  const khmerNums = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩']
  return num.toString().replace(/\d/g, d => khmerNums[d])
}

const contextName = computed(() => {
  if (mode === 'monthly') {
    const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']
    return `ប្រចាំខែ${months[month - 1]}`
  }
  return `ប្រចាំឆមាសទី ${toKhmerNum(semester)}`
})
</script>

<template>
  <div class="certificate-design-view">


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
                <img :src="getImageUrl(b.id)" class="border-preview-img" crossorigin="anonymous" />
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
            <img :src="getImageUrl(selectedBorder)" class="cert-border" alt="border" crossorigin="anonymous" />
            
            <!-- Watermark -->
            <div class="cert-watermark">
              <img :src="getImageUrl('watermark')" alt="watermark" crossorigin="anonymous" />
            </div>

            <!-- Content -->
            <div class="cert-content">
              <!-- Top Header Section -->
              <div class="cert-header">
                <div class="header-left">
                  <div class="moey-logo-small">
                    <img :src="getImageUrl('logo')" alt="logo" crossorigin="anonymous" />
                  </div>
                  <div class="header-text-left">
                    <p class="font-muol">ក្រសួងអប់រំ យុវជន និងកីឡា</p>
                    <p class="font-muol">ខេត្ត៖ {{ classInfo.school_province || '........' }}</p>
                    <p class="font-muol">សាលាបឋមសិក្សា៖ {{ auth.school?.name || '........' }}</p>
                  </div>
                </div>
                <div class="header-right">
                  <h3 class="font-muol text-blue">ព្រះរាជាណាចក្រកម្ពុជា</h3>
                  <h4 class="font-muol text-blue">ជាតិ សាសនា ព្រះមហាក្សត្រ</h4>
                  <div class="wiggle-line">
                    <svg viewBox="0 0 100 10" preserveAspectRatio="none"><path d="M0,5 Q25,0 50,5 T100,5" fill="none" stroke="currentColor" stroke-width="2"/></svg>
                  </div>
                </div>
              </div>

              <!-- Main Title -->
              <div class="title-section">
                <h1 class="cert-main-title">ប័ណ្ណសរសើរ</h1>
                <h3 class="font-muol text-blue" style="font-size: 16px;">នាយកសាលាបឋមសិក្សា {{ auth.school?.name }}</h3>
              </div>

              <!-- Body Text -->
              <div class="cert-body-text">
                <p>សូមធ្វើការសរសើរចំពោះសិស្សឈ្មោះ <span class="highlight-red font-muol">{{ student.full_name }}</span> ភេទ <span class="highlight-red">{{ genderLabel(student.gender) }}</span></p>
                <p>ជាសិស្សថ្នាក់ទី <span class="highlight-red">{{ toKhmerNum(classInfo.class_name) }}</span> នៃឆ្នាំសិក្សា <span class="highlight-red">{{ toKhmerNum(classInfo.academic_years?.year_name) }}</span></p>
                <p>ដែលទទួលបានលទ្ធផលល្អក្នុងសិក្សា និងទទួលបានចំណាត់ថ្នាក់លេខ <span class="highlight-red font-muol">{{ toKhmerNum(student.rank) }}</span> {{ contextName }}</p>
                <p class="cert-closing-text">ប័ណ្ណសរសើរនេះប្រគល់ជូនសាមីខ្លួនប្រើប្រាស់តាមការដែលអាចប្រើប្រាស់បាន។</p>
              </div>

              <!-- Footer Section -->
              <div class="cert-footer">
                <div class="footer-col">
                  <p class="footer-date">ថ្ងៃទី ........ ខែ ........ ឆ្នាំ២០........</p>
                  <p class="font-muol">នាយកសាលា</p>
                  <div class="signature-space"></div>
                </div>
                
                <!-- Red Stamp Box -->
                <div class="stamp-box"></div>

                <div class="footer-col">
                  <p class="footer-date">ថ្ងៃទី ........ ខែ ........ ឆ្នាំ២០........</p>
                  <p class="font-muol">គ្រូបន្ទុកថ្នាក់</p>
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

.border-preview-img {
  width: 60px;
  height: 40px;
  border-radius: 4px;
  object-fit: cover;
  border: 1px solid #cbd5e1;
}

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
  padding: 80px 100px;
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

.font-muol {
  font-family: 'Khmer OS Muol Light', 'Hanuman', serif;
  font-weight: normal;
}

.text-blue { color: #1a3b8e; }
.highlight-red { color: #d92b34; font-weight: 700; }

.cert-header {
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 30px;
}

.header-left {
  display: flex;
  gap: 12px;
  text-align: left;
  margin-top: 30px;
  margin-right: 20px;
}

.moey-logo-small img {
  width: 100px;
  height: auto;
}
.header-text-left p {
  font-size: 13px;
  margin-bottom: 2px;
  color: #1e293b;
}

.header-right {
  text-align: center;
    margin-top: 30px;
  margin-left: 20px;
}

.header-right h3 { font-size: 18px; margin-bottom: 4px; }
.header-right h4 { font-size: 14px; }

.wiggle-line {
  width: 80px;
  margin: 4px auto 0;
  color: #1a3b8e;
}

.title-section {
  text-align: center;
  margin-bottom: 30px;
}

.cert-main-title {
  font-family: 'Khmer OS Muol Light', 'Hanuman', serif;
  font-size: 64px;
  color: #d92b34;
  margin-bottom: 10px;
  text-shadow: 1px 1px 1px rgba(0,0,0,0.1);
}

.cert-body-text {
  text-align: center;
  font-size: 20px;
  line-height: 2;
  color: #1e293b;
  width: 100%;
  max-width: 850px;
}

.cert-closing-text {
  margin-top: 20px;
  font-style: italic;
  font-size: 16px;
}

.cert-footer {
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-top: auto;
  padding: 0 40px 20px;
}

.footer-col {
  text-align: center;
  flex: 1;
}

.footer-date {
  font-size: 13px;
  color: #475569;
  margin-bottom: 8px;
}

.stamp-box {
  width: 100px;
  height: 120px;
  border: 2px solid #d92b34;
  margin: 0 40px 20px;
  flex-shrink: 0;
}

.signature-space { height: 80px; }

@media (max-width: 1300px) {
  .design-layout { grid-template-columns: 1fr; }
  .toolbar { position: static; }
  .certificate-container { transform: scale(0.6); transform-origin: top center; margin-bottom: -150px; }
}
</style>
