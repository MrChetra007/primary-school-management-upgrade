<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { CheckIcon, XCircleIcon, UserGroupIcon } from '@heroicons/vue/24/outline'
import { useToast } from '@/composables/useToast'
import { isFemale } from '@/utils/gender'

const authStore = useAuthStore()

const { showToast } = useToast()
// State
const users = ref([])
const loading = ref(true)
const activeTab = ref('teacher') // teacher, admin, librarian
const showCreateModal = ref(false)
const showResetModal = ref(false)
const showRoleModal = ref(false)
const processing = ref(false)

// Step-based form state (Roadmap v8)
const createStep = ref(1)
const newUser = ref({
  // Account
  email: '',
  password: '',
  role: 'teacher',
  // Personal (Teacher Profile)
  full_name: '',
  gender: 'M',
  dob: '',
  phone_number: '',
  degree: '',
  address: '',
  profile_url: ''
})

const avatarFile = ref(null)
const avatarPreview = ref(null)

const resetData = ref({ userId: '', userName: '', newPassword: '' })
const roleData = ref({ userId: '', userName: '', currentRole: '', newRole: '' })

const filteredUsers = computed(() => {
  return users.value.filter(u => u.role === activeTab.value)
})

onMounted(fetchUsers)

async function fetchUsers() {
  loading.value = true

  const { data: usersData, error: usersError } = await supabase
    .from('users')
    .select('*')
    .order('created_at', { ascending: false })

  if (usersError) {
    showToast(usersError.message, 'error')
    loading.value = false
    return
  }

  const { data: teachersData, error: teachersError } = await supabase
    .from('teachers')
    .select('*')

  if (teachersError) {
    showToast(teachersError.message, 'error')
    loading.value = false
    return
  }

  // Merge: attach teacher profile to each user by user_id
  const teacherMap = {}
  teachersData.forEach(t => { teacherMap[t.user_id] = t })

  users.value = (usersData || []).map(u => ({
    ...u,
    teachers: teacherMap[u.id] ? [teacherMap[u.id]] : []
  }))

  console.log('========================================')
  console.log('USERS WITH TEACHER PROFILES:')
  console.log('========================================')
  users.value.forEach(u => {
    const t = u.teachers?.[0]
    console.log(`User ID: ${u.id} | Email: ${u.email} | Role: ${u.role} | Status: ${u.status}`)
    if (t) {
      console.log(`  └─ Teacher ID: ${t.id} | Name: ${t.full_name} | Gender: ${t.gender} | Phone: ${t.phone_number} | Degree: ${t.degree}`)
    } else {
      console.log(`  └─ No teacher profile found`)
    }
    console.log('---')
  })
  console.log(`Total: ${users.value.length} users`)
  console.log('========================================')

  loading.value = false;
}

async function handleCreateUser() {
  console.log('DEBUG: Starting staff registration...', newUser.value)
  
  if (!newUser.value.email || !newUser.value.password || !newUser.value.full_name) {
    showToast('Please fill all required fields', 'error')
    return
  }

  processing.value = true
  try {
    if (avatarFile.value) {
      console.log('DEBUG: Uploading staff photo...')
      newUser.value.profile_url = await uploadAvatar()
      console.log('DEBUG: Photo uploaded:', newUser.value.profile_url)
    }

    console.log('DEBUG: Calling manage-user edge function...')
    const { data, error } = await supabase.functions.invoke('manage-user', {
      body: {
        action: 'create',
        payload: { 
          ...newUser.value,
          school_id: authStore.schoolId
        }
      }
    })

    if (error) {
      console.error('DEBUG: Edge Function Error:', error)
      // Try to extract the custom error message from the response
      let errorMsg = 'Failed to create user'
      try {
        const body = await error.context.json()
        errorMsg = body.error || error.message
      } catch (e) {
        errorMsg = error.message
      }
      throw new Error(errorMsg)
    }

    console.log('DEBUG: Success!', data)
    showToast('User & Profile created successfully', 'success')
    closeCreateModal()
    await fetchUsers()
  } catch (err) {
    console.error('DEBUG: Registration failed:', err)
    showToast(err.message, 'error')
  } finally {
    processing.value = false
  }
}

