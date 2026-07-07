<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { genderLabel } from '@/utils/gender'

const route = useRoute()
const router = useRouter()
const reportLinkId = route.params.report_link_id

const loading = ref(true)
const link = ref(null)
const students = ref([])
const selectedStudent = ref('')

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

  const { data: studentData } = await supabase
    .from('students')
    .select('id, full_name, gender')
    .eq('class_id', linkData.class_id)
    .eq('is_graduated', false)
    .order('full_name')

  students.value = studentData || []
  loading.value = false
})

function contextLabel() {
  if (!link.value) return ''
  if (link.value.score_type === 'monthly') {
    const months = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ']
    return `ប្រចាំខែ${months[link.value.month - 1] || ''}`
  }
  return `ឆមាសទី${link.value.semester || 1}`
}

function goToReport() {
  if (!selectedStudent.value) return
  router.push(`/parent/report/${reportLinkId}/${selectedStudent.value}`)
}
</script>

<template>
  <div class="report-dropdown">
    <div class="card" style="max-width: 480px; margin: 60px auto;">
      <div class="card-body" style="padding: 32px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <div class="logo-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="28" height="28">
              <path d="M12 2L2 7l10 5 10-5-10-5z"/>
              <path d="M2 17l10 5 10-5"/>
              <path d="M2 12l10 5 10-5"/>
            </svg>
          </div>
          <h2 style="font-size: 20px; font-weight: 800; margin-bottom: 4px;">របាយការណ៍សិក្សា</h2>
          <p style="color: var(--text-secondary); font-size: 13px;">វិបផតថលមាតាបិតា</p>
        </div>

        <div v-if="loading" style="text-align: center; padding: 40px 0;">
          <div class="spinner"></div>
          <p style="margin-top: 12px; color: var(--text-secondary);">កំពុងផ្ទុក...</p>
        </div>

        <div v-else-if="!link" style="text-align: center; padding: 40px 0;">
          <p style="color: var(--danger-color); font-weight: 700;">តំណភ្ជាប់នេះមិនត្រឹមត្រូវទេ</p>
          <p style="color: var(--text-secondary); font-size: 13px; margin-top: 8px;">សូមទាក់ទងគ្រូបង្រៀនរបស់អ្នក</p>
        </div>

        <template v-else>
          <div style="background: var(--gray-50); border-radius: 12px; padding: 16px; margin-bottom: 24px;">
            <div style="font-size: 13px; color: var(--text-secondary); margin-bottom: 4px;">ថ្នាក់</div>
            <div style="font-size: 18px; font-weight: 800;">{{ link.classes?.class_name }}</div>
            <div style="font-size: 13px; color: var(--primary-500); font-weight: 600; margin-top: 4px;">
              {{ contextLabel() }}
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">ជ្រើសរើសកូនរបស់អ្នក</label>
            <select class="form-select" v-model="selectedStudent">
              <option value="" disabled>-- សូមជ្រើសរើស --</option>
              <option v-for="s in students" :key="s.id" :value="s.id">
                {{ s.full_name }} ({{ genderLabel(s.gender) }})
              </option>
            </select>
          </div>

          <button
            class="btn btn-primary"
            style="width: 100%; margin-top: 16px;"
            :disabled="!selectedStudent"
            @click="goToReport"
          >
            មើលរបាយការណ៍
          </button>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.report-dropdown {
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  background: var(--bg-app);
  padding: 20px;
}

.logo-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto 16px;
  background: linear-gradient(135deg, var(--primary-500), var(--primary-700));
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  box-shadow: 0 4px 12px rgba(74, 127, 165, 0.3);
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
</style>
