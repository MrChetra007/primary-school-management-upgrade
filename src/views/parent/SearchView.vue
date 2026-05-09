<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { MagnifyingGlassIcon, AcademicCapIcon, InformationCircleIcon } from '@heroicons/vue/24/outline'

const router = useRouter()
const studentName = ref('')
const dob = ref('')
const searching = ref(false)
const error = ref(null)

async function handleSearch() {
  if (!studentName.value || !dob.value) {
    error.value = 'សូមបញ្ជាក់ឈ្មោះ និង ថ្ងៃខែឆ្នាំកំណើតរបស់សិស្ស'
    return
  }

  searching.value = true
  error.value = null

  try {
    const { data, error: err } = await supabase
      .from('students')
      .select('id, full_name, dob')
      .ilike('full_name', `%${studentName.value.trim()}%`)
      .eq('dob', dob.value)
      .maybeSingle()

    if (err) throw err
    
    if (data) {
      router.push(`/parent/student/${data.id}`)
    } else {
      error.value = 'រកមិនឃើញសិស្សទេ! សូមពិនិត្យមើលឈ្មោះ និង ថ្ងៃកំណើតឡើងវិញឱ្យបានត្រឹមត្រូវ។'
    }
  } catch (err) {
    error.value = 'មានបញ្ហាបច្ចេកទេសក្នុងការស្វែងរក។ សូមព្យាយាមម្តងទៀតនៅពេលក្រោយ។'
    console.error(err)
  } finally {
    searching.value = false
  }
}
</script>

<template>
  <div class="search-page">
    <div class="search-hero">
      <div class="hero-icon">
        <AcademicCapIcon class="w-16 h-16" />
      </div>
      <h1 class="hero-title">វិបផតថលមាតាបិតា</h1>
      <p class="hero-subtitle">តាមដានវឌ្ឍនភាពសិក្សារបស់កូនអ្នកឱ្យបានជាប់លាប់</p>
    </div>

    <div class="search-container">
      <div class="search-card">
        <div class="card-glow"></div>
        <div class="search-card-header">
          <h2>ស្វែងរកព័ត៌មានសិស្ស</h2>
          <p>បញ្ចូលព័ត៌មានខាងក្រោមដើម្បីចូលមើលលទ្ធផល</p>
        </div>

        <form @submit.prevent="handleSearch" class="search-form">
          <div class="form-group">
            <label class="form-label">ឈ្មោះសិស្សពេញ</label>
            <div class="input-with-icon">
              <input 
                type="text" 
                class="form-input form-input-lg" 
                v-model="studentName" 
                placeholder="ឧ. សុខ ចាន់ត្រា"
                required
              />
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">ថ្ងៃខែឆ្នាំកំណើត</label>
            <input 
              type="date" 
              class="form-input form-input-lg" 
              v-model="dob" 
              required
            />
          </div>

          <transition name="shake">
            <div v-if="error" class="alert alert-error">
              <InformationCircleIcon class="w-5 h-5 flex-shrink-0" />
              <span>{{ error }}</span>
            </div>
          </transition>

          <button type="submit" class="btn btn-primary btn-lg btn-block" :disabled="searching">
            <span v-if="searching" class="loader-sm"></span>
            <MagnifyingGlassIcon v-else class="w-5 h-5" />
            <span>{{ searching ? 'កំពុងស្វែងរក...' : 'ស្វែងរកទិន្នន័យ' }}</span>
          </button>
        </form>
      </div>

      <!-- Helper info -->
      <div class="helper-info">
        <div class="info-item">
          <div class="info-dot dot-green"></div>
          <span>ពិនិត្យមើលវត្តមានប្រចាំខែ</span>
        </div>
        <div class="info-item">
          <div class="info-dot dot-blue"></div>
          <span>តាមដានពិន្ទុ និងចំណាត់ថ្នាក់</span>
        </div>
        <div class="info-item">
          <div class="info-dot dot-purple"></div>
          <span>ព័ត៌មានសុខភាព និងកំណើនកាយ</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.search-page {
  min-height: 80vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
}

.search-hero {
  text-align: center;
  margin-bottom: 40px;
}

.hero-icon {
  width: 80px;
  height: 80px;
  background: linear-gradient(135deg, var(--primary-500) 0%, var(--primary-700) 100%);
  border-radius: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  margin: 0 auto 20px;
  box-shadow: 0 8px 30px rgba(74, 127, 165, 0.3);
}

.hero-title {
  font-size: 32px;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 8px;
}

.hero-subtitle {
  font-size: 16px;
  color: var(--text-secondary);
}

.search-container {
  width: 100%;
  max-width: 460px;
}

.search-card {
  background: white;
  border-radius: 24px;
  padding: 40px;
  box-shadow: var(--shadow-xl);
  position: relative;
  overflow: hidden;
  border: 1px solid var(--border-default);
}

.card-glow {
  position: absolute;
  top: -100px;
  right: -100px;
  width: 200px;
  height: 200px;
  background: radial-gradient(circle, rgba(74, 127, 165, 0.1) 0%, transparent 70%);
  pointer-events: none;
}

.search-card-header {
  margin-bottom: 32px;
  text-align: center;
}

.search-card-header h2 {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary);
}

.search-card-header p {
  font-size: 14px;
  color: var(--text-muted);
  margin-top: 4px;
}

.search-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.form-input-lg {
  padding: 14px 18px;
  font-size: 15px;
}

.btn-block {
  width: 100%;
  justify-content: center;
  padding: 14px;
  font-size: 16px;
  margin-top: 12px;
}

.alert {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  border-radius: 12px;
  font-size: 13px;
}

.alert-error {
  background: var(--bg-danger);
  color: var(--color-danger);
  border: 1px solid var(--border-danger);
}

.helper-info {
  display: flex;
  justify-content: center;
  gap: 20px;
  margin-top: 32px;
  flex-wrap: wrap;
}

.info-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-secondary);
}

.info-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.dot-green { background: #10b981; }
.dot-blue { background: #3b82f6; }
.dot-purple { background: #8b5cf6; }

.loader-sm {
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Shake animation for errors */
.shake-enter-active {
  animation: shake 0.5s cubic-bezier(.36,.07,.19,.97) both;
}

@keyframes shake {
  10%, 90% { transform: translate3d(-1px, 0, 0); }
  20%, 80% { transform: translate3d(2px, 0, 0); }
  30%, 50%, 70% { transform: translate3d(-4px, 0, 0); }
  40%, 60% { transform: translate3d(4px, 0, 0); }
}

@media (max-width: 640px) {
  .search-card {
    padding: 30px 20px;
  }
  .hero-title {
    font-size: 26px;
  }
}
</style>
