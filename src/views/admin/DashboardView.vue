<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useRouter } from 'vue-router'
import { useAcademicYearStore } from '@/stores/academicYear'
import { AcademicCapIcon, UserGroupIcon, BuildingOfficeIcon, BookOpenIcon, CurrencyDollarIcon, CheckCircleIcon, ClipboardDocumentListIcon, PlusIcon, PrinterIcon } from '@heroicons/vue/24/outline'

const router = useRouter()
const yearStore = useAcademicYearStore()

const stats = ref({ 
  students: 0, 
  teachers: 0, 
  classes: 0, 
  books: 0, 
  budget_income: 0, 
  budget_expense: 0 
})
const recentStudents = ref([])
const overdueBooks = ref([])
const loading = ref(true)

onMounted(async () => {
  if (!yearStore.selectedYearId) {
    router.push('/admin/academic-years')
    return
  }
  await Promise.all([loadStats(), loadRecentStudents(), loadOverdueBooks()])
  loading.value = false
})

async function loadStats() {
  const [s, t, c, b, inc, exp] = await Promise.all([
    supabase.from('students').select('id', { count: 'exact', head: true }).eq('academic_year_id', yearStore.selectedYearId),
    supabase.from('teachers').select('id', { count: 'exact', head: true }),
    supabase.from('classes').select('id', { count: 'exact', head: true }).eq('academic_year_id', yearStore.selectedYearId),
    supabase.from('books').select('id', { count: 'exact', head: true }),
    supabase.from('budget_transactions').select('amount').eq('type', 'income').eq('academic_year_id', yearStore.selectedYearId),
    supabase.from('budget_transactions').select('amount').eq('type', 'expense').eq('academic_year_id', yearStore.selectedYearId),
  ])

  stats.value.students = s.count ?? 0
  stats.value.teachers = t.count ?? 0
  stats.value.classes  = c.count ?? 0
  stats.value.books    = b.count ?? 0
  stats.value.budget_income  = (inc.data || []).reduce((a, r) => a + Number(r.amount), 0)
  stats.value.budget_expense = (exp.data || []).reduce((a, r) => a + Number(r.amount), 0)
}

async function loadRecentStudents() {
  const { data } = await supabase
    .from('students')
    .select('id, full_name, gender, created_at')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('created_at', { ascending: false })
    .limit(5)

  recentStudents.value = data || []
}

async function loadOverdueBooks() {
  const { data } = await supabase
    .from('book_borrows')
    .select('id, due_date, students!inner(full_name, academic_year_id), books(title)')
    .eq('status', 'overdue')
    .eq('students.academic_year_id', yearStore.selectedYearId)
    .limit(5)

  overdueBooks.value = data || []
}

// Format number with Khmer Riel
function fmt(n) {
  return Number(n).toLocaleString('en-US')
}

