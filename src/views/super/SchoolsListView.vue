<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { 
  School, 
  Search, 
  Plus, 
  MoreVertical, 
  Eye, 
  Edit2, 
  Trash2,
  Filter,
  ChevronLeft,
  ChevronRight,
  ExternalLink
} from 'lucide-vue-next'

const schools = ref([])
const loading = ref(true)
const searchQuery = ref('')
const filterStatus = ref('all')

async function fetchSchools() {
  try {
    loading.value = true
    let query = supabase.from('schools').select('*')
    
    if (filterStatus.value !== 'all') {
      query = query.eq('status', filterStatus.value)
    }
    
    if (searchQuery.value) {
      query = query.ilike('name_khmer', `%${searchQuery.value}%`)
    }
    
    const { data, error } = await query.order('name_khmer')
    if (error) throw error
    schools.value = data || []
  } catch (e) {
    console.error('SchoolsListView: Error fetching schools:', e)
  } finally {
    loading.value = false
  }
}

async function toggleSchoolStatus(school) {
  const newStatus = school.status === 'active' ? 'inactive' : 'active'
  try {
    const { error } = await supabase
      .from('schools')
      .update({ status: newStatus })
      .eq('id', school.id)
    
    if (error) throw error
    school.status = newStatus
  } catch (e) {
    console.error('SchoolsListView: Error updating status:', e)
  }
}

onMounted(() => {
  fetchSchools()
})
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-6">
      <div>
        <h1 class="text-3xl font-black text-slate-900 tracking-tight">បញ្ជីសាលារៀន</h1>
        <p class="text-slate-500 font-medium">គ្រប់គ្រង និងតាមដានសកម្មភាពសាលារៀនទាំងអស់ក្នុងប្រព័ន្ធ</p>
      </div>
      <router-link 
        to="/super/schools/new"
        class="bg-indigo-600 text-white px-6 py-3 rounded-2xl font-bold flex items-center justify-center gap-2 hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-200"
      >
        <Plus class="w-5 h-5" />
        ចុះឈ្មោះសាលារៀនថ្មី
      </router-link>
    </div>

    <!-- Filters & Search -->
    <div class="bg-white p-4 rounded-3xl border border-slate-200 shadow-sm flex flex-col md:flex-row gap-4 items-center">
      <div class="relative flex-1 w-full">
        <Search class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
        <input 
          v-model="searchQuery"
          @input="fetchSchools"
          type="text" 
          placeholder="ស្វែងរកឈ្មោះសាលារៀន..." 
          class="w-full pl-12 pr-4 py-3 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium text-slate-900"
        />
      </div>
      <div class="flex items-center gap-3 w-full md:w-auto">
        <div class="relative flex-1 md:w-48">
          <Filter class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <select 
            v-model="filterStatus"
            @change="fetchSchools"
            class="w-full pl-10 pr-10 py-3 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-bold text-slate-700 appearance-none text-sm"
          >
            <option value="all">ស្ថានភាពទាំងអស់</option>
            <option value="active">សកម្ម</option>
            <option value="inactive">មិនសកម្ម</option>
          </select>
        </div>
      </div>
    </div>

    <!-- School Grid -->
    <div v-if="loading" class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="i in 6" :key="i" class="h-64 bg-slate-100 rounded-[2rem] animate-pulse"></div>
    </div>

    <div v-else-if="schools.length > 0" class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div 
        v-for="school in schools" 
        :key="school.id"
        class="bg-white rounded-[2rem] border border-slate-200 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all group overflow-hidden"
      >
        <div class="p-8">
          <div class="flex items-start justify-between mb-6">
            <div class="w-16 h-16 rounded-2xl bg-indigo-50 flex items-center justify-center text-indigo-600">
              <School v-if="!school.logo_url" class="w-8 h-8" />
              <img v-else :src="school.logo_url" class="w-full h-full object-cover rounded-2xl" />
            </div>
            <div class="flex items-center gap-2">
              <span 
                :class="[
                  school.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700',
                  'px-3 py-1 rounded-full text-[10px] font-black uppercase'
                ]"
              >
                {{ school.status }}
              </span>
              <button class="p-2 hover:bg-slate-100 rounded-lg transition-colors text-slate-400">
                <MoreVertical class="w-5 h-5" />
              </button>
            </div>
          </div>

          <h3 class="text-xl font-black text-slate-900 mb-2 line-clamp-1">{{ school.name_khmer }}</h3>
          <p class="text-sm font-bold text-slate-500 mb-6 font-mono tracking-wider">{{ school.school_code }}</p>

          <div class="space-y-3 mb-8">
            <div class="flex items-center gap-3 text-sm text-slate-600 font-medium">
              <div class="w-1.5 h-1.5 rounded-full bg-slate-300"></div>
              <span>{{ school.province }}, {{ school.district }}</span>
            </div>
            <div class="flex items-center gap-3 text-sm text-slate-600 font-medium">
              <div class="w-1.5 h-1.5 rounded-full bg-slate-300"></div>
              <span>បង្កើតនៅ: {{ new Date(school.created_at).toLocaleDateString('km-KH') }}</span>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3 pt-6 border-t border-slate-100">
            <button 
              @click="toggleSchoolStatus(school)"
              class="flex items-center justify-center gap-2 text-sm font-bold py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 transition-all"
              :class="school.status === 'active' ? 'text-rose-600 hover:border-rose-200' : 'text-emerald-600 hover:border-emerald-200'"
            >
              {{ school.status === 'active' ? 'បិទសកម្មភាព' : 'បើកសកម្មភាព' }}
            </button>
            <router-link 
              :to="`/super/schools/${school.id}`"
              class="flex items-center justify-center gap-2 text-sm font-bold py-2.5 rounded-xl bg-slate-900 text-white hover:bg-slate-800 transition-all"
            >
              <Eye class="w-4 h-4" />
              មើលលម្អិត
            </router-link>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="bg-white rounded-[3rem] py-24 border-2 border-dashed border-slate-200 flex flex-col items-center justify-center text-center px-6">
      <div class="bg-slate-50 w-24 h-24 rounded-full flex items-center justify-center mb-6">
        <School class="w-10 h-10 text-slate-300" />
      </div>
      <h3 class="text-2xl font-black text-slate-900 mb-2">មិនមានសាលារៀន</h3>
      <p class="text-slate-500 font-medium mb-8 max-w-sm">មិនមានសាលារៀនដែលត្រូវនឹងការស្វែងរករបស់អ្នកឡើយ។ សូមព្យាយាមម្តងទៀត ឬចុះឈ្មោះសាលារៀនថ្មី។</p>
      <button 
        @click="searchQuery = ''; filterStatus = 'all'; fetchSchools()"
        class="text-indigo-600 font-bold hover:underline"
      >
        លុបការស្វែងរក
      </button>
    </div>
  </div>
</template>
