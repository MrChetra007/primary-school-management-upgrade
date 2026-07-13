import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router/index.js'
import { supabase } from '@/lib/supabase'
import App from './App.vue'
import './style.css'

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)
app.use(router)

// ── Auth listener (registered BEFORE mount) ──────────────
// Must register before app.mount() so INITIAL_SESSION fires
// before the router guard runs, preventing login-loop on PWA restart.
import { useAuthStore } from '@/stores/auth'
const auth = useAuthStore()
supabase.auth.onAuthStateChange((event, newSession) => {
  auth.handleAuthEvent(event, newSession)
})

app.mount('#app')
