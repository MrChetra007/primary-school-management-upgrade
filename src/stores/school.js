import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'

export const useSchoolStore = defineStore('school', () => {
  const schoolId = ref(localStorage.getItem('current_school_id') || null)
  const schoolName = ref(localStorage.getItem('current_school_name') || null)
  const schoolCode = ref(localStorage.getItem('current_school_code') || null)
  const logoUrl = ref(localStorage.getItem('current_school_logo') || null)

  async function fetchSchool(id) {
    if (!id) return
    
    try {
      const { data, error } = await supabase
        .from('schools')
        .select('*')
        .eq('id', id)
        .single()
      
      if (error) throw error
      
      schoolId.value = data.id
      schoolName.value = data.name_khmer
      schoolCode.value = data.school_code
      logoUrl.value = data.logo_url
      
      localStorage.setItem('current_school_id', data.id)
      localStorage.setItem('current_school_name', data.name_khmer)
      localStorage.setItem('current_school_code', data.school_code)
      if (data.logo_url) localStorage.setItem('current_school_logo', data.logo_url)
      
    } catch (e) {
      console.error('SchoolStore: Error fetching school info:', e)
    }
  }

  function clearSchool() {
    schoolId.value = null
    schoolName.value = null
    schoolCode.value = null
    logoUrl.value = null
    localStorage.removeItem('current_school_id')
    localStorage.removeItem('current_school_name')
    localStorage.removeItem('current_school_code')
    localStorage.removeItem('current_school_logo')
  }

  return {
    schoolId,
    schoolName,
    schoolCode,
    logoUrl,
    fetchSchool,
    clearSchool
  }
})
