<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/utils/formatDate'
import { CheckIcon, XCircleIcon } from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'

const { showToast } = useToast()
const overdueRecords = ref([])
const loading = ref(true)

onMounted(loadOverdue)

async function loadOverdue() {
  loading.value = true
  const today = new Date().toISOString().split('T')[0]
  const { data } = await supabase
    .from('book_borrows')
    .select('*, books(title), students(full_name, phone_number)')
    .or(`status.eq.overdue,and(status.eq.borrowed,due_date.lt.${today})`)
    .order('due_date', { ascending: true })
  
  overdueRecords.value = data || []
  loading.value = false
}

async function markReturned(record) {
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
    loadOverdue()
  } else {
    showToast(error.message, 'error')
  }
}

</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">សៀវភៅហួសកំណត់</h1>
        <p class="page-subtitle">ត្រូវការយកចិត្តទុកដាក់ភ្លាមៗលើសៀវភៅទាំងនេះ</p>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div v-for="i in 5" :key="i" class="skeleton" style="height:52px;margin-bottom:10px;border-radius:8px;"></div>
    </div>

    <div v-else class="card">
      <div v-if="overdueRecords.length === 0" class="empty-state">
        <div class="empty-state-icon" style="color:var(--success-color);"><CheckIcon class="w-12 h-12" /></div>
        <p class="empty-state-title">មិនមានសៀវភៅហួសកំណត់</p>
        <p class="empty-state-desc">បច្ចុប្បន្នសៀវភៅទាំងអស់ស្ថិតក្នុងកំណត់កាលកំណត់។</p>
      </div>
      <div v-else class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>សិស្ស</th>
              <th>សៀវភៅ</th>
              <th>ថ្ងៃផុតកំណត់</th>
              <th>ហួសកំណត់ (ថ្ងៃ)</th>
              <th>ទូរស័ព្ទ</th>
              <th>សកម្មភាព</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="b in overdueRecords" :key="b.id">
              <td style="font-weight:600;">{{ b.students?.full_name }}</td>
              <td>{{ b.books?.title }}</td>
              <td style="color:var(--danger-color); font-weight:700;">{{ formatDate(b.due_date) }}</td>
              <td>
                <span class="badge badge-red">
                  {{ Math.floor((new Date() - new Date(b.due_date)) / (1000 * 60 * 60 * 24)) }} ថ្ងៃ
                </span>
              </td>
              <td style="font-size:13px;">{{ b.students?.phone_number || 'មិនមានលេខ' }}</td>
              <td>
                <button class="btn btn-secondary btn-sm" @click="markReturned(b)">
                  កត់ត្រាបានត្រឡប់
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>