async function toggleUserStatus(user) {
  const newStatus = user.status === 'active' ? 'inactive' : 'active'
  if (!confirm(`${newStatus === 'inactive' ? 'Block' : 'Unblock'} ${user.email}?`)) return

  processing.value = true
  try {
    const { error } = await supabase.rpc('admin_update_user_status', {
      p_user_id: user.id,
      p_status: newStatus
    })
    if (error) throw error
    showToast(`User ${newStatus}`, 'success')
    await fetchUsers()
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    processing.value = false
  }
}

async function handleDeleteUser(user) {
  if (!confirm(`PERMANENTLY DELETE ${user.email} and their teacher profile? This cannot be undone.`)) return

  processing.value = true
  try {
    const { error } = await supabase.functions.invoke('manage-user', {
      body: { action: 'delete', payload: { userId: user.id } }
    })
    if (error) throw error
    showToast('User deleted permanently', 'success')
    await fetchUsers()
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    processing.value = false
  }
}

async function handleResetPassword() {
  if (!resetData.value.newPassword) return
  processing.value = true
  try {
    const { error } = await supabase.functions.invoke('manage-user', {
      body: {
        action: 'reset_password',
        payload: { userId: resetData.value.userId, newPassword: resetData.value.newPassword }
      }
    })
    if (error) throw error
    showToast('Password updated', 'success')
    showResetModalState(false)
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    processing.value = false
  }
}

async function handleUpdateRole() {
  processing.value = true
  try {
    const { error } = await supabase.rpc('admin_update_user_role', {
      p_user_id: roleData.value.userId,
      p_role: roleData.value.newRole
    })
    if (error) throw error
    showToast('Role updated', 'success')
    showRoleModal.value = false
    await fetchUsers()
  } catch (err) {
    showToast(err.message, 'error')
  } finally {
    processing.value = false
  }
}

function openResetModal(user) {
  resetData.value = { userId: user.id, userName: user.teachers?.[0]?.full_name || user.email, newPassword: '' }
  showResetModal.value = true
}

function openRoleModal(user) {
  roleData.value = { userId: user.id, userName: user.teachers?.[0]?.full_name || user.email, currentRole: user.role, newRole: user.role }
  showRoleModal.value = true
}

function closeCreateModal() {
  showCreateModal.value = false
  createStep.value = 1
  newUser.value = { email: '', password: '', role: 'teacher', full_name: '', gender: 'M', dob: '', phone_number: '', degree: '', address: '', profile_url: '' }
  avatarFile.value = null
  avatarPreview.value = null
}

function handleFileSelect(e) {
  const file = e.target.files[0]
  if (!file) return
  avatarFile.value = file
  avatarPreview.value = URL.createObjectURL(file)
}

async function uploadAvatar() {
  const file = avatarFile.value
  const fileExt = file.name.split('.').pop()
  const fileName = `${Math.random().toString(36).substring(2)}.${fileExt}`
  const filePath = `avatars/${fileName}`

  const { error: uploadError } = await supabase.storage
    .from('teacher-profiles')
    .upload(filePath, file)

  if (uploadError) throw uploadError

  const { data } = supabase.storage
    .from('teacher-profiles')
    .getPublicUrl(filePath)

  return data.publicUrl
}

</script>

