<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { 
  LayoutDashboard, 
  School, 
  Users, 
  LogOut,
  Menu,
  X,
  ChevronRight,
  Settings,
  ShieldCheck
} from 'lucide-vue-next'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()

const isSidebarOpen = ref(false)

onMounted(() => {
  // Open sidebar by default only on desktop
  if (window.innerWidth >= 1024) {
    isSidebarOpen.value = true
  }
})

// Close sidebar on route change (mobile)
watch(() => route.path, () => {
  if (window.innerWidth < 1024) {
    isSidebarOpen.value = false
  }
})

const navigation = [
  { name: 'ផ្ទាំងគ្រប់គ្រង', href: '/super/dashboard', icon: LayoutDashboard },
  { name: 'បញ្ជីសាលារៀន', href: '/super/schools', icon: School },
  { name: 'អ្នកប្រើប្រាស់', href: '/super/users', icon: Users },
  { name: 'ការកំណត់', href: '/super/settings', icon: Settings },
]

const handleLogout = async () => {
  await auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex relative">
    <!-- Mobile Backdrop -->
    <transition
      enter-active-class="transition-opacity ease-linear duration-300"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity ease-linear duration-300"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div 
        v-if="isSidebarOpen" 
        @click="isSidebarOpen = false"
        class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-40 lg:hidden"
      ></div>
    </transition>

    <!-- Sidebar -->
    <aside 
      :class="[
        'bg-slate-900 text-white w-64 flex-shrink-0 transition-all duration-300 ease-in-out fixed inset-y-0 z-50 lg:relative lg:translate-x-0',
        isSidebarOpen ? 'translate-x-0' : '-translate-x-full lg:w-20'
      ]"
    >
      <div class="h-full flex flex-col">
        <!-- Logo -->
        <div class="p-6 flex items-center gap-3">
          <div class="bg-indigo-500 p-2 rounded-lg">
            <ShieldCheck class="w-6 h-6 text-white" />
          </div>
          <span v-if="isSidebarOpen" class="text-xl font-bold tracking-tight">SuperAdmin</span>
        </div>

        <!-- Nav -->
        <nav class="flex-1 px-4 py-4 space-y-2">
          <router-link
            v-for="item in navigation"
            :key="item.name"
            :to="item.href"
            :class="[
              'flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all group',
              route.path === item.href 
                ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-500/30' 
                : 'text-slate-400 hover:bg-slate-800 hover:text-white'
            ]"
          >
            <component :is="item.icon" class="w-5 h-5 flex-shrink-0" />
            <span v-if="isSidebarOpen" class="font-medium">{{ item.name }}</span>
          </router-link>
        </nav>

        <!-- User -->
        <div class="p-4 border-t border-slate-800">
          <div v-if="isSidebarOpen" class="mb-4 px-3">
            <p class="text-sm font-medium text-white truncate">{{ auth.profile?.full_name || 'Super Admin' }}</p>
            <p class="text-xs text-slate-500 truncate">{{ auth.session?.user?.email }}</p>
          </div>
          <button 
            @click="handleLogout"
            class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-slate-400 hover:bg-rose-500/10 hover:text-rose-500 transition-all group"
          >
            <LogOut class="w-5 h-5 flex-shrink-0" />
            <span v-if="isSidebarOpen" class="font-medium text-sm">ចាកចេញ</span>
          </button>
        </div>
      </div>
    </aside>

    <!-- Main Content -->
    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
      <!-- Topbar -->
      <header class="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-6 sticky top-0 z-40">
        <div class="flex items-center gap-4">
          <button @click="isSidebarOpen = !isSidebarOpen" class="p-2 hover:bg-slate-100 rounded-lg lg:hidden">
            <Menu v-if="!isSidebarOpen" class="w-6 h-6 text-slate-600" />
            <X v-else class="w-6 h-6 text-slate-600" />
          </button>
          
          <div class="flex items-center gap-2 text-sm text-slate-500">
            <span class="font-medium text-slate-900 capitalize">{{ route.name?.replace('super-', '') }}</span>
          </div>
        </div>

        <div class="flex items-center gap-4">
          <div class="flex items-center gap-2 bg-indigo-50 px-3 py-1.5 rounded-full">
            <div class="w-2 h-2 bg-indigo-500 rounded-full animate-pulse"></div>
            <span class="text-xs font-semibold text-indigo-700">Platform Online</span>
          </div>
        </div>
      </header>

      <!-- Scrollable Area -->
      <main class="flex-1 overflow-y-auto p-6">
        <div class="max-w-7xl mx-auto">
          <router-view v-slot="{ Component }">
            <transition 
              name="fade" 
              mode="out-in"
              enter-active-class="transition duration-200 ease-out"
              enter-from-class="opacity-0 translate-y-4"
              enter-to-class="opacity-100 translate-y-0"
              leave-active-class="transition duration-150 ease-in"
              leave-from-class="opacity-100 translate-y-0"
              leave-to-class="opacity-0 translate-y-4"
            >
              <component :is="Component" />
            </transition>
          </router-view>
        </div>
      </main>
    </div>
  </div>
</template>

<style scoped>
/* Temporarily disabled @apply for debugging */
.router-link-active {
  background-color: #4f46e5;
  color: white;
}
</style>
