<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import jsPDF from 'jspdf'
import 'jspdf-autotable'
import { AcademicCapIcon, CheckCircleIcon, BookOpenIcon, StarIcon, DocumentTextIcon } from '@heroicons/vue/24/outline'

const stats = ref({
  students: 0,
  teachers: 0,
  avgAttendance: 0,
  avgScore: 0,
  booksBorrowed: 0
})
const loading = ref(true)

onMounted(async () => {
  await loadStats()
})

async function loadStats() {
  loading.value = true
  
  // Basic counts
  const { count: studentCount } = await supabase.from('students').select('*', { count: 'exact', head: true })
  const { count: teacherCount } = await supabase.from('teachers').select('*', { count: 'exact', head: true })
  
  // Attendance avg
  const { data: attData } = await supabase.from('attendances').select('status')
  if (attData && attData.length > 0) {
    const present = attData.filter(a => a.status === 'present').length
    stats.value.avgAttendance = Math.round((present / attData.length) * 100)
  }

  // Score avg
  const { data: scoreData } = await supabase.from('scores').select('score')
  if (scoreData && scoreData.length > 0) {
    const total = scoreData.reduce((acc, s) => acc + s.score, 0)
    stats.value.avgScore = Math.round(total / scoreData.length)
  }

  // Books borrowed
  const { count: borrowCount } = await supabase.from('book_borrows').select('*', { count: 'exact', head: true })
  
  stats.value.students = studentCount || 0
  stats.value.teachers = teacherCount || 0
  stats.value.booksBorrowed = borrowCount || 0
  
  loading.value = false
}

function exportPDF(title, type) {
  const doc = jsPDF()
  doc.setFontSize(20)
  doc.text('សាលាបឋមសិក្សា Sunrise', 105, 20, { align: 'center' })
  doc.setFontSize(14)
  doc.text(title, 105, 30, { align: 'center' })
  doc.setFontSize(10)
  doc.text(`បង្កើតនៅ៖ ${formatDate(new Date())}`, 105, 36, { align: 'center' })
  
  doc.setFontSize(12)
  doc.text(`នេះជារបាយការណ៍សង្ខេបសម្រាប់ ${type}។`, 20, 50)
  doc.text(`សិស្សសរុប៖ ${stats.value.students} នាក់`, 20, 60)
  doc.text(`អត្រាវត្តមាន៖ ${stats.value.avgAttendance}%`, 20, 70)
  doc.text(`ពិន្ទុជាមធ្យម៖ ${stats.value.avgScore}/100`, 20, 80)
  
  doc.save(`${type.toLowerCase()}_report_${Date.now()}.pdf`)
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">មជ្ឈមណ្ឌលរបាយការណ៍</h1>
        <p class="page-subtitle">បង្កើតនិងទាញយករបាយការណ៍សង្ខេបនៃសាលា</p>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div v-for="i in 4" :key="i" class="skeleton" style="height:60px;margin-bottom:20px;border-radius:12px;"></div>
    </div>

    <div v-else>
      <!-- Quick Stats Grid -->
      <div class="grid-cols-4" style="margin-bottom:24px;">
        <div class="stat-card">
          <div class="stat-icon" style="background:#e0f2fe;color:#0ea5e9;"><AcademicCapIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">ចំនួនសិស្សសរុប</div>
            <div class="stat-value">{{ stats.students }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#f0fdf4;color:#22c55e;"><CheckCircleIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">អត្រាវត្តមាន</div>
            <div class="stat-value">{{ stats.avgAttendance }}%</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#fefce8;color:#eab308;"><StarIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">ពិន្ទុជាមធ្យម</div>
            <div class="stat-value">{{ stats.avgScore }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#faf5ff;color:#a855f7;"><BookOpenIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">សៀវភៅកំពុងខ្ចី</div>
            <div class="stat-value">{{ stats.booksBorrowed }}</div>
          </div>
        </div>
      </div>

      <!-- Report Generator Sections -->
      <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(300px, 1fr));gap:20px;">
        
        <!-- Attendance Report -->
        <div class="card">
          <div class="card-header"><span class="card-title">របាយការណ៍វត្តមាន</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              បង្កើតរបាយការណ៍វត្តមានតាមថ្នាក់ ឬតាមខែ។
            </p>
            <div style="display:flex;flex-direction:column;gap:8px;">
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('របាយការណ៍វត្តមានប្រចាំខែ', 'វត្តមាន')">
                <DocumentTextIcon class="w-4 h-4" /> របាយការណ៍ប្រចាំខែ (PDF)
              </button>
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('ចំណាត់ថ្នាក់វត្តមានតាមថ្នាក់', 'វត្តមាន')">
                <DocumentTextIcon class="w-4 h-4" /> ចំណាត់ថ្នាក់តាមថ្នាក់ (PDF)
              </button>
            </div>
          </div>
        </div>

        <!-- Academic Report -->
        <div class="card">
          <div class="card-header"><span class="card-title">របាយការណ៍សិក្សា</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              វិភាគលទ្ធផលសិក្សារបស់សិស្សតាមមុខវិជ្ជា និងថ្នាក់។
            </p>
            <div style="display:flex;flex-direction:column;gap:8px;">
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('របាយការណ៍ចែកពិន្ទុ', 'សិក្សា')">
                <DocumentTextIcon class="w-4 h-4" /> ចែកចាយពិន្ទុ (PDF)
              </button>
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('វិភាគលទ្ធផលតាមមុខវិជ្ជា', 'សិក្សា')">
                <DocumentTextIcon class="w-4 h-4" /> វិភាគតាមមុខវិជ្ជា (PDF)
              </button>
            </div>
          </div>
        </div>

        <!-- Financial Report -->
        <div class="card">
          <div class="card-header"><span class="card-title">របាយការណ៍ហិរញ្ញវត្ថុ</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              ពិនិត្យថវិកា ចំណូល និងចំណាយរបស់សាលា។
            </p>
            <div style="display:flex;flex-direction:column;gap:8px;">
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('របាយការណ៍ថវិកាប្រចាំត្រីមាស', 'ហិរញ្ញវត្ថុ')">
                <DocumentTextIcon class="w-4 h-4" /> របាយការណ៍ត្រីមាស (PDF)
              </button>
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('ការបែងចែកចំណាយ', 'ហិរញ្ញវត្ថុ')">
                <DocumentTextIcon class="w-4 h-4" /> ការបែងចែកចំណាយ (PDF)
              </button>
            </div>
          </div>
        </div>

        <!-- Inventory Report -->
        <div class="card">
          <div class="card-header"><span class="card-title">របាយការណ៍សារពើភណ្ឌ</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              តាមដានទ្រព្យសម្បត្តិ និងស្តុកសៀវភៅរបស់សាលា។
            </p>
            <div style="display:flex;flex-direction:column;gap:8px;">
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('របាយការណ៍ស្តុកទាប', 'សារពើភណ្ឌ')">
                <DocumentTextIcon class="w-4 h-4" /> ស្តុកទាប (PDF)
              </button>
              <button class="btn btn-ghost" style="justify-content:flex-start;" 
                      @click="exportPDF('បញ្ជីទ្រព្យសម្បត្តិទាំងអស់', 'សារពើភណ្ឌ')">
                <DocumentTextIcon class="w-4 h-4" /> បញ្ជីទ្រព្យសម្បត្តិ (PDF)
              </button>
            </div>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>