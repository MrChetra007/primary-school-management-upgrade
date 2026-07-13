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

  let _fetchPromise = null

  async function fetchProfile(id) {
    if (_fetchPromise) return _fetchPromise

    _fetchPromise = (async () => {
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
      } finally {
        _fetchPromise = null
      }
    })()

    return _fetchPromise
  }

  function backupSession(s) {
    if (s) {
      localStorage.setItem('auth_backup', JSON.stringify({ session: s, time: Date.now() }))
    }
  }

  function restoreBackup() {
    try {
      const raw = localStorage.getItem('auth_backup')
      if (!raw) return null
      const parsed = JSON.parse(raw)
      if (Date.now() - parsed.time > 7 * 24 * 60 * 60 * 1000) {
        localStorage.removeItem('auth_backup')
        return null
      }
      return parsed.session
    } catch {
      localStorage.removeItem('auth_backup')
      return null
    }
  }

  function clearBackup() {
    localStorage.removeItem('auth_backup')
  }

  function handleAuthEvent(event, newSession) {
    if (event === 'INITIAL_SESSION' || event === 'TOKEN_REFRESHED') {
      if (newSession) {
        session.value = newSession
        backupSession(newSession)
        fetchProfile(newSession.user.id)
      }
      return
    }

    if (event === 'SIGNED_OUT') {
      const backup = restoreBackup()
      if (backup) {
        supabase.auth.setSession({ access_token: backup.access_token, refresh_token: backup.refresh_token })
          .then(({ data, error }) => {
            if (data.session) {
              session.value = data.session
              backupSession(data.session)
              fetchProfile(data.session.user.id)
              return
            }
            clearBackup()
            session.value = null
            profile.value = null
            teacherProfile.value = null
          })
        return
      }
      session.value = null
      profile.value = null
      teacherProfile.value = null
      return
    }

    session.value = newSession
    if (newSession) {
      backupSession(newSession)
      fetchProfile(newSession.user.id)
    } else {
      profile.value = null
      teacherProfile.value = null
    }
  }

  async function init() {
    console.log('AuthStore: Initializing...')
    // If already fully loaded (session + profile), skip
    if (session.value && profile.value) return
    
    // If session is set but profile is still loading, wait for it
    if (session.value && _fetchPromise) {
      await _fetchPromise
      return
    }

    // No session yet — try to restore one
    if (!session.value) {
      const { data } = await supabase.auth.getSession()
      session.value = data.session
      if (session.value) {
        console.log('AuthStore: Session found for', session.value.user.email)
        backupSession(session.value)
      } else {
        const backup = restoreBackup()
        if (backup) {
          console.log('AuthStore: Restoring from backup')
          const { data: restored, error } = await supabase.auth.setSession({
            access_token: backup.access_token,
            refresh_token: backup.refresh_token
          })
          if (restored?.session) {
            session.value = restored.session
            backupSession(restored.session)
          } else {
            clearBackup()
          }
        }
        console.log('AuthStore: No session found')
      }
    }

    // If we have a session but no profile yet, fetch it
    if (session.value && !profile.value) {
      await fetchProfile(session.value.user.id)
    }
  }

  async function login(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    session.value = data.session
    backupSession(data.session)
    await fetchProfile(data.user.id)
    return profile.value?.role
  }

  async function logout() {
    await supabase.auth.signOut()
    session.value = null
    profile.value = null
    teacherProfile.value = null
    clearBackup()
    
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
