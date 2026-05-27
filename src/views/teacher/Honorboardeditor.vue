<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EditorCanvas from '@/components/honorBoard/EditorCanvas.vue'
import TemplateGallery from '@/components/honorBoard/TemplateGallery.vue'
import TextLayerControls from '@/components/honorBoard/TextLayerControls.vue'
import Toolbar from '@/components/honorBoard/Toolbar.vue'

const route  = useRoute()
const router = useRouter()

// ─── State passed from ScoresView via router ───────────────────────────────
const scoreMode  = ref(route.query.mode || 'monthly')
const top5       = ref(JSON.parse(route.query.students || '[]'))
const className  = ref(route.query.className || '')
const year       = ref(route.query.year || '')
const monthName  = ref(route.query.monthName || '')
const semester   = ref(route.query.semester || '')

// ─── Template selection ────────────────────────────────────────────────────
const selectedTemplateIndex = ref(1)
const MAX_MONTHLY_TEMPLATES  = 3
const MAX_SEMESTER_TEMPLATES = 2

const maxTemplates = computed(() =>
  scoreMode.value === 'monthly' ? MAX_MONTHLY_TEMPLATES : MAX_SEMESTER_TEMPLATES
)

function templateSrc(index) {
  const base = scoreMode.value === 'monthly'
    ? `/src/assets/honorboard-templates/template${index}.jpg`
    : `/src/assets/honorboard-templates/template_semester${index}.jpg`
  return base
}

const activeTemplateSrc = computed(() => templateSrc(selectedTemplateIndex.value))

// ─── Text layers ───────────────────────────────────────────────────────────
const DEFAULT_POSITIONS = [
  { x: 0.5,  y: 0.28 },
  { x: 0.25, y: 0.52 },
  { x: 0.75, y: 0.52 },
  { x: 0.25, y: 0.75 },
  { x: 0.75, y: 0.75 },
]

const layers = ref([])
const selectedLayerId = ref(null)

function initLayers() {
  layers.value = top5.value.slice(0, 5).map((student, i) => ({
    id:       i + 1,
    rank:     i + 1,
    text:     student.full_name || `សិស្សលំដាប់ ${i + 1}`,
    x:        DEFAULT_POSITIONS[i].x,
    y:        DEFAULT_POSITIONS[i].y,
    fontSize: 18,
    color:    '#8B0000',
    bold:     true,
  }))
  for (let i = top5.value.length; i < 5; i++) {
    layers.value.push({
      id:       i + 1,
      rank:     i + 1,
      text:     '',
      x:        DEFAULT_POSITIONS[i].x,
      y:        DEFAULT_POSITIONS[i].y,
      fontSize: 18,
      color:    '#8B0000',
      bold:     true,
    })
  }
}

onMounted(initLayers)

const selectedLayer = computed(() =>
  layers.value.find(l => l.id === selectedLayerId.value) || null
)

function updateLayer(id, patch) {
  const idx = layers.value.findIndex(l => l.id === id)
  if (idx !== -1) layers.value[idx] = { ...layers.value[idx], ...patch }
}

function selectLayer(id) { selectedLayerId.value = id }

// ─── Download ──────────────────────────────────────────────────────────────
const canvasRef = ref(null)

async function handleDownload() {
  if (canvasRef.value) await canvasRef.value.exportPNG()
}

// ─── Mobile controls accordion ─────────────────────────────────────────────
const showControls = ref(false)

function toggleControls() { showControls.value = !showControls.value }
</script>

