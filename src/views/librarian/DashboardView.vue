<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { BookOpenIcon, CheckCircleIcon, ExclamationTriangleIcon, ArrowUpTrayIcon, PlusIcon } from '@heroicons/vue/24/outline'

const stats = ref({
  totalBooks: 0,
  availableBooks: 0,
  borrowedBooks: 0,
  overdueBooks: 0
})
const loading = ref(true)
const recentBorrows = ref([])

onMounted(async () => {
  await loadStats()
})

async function loadStats() {
  loading.value = true
  
  // 1. Total & Available
  const { data: bookData } = await supabase.from('books').select('total_copies, available_copies')
  if (bookData) {
    stats.value.totalBooks = bookData.reduce((a, b) => a + b.total_copies, 0)
    stats.value.availableBooks = bookData.reduce((a, b) => a + b.available_copies, 0)
  }

  // 2. Borrowed status
  const { count: borrowedCount } = await supabase
    .from('book_borrows')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'borrowed')
  stats.value.borrowedBooks = borrowedCount || 0

  // 3. Overdue status
  const { count: overdueCount } = await supabase
    .from('book_borrows')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'overdue')
  stats.value.overdueBooks = overdueCount || 0

  // 4. Recent Borrows
  const { data: recent } = await supabase
    .from('book_borrows')
    .select('*, books(title), students(full_name)')
    .order('borrow_date', { ascending: false })
    .limit(5)
  recentBorrows.value = recent || []

  loading.value = false
}
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">ផ្ទាំងគ្រប់គ្រងបណ្ណាល័យ</h1>
        <p class="page-subtitle">គ្រប់គ្រងសៀវភៅ និងកំណត់ត្រាខ្ចីសៀវភៅ</p>
      </div>
    </div>

    <div v-if="loading" class="card card-body">
      <div class="skeleton" style="height:120px; margin-bottom:20px;"></div>
      <div class="skeleton" style="height:200px;"></div>
    </div>

    <div v-else>
      <div class="grid-cols-4" style="margin-bottom:24px;">
        <div class="stat-card">
          <div class="stat-icon" style="background:#e0f2fe;color:#0ea5e9;"><BookOpenIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">សៀវភៅសរុប</div>
            <div class="stat-value">{{ stats.totalBooks }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#f0fdf4;color:#22c55e;"><CheckCircleIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">នៅសល់</div>
            <div class="stat-value">{{ stats.availableBooks }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#fff7ed;color:#f97316;"><BookOpenIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">កំពុងខ្ចី</div>
            <div class="stat-value">{{ stats.borrowedBooks }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon" style="background:#fef2f2;color:#ef4444;"><ExclamationTriangleIcon class="w-6 h-6" /></div>
          <div class="stat-info">
            <div class="stat-label">ហួសកាលកំណត់</div>
            <div class="stat-value" style="color:#ef4444;">{{ stats.overdueBooks }}</div>
          </div>
        </div>
      </div>

      <div style="display:grid; grid-template-columns: 2fr 1fr; gap:20px;">
        <!-- Recent Borrowing -->
        <div class="card">
          <div class="card-header">
            <span class="card-title">សកម្មភាពខ្ចីថ្មីៗ</span>
            <router-link to="/librarian/borrows" class="btn btn-ghost btn-sm">មើលទាំងអស់</router-link>
          </div>
          <div class="card-body">
            <div v-if="recentBorrows.length === 0" class="empty-state" style="padding:40px;">
              <p style="color:var(--text-muted);">មិនទាន់មានសកម្មភាពថ្មីៗ</p>
            </div>
            <div v-else class="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>សិស្ស</th>
                    <th>សៀវភៅ</th>
                    <th>ថ្ងៃផុតកំណត់</th>
                    <th>ស្ថានភាព</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="b in recentBorrows" :key="b.id">
                    <td style="font-weight:600;">{{ b.students?.full_name }}</td>
                    <td>{{ b.books?.title }}</td>
                    <td>{{ new Date(b.due_date).toLocaleDateString() }}</td>
                    <td>
                      <span class="badge" 
                        :class="b.status === 'borrowed' ? 'badge-yellow' : 
                                b.status === 'overdue' ? 'badge-red' : 'badge-green'">
                        {{ 
                          b.status === 'borrowed' ? 'កំពុងខ្ចី' : 
                          b.status === 'overdue' ? 'ហួសកំណត់' : 'បានត្រឡប់' 
                        }}
                      </span>
                    </td>
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
            <button class="btn btn-primary w-full" @click="$router.push('/librarian/borrows')">
              <ArrowUpTrayIcon class="w-4 h-4" /> ចេញសៀវភៅ
            </button>
            <button class="btn btn-secondary w-full" @click="$router.push('/librarian/books')">
              <PlusIcon class="w-4 h-4" /> បញ្ចូលសៀវភៅថ្មី
            </button>
            <button class="btn btn-ghost w-full" @click="$router.push('/librarian/overdue')">
              <ExclamationTriangleIcon class="w-4 h-4" /> ពិនិត្យសៀវភៅហួសកំណត់
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>