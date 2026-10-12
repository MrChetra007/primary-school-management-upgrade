<script setup>
import { computed } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { usePlanStore } from '@/stores/plan'

const router = useRouter()
const auth = useAuthStore()
const planStore = usePlanStore()

const isAdmin = computed(() => auth.role === 'admin')

const proFeatures = [
  { icon: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z', label: 'បណ្ណាល័យ', desc: 'គ្រប់គ្រងសៀវភៅ ការខ្ចី និងការសង' },
  { icon: 'M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6', label: 'ថវិកា', desc: 'គ្រប់គ្រងចំណូល និងចំណាយ' },
  { icon: 'M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z', label: 'សន្និធិ', desc: 'តាមដានទ្រព្យសម្បត្តិ និងសម្ភារៈ' },
  { icon: 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z', label: 'ក្រុមកិត្តិយស', desc: 'តារាងកិត្តិយសសិស្ស' },
  { icon: 'M12 15a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM8.21 13.89L7 23l5-3 5 3-1.21-9.12', label: 'សញ្ញាបត្រ', desc: 'រចនា និងបោះពុម្ពសញ្ញាបត្រ' },
  { icon: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z', label: 'សិស្សមិនកំណត់', desc: 'គ្មានកំណត់ចំនួនសិស្ស' },
]

function goBack() {
  router.back()
}
</script>

<template>
  <div class="upgrade-page">
    <div class="upgrade-card">
      <button class="upgrade-back" @click="goBack">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        ត្រឡប់ក្រោយ
      </button>

      <div class="upgrade-lock">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="30" height="30">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0 1 10 0v4" />
        </svg>
      </div>

      <h1 class="upgrade-title">មុខងារនេះអាចប្រើបានតែក្នុងគម្រោង Pro</h1>
      <p class="upgrade-sub">
        សាលារបស់អ្នកកំពុងប្រើគម្រោង
        <b>{{ planStore.planMeta?.display_name || planStore.plan || 'Basic' }}</b>។
        សូមដំឡើងជា <b>Pro</b> ដើម្បីប្រើប្រាស់មុខងារពេញលេញ។
      </p>

      <div class="upgrade-features">
        <div v-for="f in proFeatures" :key="f.label" class="upgrade-feature">
          <span class="upgrade-feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" width="18" height="18">
              <path :d="f.icon" />
            </svg>
          </span>
          <span>
            <b>{{ f.label }}</b>
            <small>{{ f.desc }}</small>
          </span>
        </div>
      </div>

      <div class="upgrade-actions">
        <RouterLink v-if="isAdmin" to="/admin/billing" class="btn btn-primary">
          ដំឡើងទៅ Pro — $50/ខែ
        </RouterLink>
        <p v-else class="upgrade-contact">
          សូមទាក់ទងអ្នកគ្រប់គ្រងសាលារបស់អ្នក ដើម្បីដំឡើងគម្រោង។
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.upgrade-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: linear-gradient(135deg, #eef2ff 0%, #f8fafc 100%);
}
.upgrade-card {
  position: relative;
  width: 100%;
  max-width: 560px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 28px;
  padding: 40px;
  box-shadow: 0 24px 60px -20px rgba(15, 23, 42, 0.2);
  text-align: center;
}
.upgrade-back {
  position: absolute;
  top: 20px;
  left: 20px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 600;
  color: #64748b;
  background: none;
  border: none;
  cursor: pointer;
}
.upgrade-back:hover { color: #1e293b; }
.upgrade-lock {
  width: 72px;
  height: 72px;
  margin: 8px auto 20px;
  border-radius: 24px;
  background: #eef2ff;
  color: #4f46e5;
  display: flex;
  align-items: center;
  justify-content: center;
}
.upgrade-title {
  font-size: 22px;
  font-weight: 800;
  color: #0f172a;
  margin-bottom: 10px;
}
.upgrade-sub {
  font-size: 14px;
  color: #64748b;
  line-height: 1.6;
  margin-bottom: 28px;
}
.upgrade-features {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
  text-align: left;
  margin-bottom: 28px;
}
.upgrade-feature {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}
.upgrade-feature-icon {
  flex-shrink: 0;
  width: 34px;
  height: 34px;
  border-radius: 10px;
  background: #f1f5f9;
  color: #4f46e5;
  display: flex;
  align-items: center;
  justify-content: center;
}
.upgrade-feature b { display: block; font-size: 13px; color: #0f172a; }
.upgrade-feature small { font-size: 11.5px; color: #94a3b8; }
.upgrade-actions { display: flex; justify-content: center; }
.upgrade-contact { font-size: 13px; font-weight: 600; color: #64748b; }
@media (max-width: 520px) {
  .upgrade-features { grid-template-columns: 1fr; }
  .upgrade-card { padding: 28px 22px; }
}
</style>
