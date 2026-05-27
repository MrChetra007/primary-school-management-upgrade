<script setup>
import { ref, computed, onMounted, watch } from 'vue'
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
const selectedTemplateIndex = ref(1)   // 1-based: template1.jpg, template2.jpg …
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
// Default positions: rank1 top-center, rank2/3 mid row, rank4/5 bottom row
const DEFAULT_POSITIONS = [
  { x: 0.5,  y: 0.28 },  // rank 1
  { x: 0.25, y: 0.52 },  // rank 2
  { x: 0.75, y: 0.52 },  // rank 3
  { x: 0.25, y: 0.75 },  // rank 4
  { x: 0.75, y: 0.75 },  // rank 5
]

const layers = ref([])
const selectedLayerId = ref(null)

function initLayers() {
  layers.value = top5.value.slice(0, 5).map((student, i) => ({
    id:       i + 1,
    rank:     i + 1,
    text:     student.full_name || `សិស្សលំដាប់ ${i + 1}`,
    x:        DEFAULT_POSITIONS[i].x,   // fractional 0-1
    y:        DEFAULT_POSITIONS[i].y,
    fontSize: 18,
    color:    '#8B0000',
    bold:     true,
  }))
  // If fewer than 5 students, fill remaining slots as empty editable layers
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

// ─── Sidebar toggle (mobile) ───────────────────────────────────────────────
const showSidebar = ref(true)
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
      @toggle-sidebar="showSidebar = !showSidebar"
    />

    <div class="editor-body">

      <!-- ── Left Sidebar ─────────────────────────────────────────────────── -->
      <aside class="sidebar" :class="{ collapsed: !showSidebar }">

        <!-- Template Gallery -->
        <section class="sidebar-section">
          <div class="section-label">📄 គំរូ (Template)</div>
          <TemplateGallery
            :score-mode="scoreMode"
            :max-templates="maxTemplates"
            :selected-index="selectedTemplateIndex"
            :template-src-fn="templateSrc"
            @select="selectedTemplateIndex = $event"
          />
        </section>

        <!-- Text Layer Controls -->
        <section class="sidebar-section">
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
        </section>

      </aside>

      <!-- ── Canvas Area ────────────────────────────────────────────────────── -->
      <main class="canvas-area">
        <EditorCanvas
          ref="canvasRef"
          :template-src="activeTemplateSrc"
          :layers="layers"
          :selected-layer-id="selectedLayerId"
          @select-layer="selectLayer"
          @update-layer="({ id, patch }) => updateLayer(id, patch)"
        />
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

.editor-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* ── Sidebar ─────────────────────────────────────────────────────────────── */
.sidebar {
  width: 280px;
  min-width: 280px;
  background: #fff;
  border-right: 1px solid #e5e7eb;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0;
  transition: width 0.3s, min-width 0.3s;
}

.sidebar.collapsed {
  width: 0;
  min-width: 0;
  overflow: hidden;
}

.sidebar-section {
  padding: 16px;
  border-bottom: 1px solid #f1f5f9;
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
  align-items: center;
  justify-content: center;
  overflow: auto;
  padding: 24px;
}

/* ── Mobile ──────────────────────────────────────────────────────────────── */
@media (max-width: 768px) {
  .editor-body { flex-direction: column; }
  .sidebar {
    width: 100%;
    min-width: 100%;
    max-height: 300px;
    border-right: none;
    border-bottom: 1px solid #e5e7eb;
  }
  .sidebar.collapsed { max-height: 0; }
  .canvas-area { padding: 12px; }
}
</style>