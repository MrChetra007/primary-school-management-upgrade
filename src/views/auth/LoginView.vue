<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const showPassword = ref(false)

async function handleLogin() {
  if (!email.value || !password.value) {
    error.value = 'Please enter your email and password.'
    return
  }
  error.value = ''
  loading.value = true
  try {
    const role = await auth.login(email.value, password.value)
    if (role === 'super_admin')   router.push('/super/dashboard')
    else if (role === 'admin')     router.push('/admin/academic-years')
    else if (role === 'teacher')   router.push('/teacher/dashboard')
    else if (role === 'librarian') router.push('/librarian/dashboard')
    else router.push('/unauthorized')
  } catch (err) {
    error.value = err.message || 'Login failed. Please check your credentials.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <!-- Background decoration -->
    <div class="login-bg">
      <div class="login-blob blob-1"></div>
      <div class="login-blob blob-2"></div>
    </div>

    <!-- Card -->
    <div class="login-card">
      <!-- Logo / brand -->
      <div class="login-brand">
        <div class="login-logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
            <path d="M2 17l10 5 10-5"/>
            <path d="M2 12l10 5 10-5"/>
          </svg>
        </div>
        <div>
          <h1 class="login-title">School Management</h1>
          <p class="login-subtitle">Sign in to your account to continue</p>
        </div>
      </div>

      <!-- Form -->
      <form @submit.prevent="handleLogin" class="login-form">
        <!-- Error -->
        <div v-if="error" class="login-error">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <line x1="15" y1="9" x2="9" y2="15"/>
            <line x1="9" y1="9" x2="15" y2="15"/>
          </svg>
          {{ error }}
        </div>

        <!-- Email -->
        <div class="form-group">
          <label class="form-label" for="login-email">Email address</label>
          <div class="input-icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2z"/>
              <polyline points="22,6 12,13 2,6"/>
            </svg>
            <input
              id="login-email"
              v-model="email"
              type="email"
              class="form-input"
              placeholder="admin@school.edu"
              autocomplete="email"
              :disabled="loading"
            />
          </div>
        </div>

        <!-- Password -->
        <div class="form-group">
          <label class="form-label" for="login-password">Password</label>
          <div class="input-icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
              <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
            <input
              id="login-password"
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              class="form-input"
              placeholder="••••••••"
              autocomplete="current-password"
              :disabled="loading"
            />
            <button
              type="button"
              class="input-toggle-pass"
              @click="showPassword = !showPassword"
              tabindex="-1"
            >
              <svg v-if="!showPassword" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                <circle cx="12" cy="12" r="3"/>
              </svg>
              <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/>
                <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/>
                <line x1="1" y1="1" x2="23" y2="23"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Submit -->
        <button
          type="submit"
          class="btn btn-primary btn-lg login-submit"
          :disabled="loading"
        >
          <svg v-if="loading" class="spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
          </svg>
          {{ loading ? 'Signing in…' : 'Sign in' }}
        </button>
      </form>

        <div class="login-footer" style="text-align: center; margin-top: 16px; font-size: 14px; color: #64748b;">
          Don't have an account? 
          <router-link to="/register" style="color: #2563eb; font-weight: 600; text-decoration: none;">Sign Up</router-link>
        </div>
      </div>
    </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 50%, #0f172a 100%);
  padding: 20px;
  position: relative;
  overflow: hidden;
}

.login-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.login-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.25;
}

.blob-1 {
  width: 500px;
  height: 500px;
  background: #3b82f6;
  top: -150px;
  right: -100px;
}

.blob-2 {
  width: 400px;
  height: 400px;
  background: #8b5cf6;
  bottom: -100px;
  left: -100px;
}

.login-card {
  width: 100%;
  max-width: 420px;
  background: rgba(255, 255, 255, 0.97);
  backdrop-filter: blur(20px);
  border-radius: 20px;
  padding: 36px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
  position: relative;
  z-index: 1;
  border: 1px solid rgba(255,255,255,0.2);
  animation: card-in 0.4s ease;
}

@keyframes card-in {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}

.login-brand {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 32px;
}

.login-logo {
  width: 52px;
  height: 52px;
  background: linear-gradient(135deg, #2563eb, #3b82f6);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 8px 16px rgba(59,130,246,0.35);
}

.login-logo svg {
  width: 26px;
  height: 26px;
  color: white;
}

.login-title {
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.2;
}

.login-subtitle {
  font-size: 13px;
  color: #64748b;
  margin-top: 2px;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.login-error {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
  color: #991b1b;
  font-size: 13px;
}

.login-error svg {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.input-icon-wrap {
  position: relative;
}

.input-icon-wrap > svg:first-child {
  position: absolute;
  left: 11px;
  top: 50%;
  transform: translateY(-50%);
  width: 15px;
  height: 15px;
  color: #94a3b8;
  pointer-events: none;
}

.input-icon-wrap .form-input {
  padding-left: 36px;
  padding-right: 40px;
}

.input-toggle-pass {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  cursor: pointer;
  color: #94a3b8;
  padding: 2px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: color 0.2s;
}
.input-toggle-pass:hover { color: #64748b; }
.input-toggle-pass svg { width: 15px; height: 15px; }

.login-submit {
  width: 100%;
  justify-content: center;
  margin-top: 4px;
  background: linear-gradient(135deg, #2563eb, #3b82f6);
  box-shadow: 0 4px 12px rgba(59,130,246,0.4);
  border: none;
  color: white;
  font-size: 15px;
  padding: 12px;
  border-radius: 10px;
  transition: all 0.2s;
}
.login-submit:hover:not(:disabled) {
  box-shadow: 0 6px 16px rgba(59,130,246,0.5);
  transform: translateY(-1px);
}

.spin {
  animation: spin 0.8s linear infinite;
}
@keyframes spin {
  from { transform: rotate(0deg); }
  to   { transform: rotate(360deg); }
}

.login-roles {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: center;
  margin-top: 24px;
  font-size: 12px;
  color: #94a3b8;
}
</style>
