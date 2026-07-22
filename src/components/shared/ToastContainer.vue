<script setup>
import { useToast } from '@/composables/useToast'
import { CheckIcon, XCircleIcon, ExclamationTriangleIcon, InformationCircleIcon } from '@heroicons/vue/24/outline'

const { toast } = useToast()
</script>

<template>
  <div class="toast-container">
    <div v-if="toast" class="toast" :class="`toast-${toast.type}`">
      <CheckIcon v-if="toast.type === 'success'" class="w-4 h-4" />
      <ExclamationTriangleIcon v-else-if="toast.type === 'warning'" class="w-4 h-4" />
      <InformationCircleIcon v-else-if="toast.type === 'info'" class="w-4 h-4" />
      <XCircleIcon v-else class="w-4 h-4" />
      {{ toast.msg }}
    </div>
  </div>
</template>
