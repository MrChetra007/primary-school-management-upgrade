<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { CheckIcon, XCircleIcon, ClipboardDocumentListIcon, ArrowUpTrayIcon } from '@heroicons/vue/24/outline'

const borrows = ref([])
const books = ref([])
const students = ref([])
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const toast = ref(null)
const search = ref('')

const studentSearch = ref('')
const studentResults = ref([])

const borrowForm = ref({ 
  book_id: '', 
  student_id: '', 
  borrow_date: new Date().toISOString().split('T')[0], 
  due_date: '', 
  status: 'borrowed' 
})

onMounted(async () => {
  await Promise.all([loadBorrows(), loadBooks(), loadStudents()])
})

async function loadBorrows() {
  loading.value = true
  const { data } = await supabase
    .from('book_borrows')
    .select('*, books(title, available_copies), students(full_name)')
    .order('borrow_date', { ascending: false })
  borrows.value = data || []
  loading.value = false
}

async function loadBooks() {
  const { data } = await supabase.from('books').select('id, title, available_copies').gt('available_copies', 0)
  books.value = data || []
}

async function loadStudents() {
  const { data } = await supabase.from('students').select('id, full_name').order('full_name')
  students.value = data || []
}

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return borrows.value.filter(b => 
    b.books?.title.toLowerCase().includes(q) || 
    b.students?.full_name.toLowerCase().includes(q)
  )
})

function searchStudents() {
  const q = studentSearch.value.toLowerCase()
  studentResults.value = q.length > 1 
    ? students.value.filter(s => s.full_name.toLowerCase().includes(q)).slice(0, 8) 
    : []
}

function selectStudent(s) {
  borrowForm.value.student_id = s.id
  studentSearch.value = s.full_name
  studentResults.value = []
}

async function issueBook() {
  if (!borrowForm.value.book_id || !borrowForm.value.student_id || !borrowForm.value.due_date) {
    showToast('សូមបំពេញទិន្នន័យទាំងអស់ដែលត្រូវការ', 'error'); 
    return
  }
  
  saving.value = true
  const { error } = await supabase.from('book_borrows').insert(borrowForm.value)
  
  if (!error) {
    const book = books.value.find(b => b.id === borrowForm.value.book_id)
    await supabase.from('books').update({ available_copies: book.available_copies - 1 }).eq('id', book.id)
    showToast('ចេញសៀវភៅបានជោគជ័យ!', 'success')
    showModal.value = false
    await loadBorrows()
    await loadBooks()
  } else {
    showToast(error.message, 'error')
  }
  saving.value = false
}

async function returnBook(record) {
  const { error } = await supabase
    .from('book_borrows')
    .update({ 
      status: 'returned', 
      return_date: new Date().toISOString().split('T')[0] 
    })
    .eq('id', record.id)
  
  if (!error) {
    const { data: book } = await supabase.from('books').select('available_copies').eq('id', record.book_id).single()
    await supabase.from('books').update({ available_copies: book.available_copies + 1 }).eq('id', record.book_id)
    showToast('សៀវភៅត្រឡប់បានជោគជ័យ!', 'success')
    await loadBorrows()
    await loadBooks()
  } else {
    showToast(error.message, 'error')
  }
}

function showToast(msg, type = 'success') {
  toast.value = { msg, type }
  setTimeout(() => { toast.value = null }, 3000)
}
</script>