<template>
  <div class="users-view">

    <div class="page-header">
      <div>
        <h1 class="page-title">គ្រប់គ្រងគណនីបុគ្គលិក (Staff Accounts)</h1>
        <p class="page-subtitle">Manage system access. Every account is linked to a mandatory teacher profile (Roadmap (Roadmap v10)</p>
      </div>
      <button class="btn btn-primary" @click="showCreateModal = true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM20 8v6M23 11h-6"/></svg>
        បន្ថែមបុគ្គលិក (Add Staff)
      </button>
    </div>

    <div class="tabs">
      <button 
        v-for="role in ['teacher', 'admin', 'librarian']" 
        :key="role" 
        class="tab-item" 
        :class="{ active: activeTab === role }" 
        @click="activeTab = role"
      >
        {{ role === 'admin' ? 'Director/Admin' : role.charAt(0).toUpperCase() + role.slice(1) + 's' }}
      </button>
    </div>

    <div class="card main-table-card">
      <div v-if="loading" class="card-body">
        <div v-for="i in 5" :key="i" class="skeleton" style="height:60px; margin-bottom:12px; border-radius:8px;"></div>
      </div>

      <div v-else-if="filteredUsers.length === 0" class="empty-state">
        <UserGroupIcon class="w-12 h-12 text-gray-400" />
        <p class="empty-state-title">មិនមានបុគ្គលិកនៅក្នុងក្រុមនេះទេ</p>
      </div>

      <div v-else class="table-wrapper">
        <table class="user-table">
          <thead>
            <tr>
              <th>បុគ្គលិក (Staff)</th>
              <th>Email / Phone</th>
              <th>កម្រិតវប្បធម៌ (Degree)</th>
              <th>ស្ថានភាព (Status)</th>
              <th class="text-right">សកម្មភាព (Actions)</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="user in filteredUsers" :key="user.id" :class="{ 'inactive-row': user.status === 'inactive' }">
              <td>
                <div class="user-info">
                  <div v-if="user.teachers?.[0]?.profile_url" class="avatar-img">
                    <img :src="user.teachers[0].profile_url" alt="" />
                  </div>
                  <div v-else class="avatar" :class="user.role">{{ (user.teachers?.[0]?.full_name || user.email).charAt(0).toUpperCase() }}</div>
                  <div>
                    <div class="user-name">{{ user.teachers?.[0]?.full_name || user.email }}</div>
                    <div class="user-sub">{{ isFemale(user.teachers?.[0]?.gender) ? 'ស្រី (Female)' : 'ប្រុស (Male)' }}</div>
                  </div>
                </div>
              </td>
              <td>
                <div class="user-email">{{ user.email }}</div>
                <div class="user-sub">{{ user.teachers?.[0]?.phone_number || 'No phone' }}</div>
              </td>
              <td>
                <div class="font-khmer" style="font-size:13px;">{{ user.teachers?.[0]?.degree || '—' }}</div>
              </td>
              <td>
                <span class="badge" :class="user.status === 'active' ? 'badge-green' : 'badge-red'">
                  {{ user.status === 'active' ? 'សកម្ម' : 'ផ្អាក' }}
                </span>
              </td>
              <td class="text-right">
                <div class="action-buttons">
                  <button class="btn-icon-text" @click="openRoleModal(user)" title="Change Role">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
                    Role
                  </button>
                  <button class="btn-icon-text" @click="openResetModal(user)" title="Reset Password">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M21 2v6h-6M3 12a9 9 0 0 1 15-6.7L21 8M3 22v-6h6M21 12a9 9 0 0 1-15 6.7L3 16"/></svg>
                    Reset
                  </button>
                  <button class="btn-icon-text" :class="user.status === 'active' ? 'text-danger' : 'text-success'" @click="toggleUserStatus(user)">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <template v-if="user.status === 'active'">
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                      </template>
                      <template v-else>
                        <path d="M9 11V7a3 3 0 0 1 6 0v4" />
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                      </template>
                    </svg>
                    {{ user.status === 'active' ? 'Block' : 'Unblock' }}
                  </button>
                  <button class="btn-icon-text text-danger" @click="handleDeleteUser(user)" title="Delete Account">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="showCreateModal" class="modal-overlay" @click.self="closeCreateModal">
      <div class="modal" style="max-width: 700px;">
        <div class="modal-header">
          <h3 class="modal-title">ចុះឈ្មោះបុគ្គលិកថ្មី (Register New Staff)</h3>
          <button class="btn-close" @click="closeCreateModal">&times;</button>
        </div>
        
        <div class="modal-body overflow-y">
          <div class="avatar-upload-section">
            <div class="avatar-preview-wrapper" @click="$refs.fileInput.click()">
              <img v-if="avatarPreview" :src="avatarPreview" class="avatar-preview-img" />
              <div v-else class="avatar-placeholder">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="32" height="32"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
                <span>Upload Photo</span>
              </div>
              <input type="file" ref="fileInput" hidden accept="image/*" @change="handleFileSelect" />
            </div>
          </div>

          <div class="grid-2">
            <div class="section-column">
              <h4 class="section-title">ព័ត៌មានផ្ទាល់ខ្លួន (Personal Info)</h4>
              <div class="form-group">
                <label class="form-label">ឈ្មោះពេញ (Full Name) *</label>
                <input type="text" class="form-input" v-model="newUser.full_name" placeholder="Ex: SOK Chhetra" />
              </div>
              <div class="grid-2" style="gap:12px;">
                <div class="form-group">
                  <label class="form-label">ភេទ (Gender)</label>
                  <select class="form-select" v-model="newUser.gender">
                    <option value="M">ប្រុស (Male)</option>
                    <option value="F">ស្រី (Female)</option>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">ថ្ងៃខែឆ្នាំកំណើត (DOB)</label>
                  <input type="date" class="form-input" v-model="newUser.dob" />
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">លេខទូរស័ព្ទ (Phone)</label>
                <input type="text" class="form-input" v-model="newUser.phone_number" placeholder="012 345 678" />
              </div>
              <div class="form-group">
                <label class="form-label">កម្រិតវប្បធម៌ (Degree)</label>
                <input type="text" class="form-input" v-model="newUser.degree" placeholder="Ex: Bachelor of Education" />
              </div>
            </div>

            <div class="section-column">
              <h4 class="section-title">គណនីចូលប្រើ (Account Access)</h4>
              <div class="form-group">
                <label class="form-label">Email Address *</label>
                <input type="email" class="form-input" v-model="newUser.email" placeholder="email@school.com" />
              </div>
              <div class="form-group">
                <label class="form-label">Password *</label>
                <input type="password" class="form-input" v-model="newUser.password" placeholder="Min 6 characters" />
              </div>
              <div class="form-group">
                <label class="form-label">តួនាទី (User Role) *</label>
                <select class="form-select" v-model="newUser.role">
                  <option value="teacher">Teacher</option>
                  <option value="admin">Admin / Director</option>
                  <option value="librarian">Librarian</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">អាសយដ្ឋាន (Address)</label>
                <textarea class="form-input" v-model="newUser.address" rows="2" placeholder="Current living address"></textarea>
              </div>
            </div>
          </div>

          <div class="alert alert-info mt-4">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
            This will create an Auth account AND a Teacher profile simultaneously.
          </div>
        </div>

        <div class="modal-footer">
          <button class="btn btn-ghost" @click="closeCreateModal" :disabled="processing">បោះបង់</button>
          <button class="btn btn-primary" @click="handleCreateUser" :disabled="processing">
            {{ processing ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក (Register Staff)' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="showResetModal" class="modal-overlay" @click.self="showResetModal = false">
      <div class="modal modal-sm">
        <div class="modal-header"><h3 class="modal-title">Reset Password</h3></div>
        <div class="modal-body">
          <p class="mb-4">Resetting for <b>{{ resetData.userName }}</b></p>
          <input type="password" class="form-input" v-model="resetData.newPassword" placeholder="New Password" />
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showResetModal = false">Cancel</button>
          <button class="btn btn-primary" @click="handleResetPassword" :disabled="processing">Update</button>
        </div>
      </div>
    </div>

    <div v-if="showRoleModal" class="modal-overlay" @click.self="showRoleModal = false">
      <div class="modal modal-sm">
        <div class="modal-header"><h3 class="modal-title">Update Role</h3></div>
        <div class="modal-body">
          <p class="mb-4">Changing role for <b>{{ roleData.userName }}</b></p>
          <select class="form-select" v-model="roleData.newRole">
            <option value="teacher">Teacher</option>
            <option value="admin">Admin / Director</option>
            <option value="librarian">Librarian</option>
          </select>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="showRoleModal = false">Cancel</button>
          <button class="btn btn-primary" @click="handleUpdateRole" :disabled="processing">Change Role</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.users-view { display: flex; flex-direction: column; gap: 24px; }
.tabs { display: flex; gap: 12px; border-bottom: 1px solid var(--border-default); padding-bottom: 4px; }
.tab-item { padding: 12px 24px; font-weight: 600; font-size: 14px; border-bottom: 3px solid transparent; cursor: pointer; color: var(--text-secondary); transition: all 0.2s; }
.tab-item.active { color: var(--primary-color); border-bottom-color: var(--primary-color); }

.user-table { width: 100%; border-collapse: collapse; }
.user-table th { text-align: left; padding: 16px; font-size: 12px; font-weight: 800; color: var(--text-secondary); text-transform: uppercase; border-bottom: 2px solid var(--border-default); }
.user-table td { padding: 16px; border-bottom: 1px solid var(--border-default); vertical-align: middle; }

.user-info { display: flex; align-items: center; gap: 12px; }
.user-name { font-weight: 700; color: var(--text-primary); font-size: 14px; }
.user-sub { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
.user-email { font-size: 13px; font-weight: 600; color: var(--text-primary); }

.avatar { width: 40px; height: 40px; border-radius: 10px; background: #f1f5f9; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 16px; color: #64748b; }
.avatar.admin { background: #fee2e2; color: #dc2626; }
.avatar.teacher { background: #dcfce7; color: #16a34a; }
.avatar.librarian { background: #dbeafe; color: #2563eb; }

.action-buttons { display: flex; justify-content: flex-end; gap: 6px; }
.btn-icon-text { display: flex; align-items: center; gap: 6px; padding: 6px 10px; font-size: 11px; font-weight: 700; border-radius: 6px; border: 1px solid var(--border-default); background: white; cursor: pointer; }
.btn-icon-text:hover { background: #f8fafc; border-color: var(--text-muted); }

.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.section-title { font-size: 12px; font-weight: 800; text-transform: uppercase; color: var(--primary-color); margin-bottom: 16px; letter-spacing: 0.5px; border-bottom: 1px solid var(--primary-100); padding-bottom: 8px; }

.alert-info { background: #eff6ff; color: #1e40af; border: 1px solid #bfdbfe; padding: 12px; border-radius: 10px; display: flex; gap: 10px; align-items: center; font-size: 12px; }
.inactive-row { opacity: 0.6; grayscale: 1; }
.overflow-y { max-height: 70vh; overflow-y: auto; padding-right: 8px; }

.avatar-placeholder span { font-size: 11px; font-weight: 700; color: var(--text-muted); }
.avatar-img { width: 40px; height: 40px; border-radius: 10px; overflow: hidden; }
.avatar-img img { width: 100%; height: 100%; object-fit: cover; }
.avatar-upload-section { display: flex; justify-content: center; margin-bottom: 24px; }
.avatar-preview-wrapper { width: 100px; height: 100px; border-radius: 20px; border: 2px dashed var(--border-default); overflow: hidden; cursor: pointer; position: relative; transition: all 0.2s; }
.avatar-preview-wrapper:hover { border-color: var(--primary-color); background: var(--primary-50); }
.avatar-preview-img { width: 100%; height: 100%; object-fit: cover; }
.avatar-placeholder { width: 100%; height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; color: var(--text-muted); }

.modal-sm { max-width: 400px; }
.mb-6 { margin-bottom: 24px; }
</style>
