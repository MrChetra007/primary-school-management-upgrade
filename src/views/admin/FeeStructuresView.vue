<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAcademicYearStore } from '@/stores/academicYear'
import { useToast } from '@/composables/useToast'
import { ArrowLeftIcon, PlusIcon, PencilSquareIcon, TrashIcon, BanknotesIcon } from '@heroicons/vue/24/outline'

const router = useRouter()
const auth = useAuthStore()
const yearStore = useAcademicYearStore()
const { showToast } = useToast()

const structures = ref([])
const classes = ref([])
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)

const emptyForm = () => ({
  id: null,
  academic_year_id: yearStore.selectedYearId,
  class_id: '',
  name: '',
  cycle: 'monthly',
  semester: '',
  amount: '',
  currency: 'KHR',
  due_day: 10,
  is_active: true,
})

const form = ref(emptyForm())

const classMap = computed(() => Object.fromEntries(classes.value.map((c) => [c.id, c])))

onMounted(async () => {
  await Promise.all([load(), loadClasses()])
})

async function load() {
  loading.value = true
  const { data, error } = await supabase
    .from('fee_structures')
    .select('*, classes(class_name, turn)')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('created_at', { ascending: false })
  if (error) showToast(error.message, 'error')
  structures.value = data || []
  loading.value = false
}

async function loadClasses() {
  const { data } = await supabase
    .from('classes')
    .select('id, class_name, turn')
    .eq('academic_year_id', yearStore.selectedYearId)
    .order('class_name')
  classes.value = data || []
}