<template>
  <div>
    <div class="toast-container">
      <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
        <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
        <XCircleIcon v-else class="w-4 h-4" /> 
        {{ toast.msg }}
      </div>
    </div>

    <div class="page-header">
      <div>
        <h1 class="page-title">កំណត់ត្រាខ្ចីសៀវភៅ</h1>
        <p class="page-subtitle">តាមដានសៀវភៅដែលបានចេញ និងត្រឡប់</p>
      </div>
      <button class="btn btn-primary" @click="showModal = true">
        <ArrowUpTrayIcon class="w-4 h-4" /> ចេញសៀវភៅ
      </button>
    </div>

    <div class="filters-bar">
      <div class="search-input-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"/>
          <line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input class="form-input" v-model="search" placeholder="ស្វែងរតាមសិស្ស ឬឈ្មោះសៀវភៅ..." />
      </div>
    </div>

    <div class="card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
      </div>
      <div v-else-if="filtered.length === 0" class="empty-state">
        <div class="empty-state-icon"><ClipboardDocumentListIcon class="w-12 h-12" /></div>
        <p class="empty-state-title">មិនមានកំណត់ត្រាខ្ចី</p>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>សិស្ស</th>
              <th>សៀវភៅ</th>
              <th>ថ្ងៃចេញ</th>
              <th>ថ្ងៃផុតកំណត់</th>
              <th>ស្ថានភាព</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="b in filtered" :key="b.id">
              <td style="font-weight:600;">{{ b.students?.full_name }}</td>
              <td>{{ b.books?.title }}</td>
              <td>{{ formatDate(b.borrow_date) }}</td>
              <td :style="b.status === 'overdue' ? 'color:var(--danger-color); font-weight:700;' : ''">
                {{ formatDate(b.due_date) }}
              </td>
              <td>
                <span class="badge" 
                  :class="b.status === 'returned' ? 'badge-green' : 
                          b.status === 'overdue' ? 'badge-red' : 'badge-yellow'">
                  {{ 
                    b.status === 'returned' ? 'បានត្រឡប់' : 
                    b.status === 'overdue' ? 'ហួសកំណត់' : 'កំពុងខ្ចី' 
                  }}
                </span>
              </td>
              <td>
                <button v-if="b.status !== 'returned'" class="btn btn-ghost btn-sm" @click="returnBook(b)">
                  កត់ត្រាបានត្រឡប់
                </button>
                <span v-else style="color:var(--text-muted); font-size:12px;">
                  ត្រឡប់នៅ {{ formatDate(b.return_date) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Issue Book Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <div class="modal-header">
          <span class="modal-title">ចេញសៀវភៅ</span>
          <button class="btn btn-ghost btn-sm btn-icon" @click="showModal = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        <div class="modal-body" style="display:flex;flex-direction:column;gap:14px;">
          <div class="form-group">
            <label class="form-label">ជ្រើសរើសសៀវភៅ *</label>
            <select class="form-select" v-model="borrowForm.book_id">
              <option value="">— ជ្រើសរើសសៀវភៅដែលនៅសល់ —</option>
              <option v-for="book in books" :key="book.id" :value="book.id">
                {{ book.title }} (នៅសល់ {{ book.available_copies }})
              </option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">សិស្ស *</label>
            <input class="form-input" v-model="studentSearch" @input="searchStudents" placeholder="វាយឈ្មោះសិស្ស..." />
            <div v-if="studentResults.length > 0" style="border:1px solid var(--border-default);border-radius:8px;margin-top:4px;background:white;box-shadow:var(--shadow-md);overflow:hidden;z-index:10;">
              <div v-for="s in studentResults" :key="s.id" 
                   style="padding:8px 12px;cursor:pointer;font-size:13px;" 
                   @click="selectStudent(s)"
                   onmouseover="this.style.background='#f8fafc'" 
                   onmouseout="this.style.background='white'">
                {{ s.full_name }}
              </div>
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">ថ្ងៃចេញ</label>
            <input class="form-input" type="date" v-model="borrowForm.borrow_date" />
          </div>
          <div class="form-group">
            <label class="form-label">ថ្ងៃផុតកំណត់ *</label>
            <input class="form-input" type="date" v-model="borrowForm.due_date" />
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showModal = false">បោះបង់</button>
          <button class="btn btn-primary" @click="issueBook" :disabled="saving">
            {{ saving ? 'កំពុងដំណើរការ...' : 'បញ្ជាក់ការចេញសៀវភៅ' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>