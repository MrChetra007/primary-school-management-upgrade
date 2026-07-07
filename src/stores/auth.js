import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { useSchoolStore } from './school'

export const useAuthStore = defineStore('auth', () => {
  const session = ref(null)
  const profile = ref(null) // row from users table
  const teacherProfile = ref(null) // row from teachers table if applicable

  const isLoggedIn = computed(() => !!session.value)
  const role = computed(() => profile.value?.role ?? null)
  const userId = computed(() => session.value?.user?.id ?? null)
  
  const isSuperAdmin = computed(() => role.value === 'super_admin')
  const isAdmin = computed(() => role.value === 'admin')
  const isTeacher = computed(() => role.value === 'teacher')
  const isLibrarian = computed(() => role.value === 'librarian')
  const isParent = computed(() => role.value === 'parent')
  const schoolId = computed(() => profile.value?.school_id ?? null)

  async function fetchProfile(id) {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', id)
        .single()
      if (error) throw error
      
      // Security Check: Inactive users cannot access the app
      if (data?.status === 'inactive') {
        console.warn('AuthStore: Account deactivated. Blocking access.')
        await logout()
        return // Stop execution
      }

      profile.value = data
      
      // Load school information
      const schoolStore = useSchoolStore()
      if (data.school_id) {
        await schoolStore.fetchSchool(data.school_id)
      }

      // Every user has a teacher profile in Cambodia school system (Roadmap v8)
      const { data: tData } = await supabase
        .from('teachers')
        .select('*')
        .eq('user_id', id)
        .maybeSingle()
      teacherProfile.value = tData
      
      console.log('AuthStore: Profile loaded:', data)
      console.log('AuthStore: Teacher profile loaded:', tData)
      
    } catch (e) {
      console.error('AuthStore: Error fetching profile:', e)
    }
  }

  function handleAuthEvent(event, newSession) {
    if (event === 'INITIAL_SESSION' && session.value) {
      return
    }
    session.value = newSession
    if (newSession) {
      fetchProfile(newSession.user.id)
    } else {
      profile.value = null
      teacherProfile.value = null
    }
  }

  async function init() {
    console.log('AuthStore: Initializing...')
    if (session.value) return
    const { data } = await supabase.auth.getSession()
    session.value = data.session
    if (session.value) {
      console.log('AuthStore: Session found for', session.value.user.email)
      await fetchProfile(session.value.user.id)
    } else {
      console.log('AuthStore: No session found')
    }
  }

  async function login(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    session.value = data.session
    await fetchProfile(data.user.id)
    return profile.value?.role
  }

  async function logout() {
    await supabase.auth.signOut()
    session.value = null
    profile.value = null
    teacherProfile.value = null
    
    // Clear school info
    const schoolStore = useSchoolStore()
    schoolStore.clearSchool()
  }

  return { 
    session, 
    profile, 
    teacherProfile,
    isLoggedIn, 
    role, 
    userId, 
    isSuperAdmin,
    isAdmin,
    isTeacher,
    isLibrarian,
    isParent,
    schoolId,
    init, 
    handleAuthEvent,
    login, 
    logout 
  }
})
