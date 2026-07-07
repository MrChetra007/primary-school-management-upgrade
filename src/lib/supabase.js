import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

const customStorage = {
  getItem(key) {
    const val = localStorage.getItem(key)
    return val
  },
  setItem(key, value) {
    localStorage.setItem(key, value)
  },
  removeItem(key) {
    localStorage.removeItem(key)
  }
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: customStorage,
    storageKey: 'sb-auth-token',
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false
  }
})
