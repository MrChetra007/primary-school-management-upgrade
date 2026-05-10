<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { 
  School, 
  Users, 
  GraduationCap, 
  TrendingUp,
  Activity,
  CalendarDays,
  ChevronRight
} from 'lucide-vue-next'

const router = useRouter()

const stats = ref([
  { name: 'សាលារៀនសរុប', value: '0', icon: School, color: 'text-blue-600', bg: 'bg-blue-50' },
  { name: 'សិស្សសរុប', value: '0', icon: GraduationCap, color: 'text-indigo-600', bg: 'bg-indigo-50' },
  { name: 'គ្រូបង្រៀនសរុប', value: '0', icon: Users, color: 'text-emerald-600', bg: 'bg-emerald-50' },
  { name: 'សាលាសកម្ម', value: '0', icon: Activity, color: 'text-rose-600', bg: 'bg-rose-50' },
])

const recentSchools = ref([])
const loading = ref(true)

async function fetchStats() {
  try {
    loading.value = true
    
    // Total Schools
    const { count: schoolCount } = await supabase.from('schools').select('*', { count: 'exact', head: true })
    stats.value[0].value = schoolCount?.toString() || '0'
    
    // Total Students
    const { count: studentCount } = await supabase.from('students').select('*', { count: 'exact', head: true })
    stats.value[1].value = studentCount?.toString() || '0'
    
    // Total Teachers
    const { count: teacherCount } = await supabase.from('teachers').select('*', { count: 'exact', head: true })
    stats.value[2].value = teacherCount?.toString() || '0'
    
    // Active Schools
    const { count: activeCount } = await supabase.from('schools').select('*', { count: 'exact', head: true }).eq('status', 'active')
    stats.value[3].value = activeCount?.toString() || '0'

    // Recent Schools
    const { data: schools } = await supabase
      .from('schools')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5)
    
    recentSchools.value = schools || []
    
  } catch (e) {
    console.error('SuperDashboard: Error fetching stats:', e)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchStats()
})
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-3xl font-black text-slate-900 tracking-tight">ផ្ទាំងគ្រប់គ្រងប្រព័ន្ធ</h1>
        <p class="text-slate-500 font-medium">ទិដ្ឋភាពទូទៅនៃសាលារៀន និងអ្នកប្រើប្រាស់ទូទាំងប្រទេស</p>
      </div>
      <div class="flex items-center gap-2 bg-white px-4 py-2 rounded-xl border border-slate-200 shadow-sm">
        <CalendarDays class="w-5 h-5 text-slate-400" />
        <span class="text-sm font-bold text-slate-700">{{ new Date().toLocaleDateString('km-KH', { dateStyle: 'long' }) }}</span>
      </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <div 
        v-for="s in stats" 
        :key="s.name"
        class="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm flex items-center gap-5 hover:shadow-md transition-all group"
      >
        <div :class="[s.bg, s.color, 'w-14 h-14 rounded-2xl flex items-center justify-center transition-transform group-hover:scale-110']">
          <component :is="s.icon" class="w-7 h-7" />
        </div>
        <div>
          <p class="text-sm font-bold text-slate-500 mb-1">{{ s.name }}</p>
          <div class="flex items-baseline gap-2">
            <h3 class="text-2xl font-black text-slate-900">{{ s.value }}</h3>
            <span class="text-[10px] font-bold text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded flex items-center gap-0.5">
              <TrendingUp class="w-2.5 h-2.5" />
              +0%
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="grid lg:grid-cols-3 gap-8">
      <!-- Recent Schools -->
      <div class="lg:col-span-2 bg-white rounded-[2rem] border border-slate-200 shadow-sm overflow-hidden">
        <div class="p-6 border-b border-slate-100 flex items-center justify-between">
          <h2 class="text-lg font-black text-slate-900">សាលារៀនដែលបានចុះឈ្មោះថ្មីៗ</h2>
          <router-link to="/super/schools" class="text-sm font-bold text-indigo-600 hover:text-indigo-700">មើលទាំងអស់</router-link>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-slate-50 border-b border-slate-100">
              <tr>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">សាលារៀន</th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">លេខកូដ</th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ខេត្ត/ក្រុង</th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ស្ថានភាព</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr v-for="school in recentSchools" :key="school.id" class="hover:bg-slate-50 transition-colors">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center font-bold text-slate-600">
                      {{ school.name_khmer[0] }}
                    </div>
                    <div class="text-sm font-bold text-slate-900">{{ school.name_khmer }}</div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-mono font-bold text-slate-600">{{ school.school_code }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600 font-medium">{{ school.province }}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span 
                    :class="[
                      school.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700',
                      'px-3 py-1 rounded-full text-xs font-bold capitalize'
                    ]"
                  >
                    {{ school.status }}
                  </span>
                </td>
              </tr>
              <tr v-if="recentSchools.length === 0">
                <td colspan="4" class="px-6 py-12 text-center text-slate-400 font-medium">មិនទាន់មានសាលារៀននៅឡើយទេ</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Quick Actions / Announcements -->
      <div class="space-y-6">
        <div class="bg-indigo-600 rounded-[2rem] p-8 text-white shadow-xl shadow-indigo-200">
          <h3 class="text-xl font-bold mb-4">សកម្មភាពរហ័ស</h3>
          <div class="grid gap-3">
            <button 
              @click="router.push('/super/schools/new')"
              class="flex items-center justify-between bg-white/10 hover:bg-white/20 p-4 rounded-2xl transition-all border border-white/10"
            >
              <div class="flex items-center gap-3">
                <div class="bg-white/20 p-2 rounded-xl">
                  <School class="w-5 h-5 text-white" />
                </div>
                <span class="font-bold">ចុះឈ្មោះសាលារៀនថ្មី</span>
              </div>
              <ChevronRight class="w-5 h-5" />
            </button>
            <button class="flex items-center justify-between bg-white/10 hover:bg-white/20 p-4 rounded-2xl transition-all border border-white/10">
              <div class="flex items-center gap-3">
                <div class="bg-white/20 p-2 rounded-xl">
                  <Users class="w-5 h-5 text-white" />
                </div>
                <span class="font-bold">គ្រប់គ្រងអ្នកប្រើប្រាស់</span>
              </div>
              <ChevronRight class="w-5 h-5" />
            </button>
          </div>
        </div>

        <div class="bg-white rounded-[2rem] p-8 border border-slate-200 shadow-sm">
          <h3 class="text-lg font-black text-slate-900 mb-6 flex items-center gap-2">
            <TrendingUp class="w-5 h-5 text-indigo-600" />
            ដំណឹងប្រព័ន្ធ
          </h3>
          <div class="space-y-6">
            <div v-for="i in 2" :key="i" class="flex gap-4 group cursor-pointer">
              <div class="w-12 h-12 rounded-2xl bg-slate-50 flex items-center justify-center font-bold text-slate-400 group-hover:bg-indigo-50 group-hover:text-indigo-600 transition-all">
                v8
              </div>
              <div>
                <p class="text-sm font-bold text-slate-900 mb-1 group-hover:text-indigo-600 transition-all">ការធ្វើបច្ចុប្បន្នភាព v8.0.0</p>
                <p class="text-xs text-slate-500 leading-relaxed line-clamp-2">ដាក់ឱ្យដំណើរការប្រព័ន្ធ Multi-tenant សម្រាប់គ្រប់គ្រងសាលារៀនច្រើនក្នុងពេលតែមួយ។</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
