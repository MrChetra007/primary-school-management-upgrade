import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router/index.js'
import { supabase } from '@/lib/supabase'
import App from './App.vue'
import './style.css'

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)

// ── Auth listener (registered EXACTLY ONCE, BEFORE mount) ──────────────
import { useAuthStore } from '@/stores/auth'
const auth = useAuthStore()
supabase.auth.onAuthStateChange((event, newSession) => {
  auth.handleAuthEvent(event, newSession)
})

app.use(router)
app.mount('#app')