<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'

const router = useRouter()

const form = ref({
  email: '',
  password: '',
  full_name: '',
  role: 'teacher',
  school_id: ''
})

const schools = ref([])
const loading = ref(false)
const error = ref('')
const success = ref(false)
const showPassword = ref(false)

onMounted(async () => {
  const { data, error: err } = await supabase
    .from('schools')
    .select('id, name_khmer, name_english')
    .eq('status', 'active')
    .order('name_english')
  
  if (err) console.error('Error fetching schools:', err)
  else schools.value = data || []
})

async function handleRegister() {
  if (!form.value.email || !form.value.password || !form.value.full_name) {
    error.value = 'Please fill in all required fields.'
    return
  }

  if (form.value.role !== 'super_admin' && !form.value.school_id) {
    error.value = 'Please select a school.'
    return
  }

  error.value = ''
  loading.value = true
  
  try {
    const { data, error: err } = await supabase.functions.invoke('manage-user', {
      body: {
        action: 'create',
        payload: {
          email: form.value.email,
          password: form.value.password,
          full_name: form.value.full_name,
          role: form.value.role,
          school_id: form.value.role === 'super_admin' ? null : form.value.school_id
        }
      }
    })

    if (err) throw err
    if (data?.error) throw new Error(data.error)

    success.value = true
    setTimeout(() => {
      router.push('/login')
    }, 3000)
  } catch (err) {
    console.error('Registration error:', err)
    let errorMsg = 'Failed to create account.'
    
    // Try to extract the detailed error from the Edge Function response
    if (err.context) {
      try {
        const body = await err.context.json()
        errorMsg = body.error || err.message
      } catch (e) {
        errorMsg = err.message
      }
    } else {
      errorMsg = err.message
    }
    
    error.value = errorMsg
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-bg">
      <div class="login-blob blob-1"></div>
      <div class="login-blob blob-2"></div>
    </div>

    <div class="login-card">
      <div class="login-brand">
        <div class="login-logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
            <path d="M2 17l10 5 10-5"/>
            <path d="M2 12l10 5 10-5"/>
          </svg>
        </div>
        <div>
          <h1 class="login-title">Create Account</h1>
          <p class="login-subtitle">Join the school management system</p>
        </div>
      </div>

      <div v-if="success" class="success-message">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
          <polyline points="22 4 12 14.01 9 11.01"/>
        </svg>
        <div>
          <h3 class="font-bold">Account Created!</h3>
          <p>Redirecting to login...</p>
        </div>
      </div>

      <form v-else @submit.prevent="handleRegister" class="login-form">
        <div v-if="error" class="login-error">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <line x1="15" y1="9" x2="9" y2="15"/>
            <line x1="9" y1="9" x2="15" y2="15"/>
          </svg>
          {{ error }}
        </div>

        <div class="form-group">
          <label class="form-label">Full Name</label>
          <input v-model="form.full_name" type="text" class="form-input" placeholder="John Doe" required />
        </div>

        <div class="form-group">
          <label class="form-label">Email address</label>
          <input v-model="form.email" type="email" class="form-input" placeholder="admin@school.kh" required />
        </div>

        <div class="form-group">
          <label class="form-label">Password</label>
          <div class="input-icon-wrap">
            <input
              v-model="form.password"
              :type="showPassword ? 'text' : 'password'"
              class="form-input"
              placeholder="••••••••"
              required
            />
            <button type="button" class="input-toggle-pass" @click="showPassword = !showPassword">
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

        <div class="form-group">
          <label class="form-label">Role</label>
          <select v-model="form.role" class="form-input">
            <option value="super_admin">Super Admin (Platform)</option>
            <option value="admin">School Admin / Director</option>
            <option value="teacher">Teacher</option>
            <option value="librarian">Librarian</option>
          </select>
        </div>

        <div v-if="form.role !== 'super_admin'" class="form-group">
          <label class="form-label">Select School</label>
          <select v-model="form.school_id" class="form-input" required>
            <option value="" disabled>Choose a school...</option>
            <option v-for="school in schools" :key="school.id" :value="school.id">
              {{ school.name_english }} ({{ school.name_khmer }})
            </option>
          </select>
        </div>

        <button type="submit" class="login-submit" :disabled="loading">
          <svg v-if="loading" class="spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
          </svg>
          {{ loading ? 'Creating Account...' : 'Sign Up' }}
        </button>

        <div class="login-footer">
          Already have an account? 
          <router-link to="/login" class="link">Sign In</router-link>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
/* Reuse Login Styles */
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 50%, #0f172a 100%);
  padding: 40px 20px;
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

.blob-1 { width: 500px; height: 500px; background: #3b82f6; top: -150px; right: -100px; }
.blob-2 { width: 400px; height: 400px; background: #8b5cf6; bottom: -100px; left: -100px; }

.login-card {
  width: 100%;
  max-width: 480px;
  background: rgba(255, 255, 255, 0.97);
  backdrop-filter: blur(20px);
  border-radius: 24px;
  padding: 40px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
  z-index: 1;
}

.login-brand { display: flex; align-items: center; gap: 16px; margin-bottom: 32px; }
.login-logo {
  width: 52px; height: 52px;
  background: linear-gradient(135deg, #2563eb, #3b82f6);
  border-radius: 14px;
  display: flex; align-items: center; justify-content: center;
  color: white;
  box-shadow: 0 8px 16px rgba(59,130,246,0.3);
}
.login-logo svg { width: 28px; height: 28px; }

.login-title { font-size: 24px; font-weight: 800; color: #0f172a; }
.login-subtitle { font-size: 14px; color: #64748b; }

.login-form { display: flex; flex-direction: column; gap: 20px; }
.form-group { display: flex; flex-direction: column; gap: 6px; }
.form-label { font-size: 13px; font-weight: 600; color: #475569; }
.form-input {
  padding: 10px 14px;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
  background: white;
  font-size: 15px;
  transition: all 0.2s;
}
.form-input:focus { outline: none; border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); }

.input-icon-wrap { position: relative; }
.input-toggle-pass {
  position: absolute; right: 10px; top: 50%; transform: translateY(-50%);
  background: none; border: none; color: #94a3b8; cursor: pointer;
}
.input-toggle-pass svg { width: 16px; height: 16px; }

.login-submit {
  width: 100%; padding: 12px;
  background: linear-gradient(135deg, #2563eb, #3b82f6);
  color: white; font-weight: 700; border-radius: 12px;
  border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px;
  box-shadow: 0 4px 12px rgba(59,130,246,0.3);
  transition: all 0.2s;
}
.login-submit:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 6px 16px rgba(59,130,246,0.4); }

.login-error {
  display: flex; align-items: center; gap: 8px;
  padding: 12px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px;
  color: #b91c1c; font-size: 14px;
}
.login-error svg { width: 18px; height: 18px; }

.success-message {
  display: flex; flex-direction: column; align-items: center; text-align: center; gap: 16px;
  padding: 40px 0; color: #059669;
}
.success-message svg { width: 64px; height: 64px; }

.login-footer { text-align: center; font-size: 14px; color: #64748b; margin-top: 8px; }
.link { color: #2563eb; font-weight: 600; text-decoration: none; }
.link:hover { text-decoration: underline; }

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
