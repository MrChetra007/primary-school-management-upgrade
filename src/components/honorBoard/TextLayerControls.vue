<script setup>
const props = defineProps({
  layer: { type: Object, required: true }
})
const emit = defineEmits(['update'])

function onText(e)     { emit('update', { text: e.target.value }) }
function onSize(e)     { emit('update', { fontSize: Number(e.target.value) }) }
function onColor(e)    { emit('update', { color: e.target.value }) }
function toggleBold()  { emit('update', { bold: !props.layer.bold }) }

// Preset colors for quick pick
const PRESET_COLORS = [
  '#8B0000', '#B22222', '#DC143C',  // reds
  '#00008B', '#1e40af', '#2563eb',  // blues
  '#14532d', '#166534', '#15803d',  // greens
  '#78350f', '#92400e', '#b45309',  // browns
  '#111827', '#374151', '#6b7280',  // grays
  '#ffffff', '#fef3c7', '#fdf2f8',  // lights
]
</script>

<template>
  <div class="controls">

    <!-- Text input -->
    <div class="ctrl-group">
      <label class="ctrl-label">ឈ្មោះ (លំដាប់ {{ layer.rank }})</label>
      <input
        class="ctrl-input"
        type="text"
        :value="layer.text"
        placeholder="បញ្ចូលឈ្មោះសិស្ស"
        @input="onText"
      />
    </div>

    <!-- Font size -->
    <div class="ctrl-group">
      <label class="ctrl-label">ទំហំអក្សរ: {{ layer.fontSize }}px</label>
      <input
        class="ctrl-range"
        type="range"
        min="10"
        max="48"
        :value="layer.fontSize"
        @input="onSize"
      />
    </div>

    <!-- Bold toggle -->
    <div class="ctrl-group row">
      <label class="ctrl-label">អក្សរដិត</label>
      <button
        class="bold-btn"
        :class="{ active: layer.bold }"
        @click="toggleBold"
      >
        <b>B</b>
      </button>
    </div>

    <!-- Color picker -->
    <div class="ctrl-group">
      <label class="ctrl-label">ពណ៌អក្សរ</label>
      <div class="color-row">
        <input class="color-native" type="color" :value="layer.color" @input="onColor" />
        <span class="color-val">{{ layer.color }}</span>
      </div>
      <div class="preset-grid">
        <button
          v-for="c in PRESET_COLORS"
          :key="c"
          class="preset-dot"
          :style="{ background: c, outline: layer.color === c ? '3px solid #8b5cf6' : 'none' }"
          @click="emit('update', { color: c })"
        />
      </div>
    </div>

    <!-- Preview -->
    <div class="ctrl-group">
      <label class="ctrl-label">មើលជាមុន</label>
      <div
        class="preview-text"
        :style="{
          fontSize:   layer.fontSize + 'px',
          color:      layer.color,
          fontWeight: layer.bold ? '700' : '400',
        }"
      >
        {{ layer.text || '(គ្មានឈ្មោះ)' }}
      </div>
    </div>

  </div>
</template>

<style scoped>
.controls {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.ctrl-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.ctrl-group.row {
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
}

.ctrl-label {
  font-size: 11px;
  font-weight: 700;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  font-family: 'Noto Sans Khmer', sans-serif;
}

.ctrl-input {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 13px;
  font-family: 'Khmer OS Muol', 'Noto Sans Khmer', sans-serif;
  outline: none;
  transition: border-color 0.15s;
}

.ctrl-input:focus { border-color: #8b5cf6; }

.ctrl-range {
  width: 100%;
  accent-color: #8b5cf6;
  cursor: pointer;
}

.bold-btn {
  width: 34px;
  height: 34px;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  background: #fff;
  cursor: pointer;
  font-size: 16px;
  transition: all 0.15s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.bold-btn.active {
  border-color: #8b5cf6;
  background: #ede9fe;
  color: #7c3aed;
}

.color-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.color-native {
  width: 40px;
  height: 32px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  padding: 0;
}

.color-val {
  font-size: 12px;
  color: #6b7280;
  font-family: monospace;
}

.preset-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.preset-dot {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 1px solid rgba(0,0,0,0.15);
  cursor: pointer;
  transition: transform 0.1s;
}

.preset-dot:hover { transform: scale(1.2); }

.preview-text {
  font-family: 'Khmer OS Muol', 'Noto Sans Khmer', sans-serif;
  min-height: 36px;
  padding: 8px;
  background: #f8fafc;
  border-radius: 8px;
  border: 1px dashed #e5e7eb;
  text-align: center;
  word-break: break-all;
  line-height: 1.5;
}
</style>