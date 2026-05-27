<script setup>
defineProps({
  scoreMode: { type: String, default: 'monthly' },
  className: { type: String, default: '' },
  monthName: { type: String, default: '' },
  semester:  { type: String, default: '' },
  year:      { type: String, default: '' },
})

const emit = defineEmits(['back', 'download', 'toggle-sidebar'])
</script>

<template>
  <header class="toolbar">

    <!-- Left: back + title -->
    <div class="toolbar-left">
      <button class="icon-btn" @click="emit('back')" title="ត្រឡប់ក្រោយ">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <path d="M19 12H5M12 5l-7 7 7 7"/>
        </svg>
      </button>
      <button class="icon-btn sidebar-toggle" @click="emit('toggle-sidebar')" title="បង្ហាញ/លាក់ Sidebar">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/>
        </svg>
      </button>
      <div class="title-block">
        <span class="title-main">តារាងកិត្តិយស</span>
        <span class="title-sub">
          {{ className }}
          <template v-if="scoreMode === 'monthly'"> · ខែ{{ monthName }}</template>
          <template v-else> · ឆមាសទី{{ semester }}</template>
          · {{ year }}
        </span>
      </div>
    </div>

    <!-- Right: download -->
    <div class="toolbar-right">
      <button class="btn-download" @click="emit('download')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
        </svg>
        ទាញយក PNG
      </button>
    </div>

  </header>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  background: #fff;
  border-bottom: 1px solid #e5e7eb;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06);
  z-index: 10;
  gap: 12px;
  font-family: 'Noto Sans Khmer', sans-serif;
}

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.icon-btn {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  background: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #374151;
  flex-shrink: 0;
  transition: background 0.15s;
}

.icon-btn:hover { background: #f3f4f6; }

.title-block {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.title-main {
  font-size: 15px;
  font-weight: 700;
  color: #1e293b;
  white-space: nowrap;
}

.title-sub {
  font-size: 11px;
  color: #9ca3af;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.toolbar-right { flex-shrink: 0; }

.btn-download {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: #8b5cf6;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  font-family: 'Noto Sans Khmer', sans-serif;
  transition: background 0.15s;
  white-space: nowrap;
}

.btn-download:hover { background: #7c3aed; }

@media (max-width: 500px) {
  .sidebar-toggle { display: none; }
  .title-sub      { display: none; }
}
</style>