// Improved gender display (more robust)
function getGenderLabel(gender) {
  if (!gender) return '—'
  const g = gender.toString().trim().toLowerCase()
  if (g === 'male' || g === 'm') return 'ប្រុស'
  if (g === 'female' || g === 'f') return 'ស្រី'
  return '—'
}

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('en-GB')
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">ផ្ទាំងគ្រប់គ្រង</h1>
        <p class="page-subtitle">សូមស្វាគមន៍មកកាន់ប្រព័ន្ធគ្រប់គ្រង — នេះជាសកម្មភាពនានាដែលកំពុងកើតឡើងនៅថ្ងៃនេះ</p>
      </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid-cols-4" style="margin-bottom:24px;">
      <div class="stat-card">
        <div class="stat-icon" style="background:var(--primary-100);"><AcademicCapIcon class="w-6 h-6" /></div>
        <div class="stat-info">
          <div class="stat-label">សរុបសិស្ស</div>
          <div class="stat-value">{{ loading ? '—' : fmt(stats.students) }}</div>
          <div class="stat-sub">ដែលបានចុះឈ្មោះឆ្នាំនេះ</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:var(--bg-success);"><UserGroupIcon class="w-6 h-6" /></div>
        <div class="stat-info">
          <div class="stat-label">គ្រូបង្រៀន</div>
          <div class="stat-value">{{ loading ? '—' : fmt(stats.teachers) }}</div>
          <div class="stat-sub">បុគ្គលិកសកម្ម</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:var(--bg-purple);"><BuildingOfficeIcon class="w-6 h-6" /></div>
        <div class="stat-info">
          <div class="stat-label">ថ្នាក់រៀន</div>
          <div class="stat-value">{{ loading ? '—' : fmt(stats.classes) }}</div>
          <div class="stat-sub">ថ្នាក់រៀនសកម្ម</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:var(--bg-warning);"><BookOpenIcon class="w-6 h-6" /></div>
        <div class="stat-info">
          <div class="stat-label">សៀវភៅបណ្ណាល័យ</div>
          <div class="stat-value">{{ loading ? '—' : fmt(stats.books) }}</div>
          <div class="stat-sub">នៅក្នុងស្តុក</div>
        </div>
      </div>
    </div>

    <!-- Budget -->
    <div class="grid-cols-2" style="margin-bottom:24px;">
      <div class="stat-card">
        <div class="stat-icon" style="background:var(--bg-success);"><CurrencyDollarIcon class="w-6 h-6" /></div>
        <div class="stat-info">
          <div class="stat-label">ចំណូលសរុប</div>
          <div class="stat-value" style="color:var(--color-success);">{{ loading ? '—' : fmt(stats.budget_income) }} ៛</div>
          <div class="stat-sub">ប្រតិបត្តិការថវិកា</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:var(--bg-danger);">💸</div>
        <div class="stat-info">
          <div class="stat-label">ចំណាយសរុប</div>
          <div class="stat-value" style="color:var(--color-danger);">{{ loading ? '—' : fmt(stats.budget_expense) }} ៛</div>
          <div class="stat-sub">ប្រតិបត្តិការថវិកា</div>
        </div>
      </div>
    </div>

    <!-- Recent Students & Overdue Books -->
    <div class="grid-cols-2">
      <!-- Recent Students -->
      <div class="card">
        <div class="card-header">
          <span class="card-title">សិស្សទើបចុះឈ្មោះថ្មីៗ</span>
          <button class="btn btn-secondary btn-sm" @click="router.push('/admin/students')">មើលទាំងអស់</button>
        </div>
        <div v-if="loading" class="card-body">
          <div v-for="i in 4" :key="i" class="skeleton" style="height:36px;margin-bottom:10px;border-radius:8px;"></div>
        </div>
        <div v-else-if="recentStudents.length === 0" class="empty-state">
          <div class="empty-state-icon"><AcademicCapIcon class="w-12 h-12 text-gray-400" /></div>
          <p class="empty-state-title">មិនទាន់មានទិន្នន័យសិស្ស</p>
        </div>
        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>ឈ្មោះ</th>
                <th>ភេទ</th>
                <th>ថ្ងៃចុះឈ្មោះ</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="s in recentStudents" 
                :key="s.id" 
                style="cursor:pointer;" 
                @click="router.push('/admin/students/'+s.id)"
              >
                <td>
                  <div style="display:flex;align-items:center;gap:8px;">
                    <div class="avatar" style="width:28px;height:28px;font-size:11px;">
                      {{ s.full_name?.charAt(0) || '?' }}
                    </div>
                    {{ s.full_name }}
                  </div>
                </td>
                <td>
                  <span class="badge" 
                        :class="getGenderLabel(s.gender) === 'ប្រុស' ? 'badge-blue' : 'badge-red'">
                    {{ getGenderLabel(s.gender) }}
                  </span>
                </td>
                <td>{{ fmtDate(s.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Overdue Books -->
      <div class="card">
        <div class="card-header">
          <span class="card-title">សៀវភៅហួសកាលកំណត់</span>
          <button class="btn btn-secondary btn-sm" @click="router.push('/admin/library')">មើលទាំងអស់</button>
        </div>
        <div v-if="loading" class="card-body">
          <div v-for="i in 4" :key="i" class="skeleton" style="height:36px;margin-bottom:10px;border-radius:8px;"></div>
        </div>
        <div v-else-if="overdueBooks.length === 0" class="empty-state">
          <div class="empty-state-icon"><CheckCircleIcon class="w-12 h-12 text-gray-400" /></div>
          <p class="empty-state-title">គ្មានសៀវភៅហួសកាលកំណត់ទេ</p>
        </div>
        <div v-else class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>សៀវភៅ</th>
                <th>សិស្ស</th>
                <th>ត្រូវសង</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="b in overdueBooks" :key="b.id">
                <td>{{ b.books?.title }}</td>
                <td>{{ b.students?.full_name }}</td>
                <td><span class="badge badge-red">{{ fmtDate(b.due_date) }}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="card" style="margin-top:20px;">
      <div class="card-header">
        <span class="card-title">សកម្មភាពរហ័ស</span>
      </div>
      <div class="card-body" style="display:flex;gap:12px;flex-wrap:wrap;">
        <button class="btn btn-primary" @click="router.push('/admin/students')">
          <PlusIcon class="w-4 h-4" /> បន្ថែមសិស្ស
        </button>
        <button class="btn btn-secondary" @click="router.push('/admin/teachers')">
          <PlusIcon class="w-4 h-4" /> បន្ថែមគ្រូបង្រៀន
        </button>
        <button class="btn btn-secondary" @click="router.push('/admin/attendance/students')">
          <ClipboardDocumentListIcon class="w-4 h-4" /> ពិនិត្យវត្តមាន
        </button>
        <button class="btn btn-secondary" @click="router.push('/admin/budget')">
          <CurrencyDollarIcon class="w-4 h-4" /> បន្ថែមប្រតិបត្តិការ
        </button>
        <button class="btn btn-secondary" @click="router.push('/admin/reports')">
          <PrinterIcon class="w-4 h-4" /> បោះពុម្ពរបាយការណ៍
        </button>
      </div>
    </div>
  </div>
</template>