<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { School, ArrowLeft, Save, Loader2 } from 'lucide-vue-next'

const router = useRouter()
const route = useRoute()
const schoolId = route.params.id

const form = ref({
  name_khmer: '',
  name_english: '',
  school_code: '',
  province: '',
  district: '',
  status: 'active'
})
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const success = ref(false)

onMounted(async () => {
  loading.value = true
  try {
    const { data, error: err } = await supabase
      .from('schools')
      .select('*')
      .eq('id', schoolId)
      .single()

    if (err) throw err
    if (!data) throw new Error('School not found')

    form.value = {
      name_khmer: data.name_khmer || '',
      name_english: data.name_english || '',
      school_code: data.school_code || '',
      province: data.province || '',
      district: data.district || '',
      status: data.status || 'active'
    }
  } catch (e) {
    error.value = e.message || 'Failed to load school'
  } finally {
    loading.value = false
  }
})

async function handleSave() {
  if (!form.value.name_khmer || !form.value.school_code) {
    error.value = 'School name (Khmer) and code are required.'
    return
  }

  saving.value = true
  error.value = ''
  success.value = false

  try {
    const { error: err } = await supabase
      .from('schools')
      .update({
        name_khmer: form.value.name_khmer,
        name_english: form.value.name_english,
        school_code: form.value.school_code,
        province: form.value.province,
        district: form.value.district,
        status: form.value.status
      })
      .eq('id', schoolId)

    if (err) throw err
    success.value = true
    setTimeout(() => success.value = false, 3000)
  } catch (e) {
    error.value = e.message || 'Failed to update school'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl mx-auto space-y-8">
    <div class="flex items-center gap-4">
      <button
        @click="router.push('/super/schools')"
        class="p-2 hover:bg-white rounded-xl transition-all text-slate-400 hover:text-slate-900 border border-transparent hover:border-slate-200"
      >
        <ArrowLeft class="w-6 h-6" />
      </button>
      <div>
        <h1 class="text-3xl font-black text-slate-900 tracking-tight">កែសម្រួលព័ត៌មានសាលារៀន</h1>
        <p class="text-slate-500 font-medium">កែប្រែព័ត៌មានលម្អិតរបស់សាលារៀន</p>
      </div>
    </div>

    <div v-if="loading" class="bg-white rounded-[2.5rem] border border-slate-200 p-10">
      <div class="space-y-6 animate-pulse">
        <div class="h-12 bg-slate-100 rounded-2xl"></div>
        <div class="h-12 bg-slate-100 rounded-2xl"></div>
        <div class="grid grid-cols-2 gap-6">
          <div class="h-12 bg-slate-100 rounded-2xl"></div>
          <div class="h-12 bg-slate-100 rounded-2xl"></div>
        </div>
      </div>
    </div>

    <div v-else class="bg-white rounded-[2.5rem] border border-slate-200 shadow-xl shadow-slate-100 overflow-hidden p-10">
      <div class="flex items-center gap-4 mb-8">
        <div class="bg-indigo-50 p-3 rounded-2xl text-indigo-600">
          <School class="w-7 h-7" />
        </div>
        <h2 class="text-xl font-black text-slate-900">ព័ត៌មានសាលារៀន</h2>
      </div>

      <div v-if="error" class="mb-6 p-4 bg-rose-50 border border-rose-200 rounded-2xl text-rose-700 text-sm font-bold">
        {{ error }}
      </div>

      <div v-if="success" class="mb-6 p-4 bg-emerald-50 border border-emerald-200 rounded-2xl text-emerald-700 text-sm font-bold flex items-center gap-2">
        <Save class="w-4 h-4" />
        បានរក្សាទុកដោយជោគជ័យ
      </div>

      <form @submit.prevent="handleSave" class="space-y-6">
        <div class="space-y-2">
          <label class="text-sm font-bold text-slate-700">ឈ្មោះសាលារៀន (ភាសាខ្មែរ)</label>
          <input v-model="form.name_khmer" type="text" class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-bold text-slate-700">ឈ្មោះសាលារៀន (English)</label>
          <input v-model="form.name_english" type="text" class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium" />
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">លេខកូដសាលា</label>
            <input v-model="form.school_code" type="text" class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-bold uppercase" />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ស្ថានភាព</label>
            <select v-model="form.status" class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium appearance-none">
              <option value="active">សកម្ម</option>
              <option value="inactive">មិនសកម្ម</option>
            </select>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ខេត្ត/ក្រុង</label>
            <input v-model="form.province" type="text" class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium" />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-bold text-slate-700">ស្រុក/ខណ្ឌ</label>
            <input v-model="form.district" type="text" class="w-full px-5 py-3.5 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium" />
          </div>
        </div>

        <div class="pt-4 flex justify-end gap-4">
          <button type="button" @click="router.push('/super/schools')" class="px-8 py-3.5 rounded-2xl font-bold border border-slate-200 text-slate-600 hover:bg-slate-50 transition-all">
            បោះបង់
          </button>
          <button type="submit" :disabled="saving" class="bg-indigo-600 text-white px-8 py-3.5 rounded-2xl font-bold flex items-center gap-2 hover:bg-indigo-700 disabled:opacity-50 transition-all shadow-lg shadow-indigo-200">
            <Loader2 v-if="saving" class="w-5 h-5 animate-spin" />
            <Save v-else class="w-5 h-5" />
            {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
