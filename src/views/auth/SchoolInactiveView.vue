<script setup>
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

async function logout() {
  await auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="inactive-page">
    <div class="inactive-card">
      <div class="inactive-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" width="42" height="42">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0 1 10 0v4" />
        </svg>
      </div>
      <h1 class="inactive-title">សាលារបស់អ្នកមិនអាចប្រើប្រាស់បានទេ</h1>
      <p class="inactive-desc">
        ការជាវរបស់សាលាមិនទាន់បានបង់ ឬបានផុតកំណត់។<br />
        សូមទាក់ទងអ្នកគ្រប់គ្រងសាលាដើម្បីបន្តការជាវ។
      </p>
      <button class="btn btn-primary" @click="logout">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
        </svg>
        ចាកចេញ
      </button>
    </div>
  </div>
</template>

<style scoped>
.inactive-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: linear-gradient(135deg, #fef2f2 0%, #f8fafc 100%);
}
.inactive-card {
  text-align: center;
  background: #fff;
  border-radius: 24px;
  padding: 56px 40px;
  box-shadow: var(--shadow-xl);
  max-width: 440px;
  width: 100%;
  border: 1px solid var(--border-default);
  animation: card-in 0.3s ease;
}
@keyframes card-in {
  from { opacity: 0; transform: scale(0.95); }
  to   { opacity: 1; transform: scale(1); }
}
.inactive-icon {
  width: 84px;
  height: 84px;
  margin: 0 auto 20px;
  border-radius: 24px;
  background: #fee2e2;
  color: #dc2626;
  display: flex;
  align-items: center;
  justify-content: center;
}
.inactive-title {
  font-size: 21px;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 12px;
  line-height: 1.4;
}
.inactive-desc {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.7;
  margin-bottom: 28px;
}
</style>
