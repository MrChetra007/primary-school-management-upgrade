<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'

const props = defineProps({
  templateSrc:     { type: String,  required: true },
  layers:          { type: Array,   default: () => [] },
  selectedLayerId: { type: Number,  default: null },
})

const emit = defineEmits(['select-layer', 'update-layer'])

// ─── Canvas wrapper ref ────────────────────────────────────────────────────
const wrapperRef  = ref(null)
const imgLoaded   = ref(false)
const imgError    = ref(false)
const imgRef      = ref(null)

// ─── Drag state ────────────────────────────────────────────────────────────
const dragging    = ref(null)   // { layerId, startX, startY, origX, origY }

// ─── Template image ────────────────────────────────────────────────────────
function onImgLoad()  { imgLoaded.value = true;  imgError.value = false }
function onImgError() { imgError.value  = true;  imgLoaded.value = false }

watch(() => props.templateSrc, () => {
  imgLoaded.value = false
  imgError.value  = false
})

// ─── Drag handlers ─────────────────────────────────────────────────────────
function getEventXY(e) {
  if (e.touches) return { x: e.touches[0].clientX, y: e.touches[0].clientY }
  return { x: e.clientX, y: e.clientY }
}

function startDrag(e, layer) {
  e.preventDefault()
  emit('select-layer', layer.id)
  const { x, y } = getEventXY(e)
  dragging.value = {
    layerId: layer.id,
    startX:  x,
    startY:  y,
    origX:   layer.x,
    origY:   layer.y,
  }
}

function onMove(e) {
  if (!dragging.value || !wrapperRef.value) return
  e.preventDefault()
  const { x, y } = getEventXY(e)
  const rect = wrapperRef.value.getBoundingClientRect()
  const dx   = (x - dragging.value.startX) / rect.width
  const dy   = (y - dragging.value.startY) / rect.height
  const newX = Math.min(0.95, Math.max(0.05, dragging.value.origX + dx))
  const newY = Math.min(0.95, Math.max(0.05, dragging.value.origY + dy))
  emit('update-layer', { id: dragging.value.layerId, patch: { x: newX, y: newY } })
}

function endDrag() { dragging.value = null }

onMounted(() => {
  window.addEventListener('mousemove', onMove)
  window.addEventListener('mouseup',   endDrag)
  window.addEventListener('touchmove', onMove, { passive: false })
  window.addEventListener('touchend',  endDrag)
})

onUnmounted(() => {
  window.removeEventListener('mousemove', onMove)
  window.removeEventListener('mouseup',   endDrag)
  window.removeEventListener('touchmove', onMove)
  window.removeEventListener('touchend',  endDrag)
})

// ─── Export PNG via html2canvas ────────────────────────────────────────────
async function exportPNG() {
  // Deselect so no blue ring appears in export
  emit('select-layer', null)
  await nextTick()
  try {
    const html2canvas = (await import('html2canvas')).default
    const canvas = await html2canvas(wrapperRef.value, {
      useCORS:       true,
      allowTaint:    true,
      scale:         2,
      backgroundColor: '#ffffff',
    })
    const link    = document.createElement('a')
    link.download = 'honor-board.png'
    link.href     = canvas.toDataURL('image/png')
    link.click()
  } catch (err) {
    console.error('Export failed:', err)
    alert('មិនអាចទាញយកបាន។ សូមព្យាយាមម្ដងទៀត។')
  }
}

defineExpose({ exportPNG })
</script>

<template>
  <div class="canvas-outer">
    <div
      ref="wrapperRef"
      class="canvas-wrapper"
      :class="{ 'img-loaded': imgLoaded }"
    >
      <!-- Background template image -->
      <img
        v-if="!imgError"
        ref="imgRef"
        :src="templateSrc"
        class="template-img"
        draggable="false"
        @load="onImgLoad"
        @error="onImgError"
      />

      <!-- Fallback blank background -->
      <div v-if="imgError || !templateSrc" class="blank-bg">
        <span class="blank-hint">គ្មានគំរូ — ប្រើផ្ទៃស</span>
      </div>

      <!-- Loading shimmer -->
      <div v-if="!imgLoaded && !imgError && templateSrc" class="img-shimmer" />

      <!-- Draggable text layers -->
      <template v-if="imgLoaded || imgError">
        <div
          v-for="layer in layers"
          :key="layer.id"
          class="text-layer"
          :class="{
            selected:  selectedLayerId === layer.id,
            dragging:  dragging?.layerId === layer.id,
            'no-text': !layer.text
          }"
          :style="{
            left:      layer.x * 100 + '%',
            top:       layer.y * 100 + '%',
            fontSize:  layer.fontSize + 'px',
            color:     layer.color,
            fontWeight: layer.bold ? '700' : '400',
          }"
          @mousedown="e => startDrag(e, layer)"
          @touchstart="e => startDrag(e, layer)"
          @click.stop="emit('select-layer', layer.id)"
        >
          <span class="layer-text">{{ layer.text || `(លំដាប់ ${layer.rank})` }}</span>
          <div v-if="selectedLayerId === layer.id" class="drag-handle">⠿</div>
        </div>
      </template>

    </div>

    <p class="canvas-hint">អូសអត្ថបទដើម្បីផ្លាស់ប្ដូរទីតាំង • ចុចដើម្បីជ្រើសរើស</p>
  </div>
</template>

<style scoped>
.canvas-outer {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  width: 100%;
}

/* A4-ish ratio wrapper */
.canvas-wrapper {
  position: relative;
  width: 100%;
  max-width: 600px;
  aspect-ratio: 210 / 297;
  background: #fff;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 8px 32px rgba(0,0,0,0.18);
  user-select: none;
}

.template-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: fill;
  display: block;
  pointer-events: none;
}

.blank-bg {
  position: absolute;
  inset: 0;
  background: #fafafa;
  border: 2px dashed #d1d5db;
  display: flex;
  align-items: center;
  justify-content: center;
}

.blank-hint { color: #9ca3af; font-size: 13px; }

.img-shimmer {
  position: absolute;
  inset: 0;
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: shimmer 1.2s infinite;
}

@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* ── Text layers ─────────────────────────────────────────────────────────── */
.text-layer {
  position: absolute;
  transform: translate(-50%, -50%);
  cursor: grab;
  padding: 4px 8px;
  border-radius: 4px;
  border: 2px dashed transparent;
  transition: border-color 0.15s;
  white-space: nowrap;
  font-family: 'Khmer OS Muol', 'Noto Sans Khmer', sans-serif;
  line-height: 1.3;
  touch-action: none;
}

.text-layer:hover   { border-color: rgba(139, 92, 246, 0.4); background: rgba(255,255,255,0.3); }
.text-layer.selected { border-color: #8b5cf6; background: rgba(255,255,255,0.5); }
.text-layer.dragging { cursor: grabbing; opacity: 0.85; }
.text-layer.no-text  { opacity: 0.5; }

.layer-text { display: block; }

.drag-handle {
  position: absolute;
  top: -18px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 14px;
  color: #8b5cf6;
  cursor: grab;
  background: white;
  border-radius: 4px;
  padding: 0 4px;
  border: 1px solid #8b5cf6;
  line-height: 1.4;
}

.canvas-hint {
  font-size: 11px;
  color: #9ca3af;
  text-align: center;
}
</style>