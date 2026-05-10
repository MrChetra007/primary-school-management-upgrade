<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { 
  School, 
  User, 
  Shield, 
  ArrowLeft, 
  ArrowRight, 
  Check, 
  Loader2,
  Lock,
  Mail,
  MapPin,
  Smartphone
} from 'lucide-vue-next'

const router = useRouter()
const step = ref(1)
const loading = ref(false)
const error = ref('')

// Holds the school ID after step 1 completes — prevents re-creating on retry
const createdSchoolId = ref(null)

// Form State
const schoolForm = ref({
  name_khmer: '',
  name_english: '',
  school_code: '',
  province: '',
  district: ''
})

const adminForm = ref({
  full_name: '',
  email: '',
  password: ''
})

async function handleSubmit() {
  error.value = ''
  loading.value = true

  try {
    // ── Step 1: Create School (skip if already created on a previous retry) ──
    if (!createdSchoolId.value) {
      const { data: schoolId, error: schoolError } = await supabase.rpc('super_admin_create_school', {
        p_name_khmer:   schoolForm.value.name_khmer,
        p_name_english: schoolForm.value.name_english,
        p_school_code:  schoolForm.value.school_code,
        p_province:     schoolForm.value.province,
        p_district:     schoolForm.value.district
      })

      if (schoolError) throw new Error(schoolError.message || 'Failed to create school.')
      if (!schoolId)   throw new Error('No school ID returned from database.')

      createdSchoolId.value = schoolId
      console.log('School created:', schoolId)
    } else {
      console.log('School already created, reusing ID:', createdSchoolId.value)
    }

    // ── Step 2: Create Admin User via Edge Function ──
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) throw new Error('Not authenticated. Please log in again.')

    const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL
    const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY

    let funcResponse
    try {
      funcResponse = await fetch(`${SUPABASE_URL}/functions/v1/manage-user`, {
        method: 'POST',
        headers: {
          'Content-Type':  'application/json',
          'Authorization': `Bearer ${session.access_token}`,
          'apikey':        SUPABASE_ANON_KEY
        },
        body: JSON.stringify({
          action: 'create',
          payload: {
            email:     adminForm.value.email,
            password:  adminForm.value.password,
            role:      'admin',
            full_name: adminForm.value.full_name,
            school_id: createdSchoolId.value
          }
        })
      })
    } catch (networkErr) {
      throw new Error('Cannot reach the server. Check your internet connection.')
    }

    const userData = await funcResponse.json()
    console.log('Edge function response:', funcResponse.status, userData)

    if (!funcResponse.ok || userData?.error) {
      throw new Error(userData?.error || `Server error (${funcResponse.status})`)
    }

    if (!userData?.success) {
      throw new Error('Unexpected response from server. Please try again.')
    }

    // ── Success ──
    console.log('Admin user created:', userData.userId)
    router.push('/super/schools')

  } catch (err) {
    console.error('Creation error:', err)
    error.value = err.message || 'An unexpected error occurred.'
  } finally {
    // Always stop loading — no matter what happens
    loading.value = false
  }
}
</script>

