<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { CheckIcon, XCircleIcon, BookOpenIcon, TrashIcon } from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'

const books = ref([])
const auth = useAuthStore()
const { showToast } = useToast()
const loading = ref(true)
const saving = ref(false)
const search = ref('')
const showModal = ref(false)
const isEdit = ref(false)
const deleteTarget = ref(null)

const emptyForm = () => ({ 
  id: null, 
  title: '', 
  author: '', 
  isbn: '', 
  category: '', 
  total_copies: 1, 
  available_copies: 1 
})
const form = ref(emptyForm())

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return books.value.filter(b => 
    b.title.toLowerCase().includes(q) || 
    (b.author || '').toLowerCase().includes(q) ||
    (b.isbn || '').includes(q)
  )
})

onMounted(load)

async function load() {
  loading.value = true
  const { data } = await supabase.from('books').select('*').order('title')
  books.value = data || []
  loading.value = false
}

function openAdd() {
  isEdit.value = false
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(b) {
  isEdit.value = true
  form.value = { ...b }
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim()) { 
    showToast('សូមបញ្ចូលឈ្មោះសៀវភៅ', 'error'); 
    return 
  }
  saving.value = true
  const { id, ...payload } = form.value
  const { error } = isEdit.value
    ? await supabase.from('books').update(payload).eq('id', id)
    : await supabase.from('books').insert({ ...payload, school_id: auth.schoolId })
  
  saving.value = false
  if (error) { showToast(error.message, 'error'); return }
  
  showToast(isEdit.value ? 'បានកែប្រែសៀវភៅ!' : 'បានបញ្ចូលសៀវភៅថ្មី!', 'success')
  showModal.value = false
  load()
}

async function doDelete() {
  const { error } = await supabase.from('books').delete().eq('id', deleteTarget.value.id)
  deleteTarget.value = null
  if (error) { showToast(error.message, 'error'); return }
  showToast('បានលុបសៀវភៅ', 'success')
  load()
}

</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">គ្រប់គ្រងសៀវភៅ</h1>
        <p class="page-subtitle">បញ្ចូល កែប្រែ ឬលុបសៀវភៅចេញពីបណ្ណាល័យ</p>
      </div>
      <button class="btn btn-primary" @click="openAdd">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px">
          <line x1="12" y1="5" x2="12" y2="19"/>
          <line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        បញ្ចូលសៀវភៅថ្មី
      </button>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"/>
          <line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរតាមឈ្មោះសៀវភៅ អ្នកនិពន្ធ ឬ ISBN..." />
      </div>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <div class="empty-state-icon"><BookOpenIcon class="w-12 h-12" /></div>
        <p class="empty-state-title">មិនមានសៀវភៅ</p>
        <button class="btn btn-primary" @click="openAdd">បញ្ចូលសៀវភៅដំបូង</button>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>ឈ្មោះសៀវភៅ</th>
              <th>អ្នកនិពន្ធ</th>
              <th>ISBN</th>
              <th>សរុប</th>
              <th>នៅសល់</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="b in filtered" :key="b.id">
              <td style="font-weight:600;">{{ b.title }}</td>
              <td>{{ b.author || '—' }}</td>
              <td style="font-size:12px;color:var(--text-muted);">{{ b.isbn || '—' }}</td>
              <td>{{ b.total_copies }}</td>
              <td>
                <span class="badge" :class="b.available_copies > 0 ? 'badge-green' : 'badge-red'">
                  {{ b.available_copies }}
                </span>
              </td>
              <td>
                <div class="table-actions">
                  <button class="btn btn-ghost btn-sm btn-icon" @click="openEdit(b)">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                      <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                    </svg>
                  </button>
                  <button class="btn btn-danger btn-sm btn-icon" @click="deleteTarget = b">
                    <TrashIcon class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal modal-lg">
        <div class="modal-header">
          <span class="modal-title">{{ isEdit ? 'កែប្រែសៀវភៅ' : 'បញ្ចូលសៀវភៅថ្មី' }}</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        <div class="modal-body" style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
          <div class="form-group" style="grid-column:1/-1;">
            <label class="form-label">ឈ្មោះសៀវភៅ *</label>
            <input class="form-input" v-model="form.title" placeholder="ឈ្មោះសៀវភៅ" />
          </div>
          <div class="form-group">
            <label class="form-label">អ្នកនិពន្ធ</label>
            <input class="form-input" v-model="form.author" placeholder="ឈ្មោះអ្នកនិពន្ធ" />
          </div>
          <div class="form-group">
            <label class="form-label">ISBN</label>
            <input class="form-input" v-model="form.isbn" placeholder="លេខ ISBN" />
          </div>
          <div class="form-group">
            <label class="form-label">ប្រភេទ</label>
            <input class="form-input" v-model="form.category" placeholder="ឧ. វិទ្យាសាស្ត្រ, អក្សរសាស្ត្រ" />
          </div>
          <div class="form-group">
            <label class="form-label">ចំនួនសរុប</label>
            <input class="form-input" type="number" v-model="form.total_copies" min="1" />
          </div>
          <div class="form-group">
            <label class="form-label">នៅសល់</label>
            <input class="form-input" type="number" v-model="form.available_copies" min="0" />
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
          <div style="margin-bottom:12px;"><TrashIcon class="w-10 h-10 text-red-500" /></div>
          <h3 style="margin-bottom:8px;">លុបសៀវភៅ?</h3>
          <p style="color:var(--text-secondary);font-size:13px;">
            លុប <strong>{{ deleteTarget.title }}</strong>? កំណត់ត្រាខ្ចីនឹងត្រូវលុបផងដែរ។
          </p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="deleteTarget = null">បោះបង់</button>
          <button class="btn btn-danger" @click="doDelete">យល់ព្រម លុប</button>
        </div>
      </div>
    </div>
  </div>
</template>