<template>
  <div class="hb-editor">

    <!-- ── Top Toolbar ───────────────────────────────────────────────────── -->
    <Toolbar
      :score-mode="scoreMode"
      :class-name="className"
      :month-name="monthName"
      :semester="semester"
      :year="year"
      @back="router.back()"
      @download="handleDownload"
    />

    <!-- ── Template Gallery Header (horizontal strip) ────────────────────── -->
    <div class="template-header">
      <div class="template-header-inner">
        <span class="template-label">📄 គំរូ</span>
        <TemplateGallery
          :score-mode="scoreMode"
          :max-templates="maxTemplates"
          :selected-index="selectedTemplateIndex"
          :template-src-fn="templateSrc"
          @select="selectedTemplateIndex = $event"
        />
      </div>
    </div>

    <div class="editor-body">

      <!-- ── Desktop Sidebar (layer list + controls) ─────────────────────── -->
      <aside class="sidebar-desktop">
        <div class="sidebar-section">
          <div class="section-label">✏️ កែសម្រួលអត្ថបទ</div>
          <div class="layer-list">
            <div
              v-for="layer in layers"
              :key="layer.id"
              class="layer-chip"
              :class="{ active: selectedLayerId === layer.id }"
              @click="selectLayer(layer.id)"
            >
              <span class="rank-badge">{{ layer.rank }}</span>
              <span class="layer-name">{{ layer.text || '(គ្មានឈ្មោះ)' }}</span>
            </div>
          </div>

          <TextLayerControls
            v-if="selectedLayer"
            :layer="selectedLayer"
            @update="patch => updateLayer(selectedLayer.id, patch)"
          />
          <div v-else class="hint-text">ចុចលើអត្ថបទនៅលើ Canvas ដើម្បីកែសម្រួល</div>
        </div>
      </aside>

      <!-- ── Canvas Area ──────────────────────────────────────────────────── -->
      <main class="canvas-area">
        <EditorCanvas
          ref="canvasRef"
          :template-src="activeTemplateSrc"
          :layers="layers"
          :selected-layer-id="selectedLayerId"
          @select-layer="selectLayer"
          @update-layer="({ id, patch }) => updateLayer(id, patch)"
        />

        <!-- ── Mobile controls toggle ─────────────────────────────────────── -->
        <div class="mobile-controls-bar">
          <button class="mobile-ctrl-btn" @click="toggleControls">
            <span>✏️ កែសម្រួលអត្ថបទ</span>
            <svg
              :class="{ rotated: showControls }"
              viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
              width="16" height="16"
            >
              <path d="M6 9l6 6 6-6"/>
            </svg>
          </button>
        </div>

        <div v-show="showControls" class="mobile-controls-panel">
          <div class="layer-list">
            <div
              v-for="layer in layers"
              :key="layer.id"
              class="layer-chip"
              :class="{ active: selectedLayerId === layer.id }"
              @click="selectLayer(layer.id)"
            >
              <span class="rank-badge">{{ layer.rank }}</span>
              <span class="layer-name">{{ layer.text || '(គ្មានឈ្មោះ)' }}</span>
            </div>
          </div>
          <TextLayerControls
            v-if="selectedLayer"
            :layer="selectedLayer"
            @update="patch => updateLayer(selectedLayer.id, patch)"
          />
          <div v-else class="hint-text">ចុចលើអត្ថបទនៅលើ Canvas ដើម្បីកែសម្រួល</div>
        </div>
      </main>

    </div>
  </div>
</template>

<style scoped>
/* ── Layout ──────────────────────────────────────────────────────────────── */
.hb-editor {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: #f0f2f5;
  font-family: 'Noto Sans Khmer', sans-serif;
}

/* ── Template Header ─────────────────────────────────────────────────────── */
.template-header {
  background: #fff;
  border-bottom: 1px solid #e5e7eb;
  padding: 8px 16px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.template-header-inner {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: min-content;
}

.template-label {
  font-size: 12px;
  font-weight: 700;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  white-space: nowrap;
  flex-shrink: 0;
}

/* ── Editor body ─────────────────────────────────────────────────────────── */
.editor-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* ── Desktop Sidebar ─────────────────────────────────────────────────────── */
.sidebar-desktop {
  width: 280px;
  min-width: 280px;
  background: #fff;
  border-right: 1px solid #e5e7eb;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.sidebar-section {
  padding: 16px;
}

.section-label {
  font-size: 12px;
  font-weight: 700;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 12px;
}

/* ── Layer list ──────────────────────────────────────────────────────────── */
.layer-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 14px;
}

.layer-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  cursor: pointer;
  transition: all 0.15s;
  font-size: 13px;
}

.layer-chip:hover { background: #f8fafc; }
.layer-chip.active { border-color: #8b5cf6; background: #f5f3ff; }

.rank-badge {
  width: 22px;
  height: 22px;
  background: #8b5cf6;
  color: white;
  border-radius: 50%;
  font-size: 11px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.layer-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #374151;
}

.hint-text {
  font-size: 12px;
  color: #9ca3af;
  text-align: center;
  padding: 12px 0;
  line-height: 1.6;
}

/* ── Canvas area ─────────────────────────────────────────────────────────── */
.canvas-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  overflow: auto;
  padding: 24px;
}

/* ── Mobile controls ─────────────────────────────────────────────────────── */
.mobile-controls-bar,
.mobile-controls-panel {
  display: none;
}

/* ── Desktop ─────────────────────────────────────────────────────────────── */
@media (min-width: 769px) {
  .sidebar-desktop { display: flex; }
}

/* ── Mobile ──────────────────────────────────────────────────────────────── */
@media (max-width: 768px) {
  .sidebar-desktop { display: none; }

  .canvas-area {
    padding: 12px;
    justify-content: flex-start;
  }

  .mobile-controls-bar {
    display: flex;
    width: 100%;
    max-width: 600px;
    margin-top: 12px;
  }

  .mobile-ctrl-btn {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 10px 14px;
    background: #fff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 700;
    color: #374151;
    cursor: pointer;
    font-family: 'Noto Sans Khmer', sans-serif;
    transition: background 0.15s;
  }

  .mobile-ctrl-btn:hover { background: #f8fafc; }

  .mobile-ctrl-btn svg {
    transition: transform 0.2s;
  }

  .mobile-ctrl-btn svg.rotated {
    transform: rotate(180deg);
  }

  .mobile-controls-panel {
    display: block;
    width: 100%;
    max-width: 600px;
    background: #fff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 14px;
    margin-top: 8px;
  }
}
</style>
