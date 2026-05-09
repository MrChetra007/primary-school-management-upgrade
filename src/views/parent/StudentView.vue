<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, RouterView } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { 
  UserIcon, 
  AcademicCapIcon, 
  HashtagIcon, 
  IdentificationIcon,
  CalendarDaysIcon,
  MapPinIcon
} from '@heroicons/vue/24/outline'

const route = useRoute()
const studentId = route.params.id
const student = ref(null)
const loading = ref(true)
const error = ref(null)

onMounted(async () => {
  try {
    const { data, error: err } = await supabase
      .from('students')
      .select('*, classes(class_name, academic_year_id), academic_years(year_name)')
      .eq('id', studentId)
      .single()

    if (err) throw err
    student.value = data
  } catch (err) {
    error.value = 'មានបញ្ហាក្នុងការទាញយកទិន្នន័យសិស្ស'
    console.error(err)
  } finally {
    loading.value = false
  }
})

function getInitials(name) {
  if (!name) return 'S'
  return name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase()
}
</script>

<template>
  <div class="student-detail-wrapper">
    <!-- Skeleton Loading -->
    <div v-if="loading" class="student-profile-skeleton">
      <div class="skeleton profile-header-skeleton"></div>
      <div class="skeleton profile-stats-skeleton"></div>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="alert alert-error">
      {{ error }}
    </div>

    <!-- Profile Header -->
    <template v-else-if="student">
      <div class="student-profile-header">
        <div class="profile-main-info">
          <div class="profile-avatar-wrap">
            <div class="profile-avatar">
              <img v-if="student.photo_url" :src="student.photo_url" :alt="student.full_name" />
              <div v-else class="avatar-placeholder">{{ getInitials(student.full_name) }}</div>
            </div>
          </div>

          <div class="profile-text-info">
            <div class="name-row">
              <h1 class="student-name">{{ student.full_name }}</h1>
              <span class="badge badge-green">កំពុងសិក្សា</span>
            </div>
            
            <div class="info-grid">
              <div class="info-item">
                <HashtagIcon class="w-4 h-4" />
                <span>អត្តលេខ: <strong>{{ student.student_id_card }}</strong></span>
              </div>
              <div class="info-item">
                <AcademicCapIcon class="w-4 h-4" />
                <span>ថ្នាក់: <strong>{{ student.classes?.class_name }}</strong></span>
              </div>
              <div class="info-item">
                <CalendarDaysIcon class="w-4 h-4" />
                <span>ឆ្នាំសិក្សា: <strong>{{ student.academic_years?.year_name }}</strong></span>
              </div>
              <div class="info-item">
                <IdentificationIcon class="w-4 h-4" />
                <span>ភេទ: <strong>{{ student.gender === 'male' ? 'ប្រុស' : 'ស្រី' }}</strong></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Child View Content -->
    <div class="child-view-container">
      <RouterView />
    </div>
  </div>
</template>

<style scoped>
.student-detail-wrapper {
  animation: slideUp 0.4s ease;
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

.student-profile-header {
  background: white;
  border-radius: 20px;
  padding: 30px;
  box-shadow: var(--shadow-md);
  margin-bottom: 24px;
  border: 1px solid var(--border-default);
  position: relative;
  overflow: hidden;
}

.student-profile-header::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 6px;
  background: linear-gradient(90deg, var(--primary-500), var(--primary-700));
}

.profile-main-info {
  display: flex;
  gap: 30px;
  align-items: center;
}

.profile-avatar-wrap {
  position: relative;
}

.profile-avatar {
  width: 110px;
  height: 110px;
  border-radius: 24px;
  overflow: hidden;
  background: var(--primary-50);
  border: 4px solid white;
  box-shadow: var(--shadow-lg);
  display: flex;
  align-items: center;
  justify-content: center;
}

.profile-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  font-size: 36px;
  font-weight: 800;
  color: var(--primary-500);
  font-family: var(--font-khmer);
}

.profile-text-info {
  flex: 1;
}

.name-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.student-name {
  font-size: 26px;
  font-weight: 800;
  color: var(--text-primary);
  font-family: var(--font-khmer);
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px 24px;
}

.info-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--text-secondary);
}

.info-item strong {
  color: var(--text-primary);
}

/* Skeleton loader */
.profile-header-skeleton {
  height: 160px;
  border-radius: 20px;
  margin-bottom: 24px;
}

.profile-stats-skeleton {
  height: 100px;
  border-radius: 12px;
}

@media (max-width: 768px) {
  .profile-main-info {
    flex-direction: column;
    text-align: center;
    gap: 20px;
  }
  
  .name-row {
    flex-direction: column;
    gap: 8px;
  }
  
  .info-grid {
    grid-template-columns: 1fr;
    gap: 8px;
  }
  
  .info-item {
    justify-content: center;
  }
}
</style>