<template>
  <div class="max-w-3xl mx-auto space-y-8">
    <!-- Header -->
    <div class="flex items-center gap-4">
      <button 
        @click="router.back()" 
        class="p-2 hover:bg-white rounded-xl transition-all text-slate-400 hover:text-slate-900 border border-transparent hover:border-slate-200"
      >
        <ArrowLeft class="w-6 h-6" />
      </button>
      <div>
        <h1 class="text-3xl font-black text-slate-900 tracking-tight">ចុះឈ្មោះសាលារៀនថ្មី</h1>
        <p class="text-slate-500 font-medium">បង្កើតសាលារៀន និងគណនីអភិបាលដំបូង</p>
      </div>
    </div>

    <!-- Stepper -->
    <div class="flex items-center gap-4 mb-8">
      <div :class="['flex-1 h-2 rounded-full transition-all duration-500', step >= 1 ? 'bg-indigo-600' : 'bg-slate-200']"></div>
      <div :class="['flex-1 h-2 rounded-full transition-all duration-500', step >= 2 ? 'bg-indigo-600' : 'bg-slate-200']"></div>
    </div>

    <!-- Forms -->
    <div class="bg-white rounded-[2.5rem] border border-slate-200 shadow-xl shadow-slate-100 overflow-hidden">

      <!-- Step 1: School Info -->
      <div v-if="step === 1" class="p-10 animate-in fade-in slide-in-from-right-4 duration-300">
        <div class="flex items-center gap-4 mb-8">
          <div class="bg-indigo-50 p-3 rounded-2xl text-indigo-600">
            <School class="w-7 h-7" />
          </div>
          <h2 class="text-xl font-black text-slate-900">ព័ត៌មានសាលារៀន</h2>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-2 md:col-span-2">
            <label class="text-sm font-bold text-slate-700">ឈ្មោះសាលារៀន (ភាសាខ្មែរ)</label>
            <input 
              v-model="schoolForm.name_khmer" type="text" 
              placeholder="ឧ. សាលាបឋមសិក្សាបាត់ដំបង"
              class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ឈ្មោះសាលារៀន (English)</label>
            <input 
              v-model="schoolForm.name_english" type="text" 
              placeholder="e.g. Battambang Primary"
              class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">លេខកូដសាលា</label>
            <input 
              v-model="schoolForm.school_code" type="text" 
              placeholder="ឧ. BTB-001"
              class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-bold uppercase"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ខេត្ត/ក្រុង</label>
            <input 
              v-model="schoolForm.province" type="text" 
              placeholder="បាត់ដំបង"
              class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ស្រុក/ខណ្ឌ</label>
            <input 
              v-model="schoolForm.district" type="text" 
              placeholder="បាត់ដំបង"
              class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
            />
          </div>
        </div>

        <div class="mt-12 flex justify-end">
          <button 
            @click="step = 2"
            :disabled="!schoolForm.name_khmer || !schoolForm.school_code"
            class="bg-slate-900 text-white px-8 py-4 rounded-2xl font-bold flex items-center gap-2 hover:bg-slate-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            បន្តទៅកាន់ព័ត៌មានអ្នកគ្រប់គ្រង
            <ArrowRight class="w-5 h-5" />
          </button>
        </div>
      </div>

      <!-- Step 2: Admin Info -->
      <div v-if="step === 2" class="p-10 animate-in fade-in slide-in-from-right-4 duration-300">
        <div class="flex items-center gap-4 mb-8">
          <div class="bg-indigo-50 p-3 rounded-2xl text-indigo-600">
            <Shield class="w-7 h-7" />
          </div>
          <h2 class="text-xl font-black text-slate-900">គណនីអភិបាល (Admin)</h2>
        </div>

        <!-- Error Banner -->
        <div 
          v-if="error" 
          class="mb-8 p-4 bg-rose-50 border border-rose-200 rounded-2xl text-rose-700 text-sm font-bold flex items-center gap-3"
        >
          <div class="w-2 h-2 bg-rose-500 rounded-full flex-shrink-0"></div>
          {{ error }}
        </div>

        <div class="space-y-6">
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ឈ្មោះពេញ</label>
            <div class="relative">
              <User class="absolute left-5 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
              <input 
                v-model="adminForm.full_name" type="text" 
                placeholder="ឧ. ឈិត ត្រា"
                class="w-full pl-14 pr-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
              />
            </div>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">អ៊ីមែល (Email)</label>
            <div class="relative">
              <Mail class="absolute left-5 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
              <input 
                v-model="adminForm.email" type="email" 
                placeholder="admin@school.edu.kh"
                class="w-full pl-14 pr-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
              />
            </div>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">លេខសម្ងាត់ (Password)</label>
            <div class="relative">
              <Lock class="absolute left-5 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
              <input 
                v-model="adminForm.password" type="password" 
                placeholder="••••••••"
                class="w-full pl-14 pr-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
              />
            </div>
          </div>
        </div>

        <div class="mt-12 flex items-center justify-between">
          <button 
            @click="step = 1; error = ''"
            :disabled="loading"
            class="text-slate-500 font-bold hover:text-slate-900 transition-colors px-6 disabled:opacity-40"
          >
            ត្រឡប់ក្រោយ
          </button>
          <button 
            @click="handleSubmit"
            :disabled="loading || !adminForm.email || !adminForm.password || !adminForm.full_name"
            class="bg-indigo-600 text-white px-8 py-4 rounded-2xl font-bold flex items-center gap-2 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg shadow-indigo-200"
          >
            <Loader2 v-if="loading" class="w-5 h-5 animate-spin" />
            <Check v-else class="w-5 h-5" />
            {{ loading ? 'កំពុងបង្កើត...' : 'បង្កើតសាលារៀនឥឡូវនេះ' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Info Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="bg-slate-50 p-6 rounded-[2rem] border border-slate-100">
        <MapPin class="w-8 h-8 text-indigo-500 mb-4" />
        <h4 class="font-bold text-slate-900 mb-1">ទីតាំងស្វ័យប្រវត្តិ</h4>
        <p class="text-xs text-slate-500 leading-relaxed">ព័ត៌មានទីតាំងនឹងត្រូវប្រើប្រាស់សម្រាប់របាយការណ៍ស្ថិតិថ្នាក់ជាតិ។</p>
      </div>
      <div class="bg-slate-50 p-6 rounded-[2rem] border border-slate-100">
        <Shield class="w-8 h-8 text-emerald-500 mb-4" />
        <h4 class="font-bold text-slate-900 mb-1">សន្តិសុខទិន្នន័យ</h4>
        <p class="text-xs text-slate-500 leading-relaxed">រាល់ទិន្នន័យសាលារៀនថ្មីនឹងត្រូវដាក់ក្នុង Scope ដាច់ដោយឡែកភ្លាមៗ។</p>
      </div>
      <div class="bg-slate-50 p-6 rounded-[2rem] border border-slate-100">
        <Smartphone class="w-8 h-8 text-amber-500 mb-4" />
        <h4 class="font-bold text-slate-900 mb-1">ត្រៀមប្រើប្រាស់</h4>
        <p class="text-xs text-slate-500 leading-relaxed">បន្ទាប់ពីបង្កើតរួច Admin អាចចូលប្រើប្រាស់ និងកំណត់ឆ្នាំសិក្សាបានភ្លាម។</p>
      </div>
    </div>
  </div>
</template>