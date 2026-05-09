<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { ChartBarIcon, DocumentTextIcon, DocumentIcon, ChartBarSquareIcon } from '@heroicons/vue/24/outline'
import jsPDF from 'jspdf'
import 'jspdf-autotable'

const auth = useAuthStore()
const classInfo = ref(null)
const students = ref([])
const loading = ref(true)

onMounted(async () => {
  if (auth.teacherProfile) {
    await loadData()
  } else {
    setTimeout(async () => {
      if (auth.teacherProfile) await loadData()
      else loading.value = false
    }, 1000)
  }
})

async function loadData() {
  loading.value = true
  const teacherId = auth.teacherProfile.id

  const { data: classData } = await supabase
    .from('classes')
    .select('*, academic_years!inner(year_name, status)')
    .eq('teacher_id', teacherId)
    .eq('academic_years.status', 'active')
    .maybeSingle()
  
  if (classData) {
    classInfo.value = classData
    const { data: stuData } = await supabase
      .from('students')
      .select('id, full_name, real_id, gender')
      .eq('class_id', classData.id)
      .order('full_name')
    students.value = stuData || []
  }
  loading.value = false
}

function printClassList() {
  const doc = jsPDF()
  doc.setFontSize(18)
  doc.text(`${classInfo.value.class_name} - បញ្ជីសិស្ស`, 105, 20, { align: 'center' })
  doc.setFontSize(12)
  doc.text(`ឆ្នាំសិក្សា៖ ${classInfo.value.academic_years?.year_name}`, 105, 28, { align: 'center' })
  doc.text(`គ្រូបន្ទុក៖ ${auth.teacherProfile.full_name}`, 105, 34, { align: 'center' })
  
  const body = students.value.map((s, idx) => [idx + 1, s.real_id || '—', s.full_name, s.gender === 'Male' ? 'ប្រុស' : 'ស្រី'])
  
  doc.autoTable({
    startY: 45,
    head: [['ល.រ', 'លេខកូដ', 'ឈ្មោះសិស្ស', 'ភេទ']],
    body: body,
  })
  
  doc.save(`${classInfo.value.class_name}_បញ្ជីសិស្ស.pdf`)
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">របាយការណ៍ថ្នាក់</h1>
        <p class="page-subtitle" v-if="classInfo">
          បង្កើតរបាយការណ៍សម្រាប់ថ្នាក់ <strong>{{ classInfo.class_name }}</strong>
        </p>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:100px; margin-bottom:20px;"></div>
    </div>

    <div v-else-if="!classInfo" class="empty-state">
      <div class="empty-state-icon"><ChartBarIcon class="w-12 h-12 text-gray-400" /></div>
      <p class="empty-state-title">មិនទាន់មានថ្នាក់ត្រូវបានចាត់តាំង</p>
    </div>

    <div v-else>
      <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap:20px;">
        
        <!-- Student List -->
        <div class="card">
          <div class="card-header"><span class="card-title">បញ្ជីសិស្ស</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              ទាញយកបញ្ជីសិស្សផ្លូវការនៃថ្នាក់របស់អ្នក។
            </p>
            <button class="btn btn-ghost w-full" style="justify-content:flex-start;" @click="printClassList">
              <DocumentIcon class="w-4 h-4" /> ទាញយកបញ្ជីសិស្ស (PDF)
            </button>
          </div>
        </div>

        <!-- Attendance Summary -->
        <div class="card">
          <div class="card-header"><span class="card-title">សង្ខេបវត្តមាន</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              មើលនិន្នាការវត្តមានប្រចាំខែរបស់ថ្នាក់។
            </p>
            <button class="btn btn-ghost w-full" style="justify-content:flex-start;" disabled>
              <DocumentTextIcon class="w-4 h-4" /> របាយការណ៍វត្តមាន (មកដល់ឆាប់ៗនេះ)
            </button>
          </div>
        </div>

        <!-- Grade Distribution -->
        <div class="card">
          <div class="card-header"><span class="card-title">ការបែងចែងពិន្ទុ</span></div>
          <div class="card-body">
            <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;">
              វិភាគលទ្ធផលសិក្សាជាមធ្យមភាគរបស់សិស្ស។
            </p>
            <button class="btn btn-ghost w-full" style="justify-content:flex-start;" disabled>
              <ChartBarSquareIcon class="w-4 h-4" /> ច្បាប់ពិន្ទុ (មកដល់ឆាប់ៗនេះ)
            </button>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>