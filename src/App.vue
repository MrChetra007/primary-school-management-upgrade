<script setup>
import { RouterView } from 'vue-router'
import ToastContainer from '@/components/shared/ToastContainer.vue'
import ConnectionStatus from '@/components/shared/ConnectionStatus.vue'
</script>

<template>
  <ConnectionStatus />
  <RouterView />
  <ToastContainer />
</template>
