<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { CheckIcon, ExclamationCircleIcon, ClockIcon, DocumentTextIcon, SunIcon, MoonIcon, BuildingOfficeIcon, UserGroupIcon, CheckCircleIcon, CalendarIcon, PencilSquareIcon, ChartBarIcon, AcademicCapIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const classInfo = ref(null)
const studentsCount = ref(0)
const attendanceToday = ref({ present: 0, total: 0 })
const recentScores = ref([])
const loading = ref(true)

const myAttendanceToday = ref(null)
const checkingIn = ref(false)

onMounted(async () => {
  if (auth.teacherProfile) {
    await Promise.all([loadData(), loadCheckInStatus()])
  } else {
    setTimeout(async () => {
      if (auth.teacherProfile) await Promise.all([loadData(), loadCheckInStatus()])
      else loading.value = false
    }, 1000)
  }
})

async function loadCheckInStatus() {
  if (!auth.teacherProfile) return
  const teacherId = auth.teacherProfile.id
  const today = new Date().toISOString().split('T')[0]
  const { data } = await supabase
    .from('teacher_attendances')
    .select('*')
    .eq('teacher_id', teacherId)
    .eq('date', today)
    .maybeSingle()
  myAttendanceToday.value = data
}

async function handleCheckIn() {
  checkingIn.value = true
  const { data, error } = await supabase.rpc('teacher_check_in')
  checkingIn.value = false
  if (error) {
    alert(error.message)
  } else {
    myAttendanceToday.value = data
  }
}

async function loadData() {
  loading.value = true
  const teacherId = auth.teacherProfile.id

  // 1. Get Class Info
  const { data: classData } = await supabase
    .from('classes')
    .select('*, academic_years!inner(year_name, status)')
    .eq('teacher_id', teacherId)
    .eq('academic_years.status', 'active')
    .maybeSingle()

  if (classData) {
    classInfo.value = classData

    // 2. Get Students (reuse for count + attendance)
    const { data: studentData } = await supabase
      .from('students')
      .select('id')
      .eq('class_id', classData.id)

    const ids = studentData?.map(s => s.id) || []
    studentsCount.value = ids.length

    // 3. Attendance Today — filter by student_id, attendances has no class_id
    const today = new Date().toISOString().split('T')[0]
    if (ids.length > 0) {
      const { data: attData, error: attError } = await supabase
        .from('attendances')
        .select('status, student_id')
        .eq('date', today)
        .in('student_id', ids)

      if (attError) {
        console.error('Attendance error:', attError)
      } else {
        attendanceToday.value.total = ids.length
        attendanceToday.value.present = attData?.filter(a => a.status === 'present').length ?? 0
      }
    } else {
      attendanceToday.value.total = 0
      attendanceToday.value.present = 0
    }

    // 4. Recent Scores
    const { data: scoreData, error: scoreError } = await supabase
      .from('scores')
      .select('*, students!inner(full_name, class_id), subjects(subject_name)')
      .eq('students.class_id', classData.id)
      .order('created_at', { ascending: false })
      .limit(5)

    if (scoreError) {
      console.error('Scores error:', scoreError)
    } else {
      recentScores.value = scoreData || []
    }
  }

  loading.value = false
}

const attendancePercent = computed(() => {
  if (attendanceToday.value.total === 0) return 0
  return Math.round((attendanceToday.value.present / attendanceToday.value.total) * 100)
})
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">ផ្ទាំងគ្រប់គ្រងគ្រូ</h1>
        <p class="page-subtitle" v-if="classInfo">
          សូមស្វាគមន៍មកវិញ! កំពុងគ្រប់គ្រងថ្នាក់ <strong>{{ classInfo.class_name }}</strong> ({{ classInfo.academic_years?.year_name }})
        </p>
        <p class="page-subtitle" v-else>សូមស្វាគមន៍មកវិញ! អ្នកមិនទាន់ត្រូវបានចាត់តាំងថ្នាក់ណាមួយនៅឡើយ។</p>
      </div>
      <div style="display:flex; gap:10px; align-items:center;">
        <!-- Check-in Status -->
        <div v-if="myAttendanceToday" class="badge" :class="myAttendanceToday.status === 'present' ? 'badge-green' : 'badge-yellow'"
             style="padding:10px 16px; flex-direction:column; align-items:flex-start; gap:2px; height:auto;">
          <div style="font-weight:700;">
            <template v-if="myAttendanceToday.status === 'present'">
              <CheckIcon class="w-4 h-4" /> មានវត្តមាន
            </template>
            <template v-else>
              <ExclamationCircleIcon class="w-4 h-4" /> យឺត
            </template>
          </div>
          <div style="font-size:11px; opacity:0.8;">
            <ClockIcon class="w-3 h-3" /> {{ new Date(myAttendanceToday.check_in_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }}
            <span v-if="myAttendanceToday.note" title="កំណត់ចំណាំ"> <DocumentTextIcon class="w-3 h-3" /></span>
          </div>
        </div>

        <!-- Check-in Button -->
        <button v-else class="btn btn-primary" style="padding:10px 24px; font-weight:bold; box-shadow: 0 4px 12px rgba(var(--primary-rgb), 0.3);"
                @click="handleCheckIn" :disabled="checkingIn">
          {{ checkingIn ? 'កំពុងបញ្ចូល...' : 'ចូលធ្វើការ (Check-in)' }}
        </button>

        <div v-if="classInfo" class="badge badge-blue" style="padding:10px 16px;">
          <template v-if="classInfo.turn === 'morning'">
            <SunIcon class="w-4 h-4" /> វេនព្រឹក
          </template>
          <template v-else>
            <MoonIcon class="w-4 h-4" /> វេនល្ងាច
          </template>
        </div>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:100px; margin-bottom:20px;"></div>
      <div class="grid-cols-3" style="gap:20px;">
        <div class="skeleton" style="height:120px;"></div>
        <div class="skeleton" style="height:120px;"></div>
        <div class="skeleton" style="height:120px;"></div>
      </div>
    </div>

    <div v-else-if="!classInfo" class="empty-state">
      <BuildingOfficeIcon class="w-12 h-12 text-gray-400" />
      <p class="empty-state-title">មិនទាន់មានថ្នាក់ត្រូវបានចាត់តាំង</p>
      <p class="empty-state-desc">សូមទាក់ទងអ្នកគ្រប់គ្រងដើម្បីចាត់តាំងអ្នកទៅថ្នាក់។</p>
    </div>

    <div v-else>
      <!-- Stats Grid -->
      <div class="grid-cols-3" style="margin-bottom:24px;">
        <div class="stat-card">
          <div class="stat-icon" style="background:#e0f2fe;color:#0ea5e9;"><UserGroupIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">សិស្សរបស់ខ្ញុំ</div>
            <div class="stat-value">{{ studentsCount }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#f0fdf4;color:#22c55e;"><CheckCircleIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">វត្តមានថ្ងៃនេះ</div>
            <div class="stat-value">{{ attendancePercent }}%</div>
            <div class="stat-desc">{{ attendanceToday.present }} / {{ attendanceToday.total }} នាក់ មានវត្តមាន</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#fff7ed;color:#f97316;"><CalendarIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">ថ្ងៃនេះ</div>
            <div class="stat-value" style="font-size:18px;">{{ formatDate(new Date()) }}</div>
          </div>
        </div>
      </div>

      <div style="display:flex;flex-direction:column; gap:20px;">
        <!-- Recent Scores -->
        <div class="card">
          <div class="card-header">
            <span class="card-title">ពិន្ទុថ្មីៗ</span>
            <router-link to="/teacher/scores" class="btn btn-ghost btn-sm">មើលទាំងអស់</router-link>
          </div>
          <div class="card-body">
            <div v-if="recentScores.length === 0" class="empty-state" style="padding:40px;">
              <p style="color:var(--text-muted);">មិនទាន់មានពិន្ទុត្រូវបានបញ្ចូលនៅឡើយទេ។</p>
            </div>
            <div v-else class="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>សិស្ស</th>
                    <th>មុខវិជ្ជា</th>
                    <th>ប្រភេទ</th>
                    <th>ពិន្ទុ</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="s in recentScores" :key="s.id">
                    <td style="font-weight:600;">{{ s.students?.full_name }}</td>
                    <td>{{ s.subjects?.subject_name }}</td>
                    <td><span class="badge badge-gray">{{ s.score_type === 'monthly' ? 'ប្រចាំខែ' : 'ឆមាស' }}</span></td>
                    <td><span class="badge" :class="s.score >= 50 ? 'badge-green' : 'badge-red'">{{ s.score }}</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="card">
          <div class="card-header">
            <span class="card-title">សកម្មភាពរហ័ស</span>
          </div>
          <div class="card-body" style="display:flex;flex-direction:column;gap:12px;">
            <button class="btn btn-primary w-full" @click="$router.push('/teacher/attendance')">
              <PencilSquareIcon class="w-4 h-4" /> កត់ត្រាវត្តមាន
            </button>
            <button class="btn btn-secondary w-full" @click="$router.push('/teacher/scores')">
              <ChartBarIcon class="w-4 h-4" /> បញ្ចូលពិន្ទុ
            </button>
            <button class="btn btn-ghost w-full" @click="$router.push('/teacher/students')">
              <AcademicCapIcon class="w-4 h-4" /> មើលបញ្ជីសិស្ស
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>