function openAdd() {
  isEdit.value = false
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(s) {
  isEdit.value = true
  form.value = {
    id: s.id,
    academic_year_id: s.academic_year_id,
    class_id: s.class_id || '',
    name: s.name,
    cycle: s.cycle,
    semester: s.semester || '',
    amount: s.amount,
    currency: s.currency,
    due_day: s.due_day || 10,
    is_active: s.is_active,
  }
  showModal.value = true
}

async function save() {
  if (!form.value.name || form.value.amount === '') {
    showToast('សូមបំពេញឈ្មោះ និងចំនួនទឹកប្រាក់', 'error')
    return
  }
  saving.value = true

  const payload = {
    academic_year_id: form.value.academic_year_id,
    class_id: form.value.class_id || null,
    name: form.value.name,
    cycle: form.value.cycle,
    semester: form.value.cycle === 'semester' ? Number(form.value.semester) || null : null,
    amount: Number(form.value.amount),
    currency: form.value.currency,
    due_day: form.value.cycle === 'monthly' ? Number(form.value.due_day) || null : null,
    is_active: form.value.is_active,
  }

  const { error } = isEdit.value
    ? await supabase.from('fee_structures').update(payload).eq('id', form.value.id)
    : await supabase.from('fee_structures').insert({ ...payload, school_id: auth.schoolId })

  saving.value = false
  if (error) { showToast(error.message, 'error'); return }

  showToast(isEdit.value ? 'បានកែប្រែរួចរាល់!' : 'បានបន្ថែមរួចរាល់!', 'success')
  showModal.value = false
  load()
}

async function doDelete() {
  const { error } = await supabase.from('fee_structures').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបរួចរាល់', 'success')
  load()
}

function cycleLabel(c) {
  return { monthly: 'ប្រចាំខែ', semester: 'ប្រចាំឆមាស', yearly: 'ប្រចាំឆ្នាំ' }[c] || c
}

function fmt(n, currency = 'KHR') {
  const suffix = currency === 'USD' ? '$' : '៛'
  return `${Number(n).toLocaleString('en-US')} ${suffix}`
}
</script>

<template>
  <div>
    <div class="page-header">
      <div style="display:flex;align-items:center;gap:12px;">
        <button class="btn btn-ghost btn-icon" @click="router.push('/admin/fees')">
          <ArrowLeftIcon class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">រចនាសម្ព័ន្ធថ្លៃសិក្សា</h1>
          <p class="page-subtitle">កំណត់ថ្លៃសិក្សាតាមថ្នាក់ វដ្ត និងចំនួនទឹកប្រាក់</p>
        </div>
      </div>
      <button class="btn btn-primary" @click="openAdd">
        <PlusIcon class="w-4 h-4" />
        បន្ថែមរចនាសម្ព័ន្ធ
      </button>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 4" :key="i" class="skeleton" style="height:44px;margin-bottom:10px;border-radius:8px;"></div>
      </div>

      <div v-else-if="structures.length === 0" class="empty-state">
        <BanknotesIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">មិនទាន់មានរចនាសម្ព័ន្ធថ្លៃទេ</p>
        <button class="btn btn-primary" @click="openAdd">បន្ថែមរចនាសម្ព័ន្ធដំបូង</button>
      </div>

      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>ឈ្មោះ</th>
              <th>ថ្នាក់រៀន</th>
              <th>វដ្ត</th>
              <th>ចំនួនទឹកប្រាក់</th>
              <th>ថ្ងៃកំណត់</th>
              <th>ស្ថានភាព</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in structures" :key="s.id">
              <td style="font-weight:700;">{{ s.name }}</td>
              <td>
                <span v-if="s.classes" class="badge badge-gray">{{ s.classes.class_name }}</span>
                <span v-else class="badge badge-blue">គ្រប់ថ្នាក់</span>
              </td>
              <td>{{ cycleLabel(s.cycle) }}<span v-if="s.semester"> · ឆមាស {{ s.semester }}</span></td>
              <td style="font-weight:700;color:#059669;">{{ fmt(s.amount, s.currency) }}</td>
              <td>{{ s.due_day ? 'ថ្ងៃទី ' + s.due_day : '—' }}</td>
              <td>
                <span class="badge" :class="s.is_active ? 'badge-green' : 'badge-gray'">
                  {{ s.is_active ? 'សកម្ម' : 'ផ្អាក' }}
                </span>
              </td>
              <td>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(s)">
                    <PencilSquareIcon class="w-4 h-4" />
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = s">
                    <TrashIcon class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែរចនាសម្ព័ន្ធ' : 'បន្ថែមរចនាសម្ព័ន្ធថ្លៃ' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">ឈ្មោះ *</label>
            <input class="form-input" v-model="form.name" placeholder="ឧ. ថ្លៃសិក្សាប្រចាំខែ" />
          </div>
          <div class="form-group">
            <label class="form-label">ថ្នាក់រៀន</label>
            <select class="form-select" v-model="form.class_id">
              <option value="">គ្រប់ថ្នាក់</option>
              <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.class_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">វដ្ត</label>
            <select class="form-select" v-model="form.cycle">
              <option value="monthly">ប្រចាំខែ</option>
              <option value="semester">ប្រចាំឆមាស</option>
              <option value="yearly">ប្រចាំឆ្នាំ</option>
            </select>
          </div>
          <div v-if="form.cycle === 'semester'" class="form-group">
            <label class="form-label">ឆមាស</label>
            <select class="form-select" v-model="form.semester">
              <option value="1">ឆមាស ១</option>
              <option value="2">ឆមាស ២</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">ចំនួនទឹកប្រាក់ *</label>
            <input class="form-input" type="number" v-model="form.amount" placeholder="0" min="0" />
          </div>
          <div class="form-group">
            <label class="form-label">រូបិយប័ណ្ណ</label>
            <select class="form-select" v-model="form.currency">
              <option value="KHR">រៀល (៛)</option>
              <option value="USD">ដុល្លារ ($)</option>
            </select>
          </div>
          <div v-if="form.cycle === 'monthly'" class="form-group">
            <label class="form-label">ថ្ងៃកំណត់ក្នុងខែ</label>
            <input class="form-input" type="number" v-model="form.due_day" min="1" max="31" />
          </div>
          <div class="form-group" style="grid-column:1/-1;display:flex;align-items:center;gap:8px;">
            <input id="fs-active" type="checkbox" v-model="form.is_active" />
            <label for="fs-active" class="form-label" style="margin:0;">សកម្ម</label>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="save" :disabled="saving">
            {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation -->
    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal" style="max-width:360px;">
        <div class="modal-body" style="text-align:center;padding:28px 24px;">
          <TrashIcon class="w-12 h-12 text-red-400" style="margin:0 auto 12px;" />
          <h3 style="margin-bottom:8px;">លុបរចនាសម្ព័ន្ធនេះ?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">វិក័យប័ត្រពាក់ព័ន្ធទាំងអស់ក៏នឹងត្រូវលុបផងដែរ។</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រម លុប</button>
        </div>
      </div>
    </div>
  </div>
</template>
