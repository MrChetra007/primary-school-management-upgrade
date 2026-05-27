<script setup>
const props = defineProps({
  scoreMode:      { type: String, required: true },
  maxTemplates:   { type: Number, default: 3 },
  selectedIndex:  { type: Number, default: 1 },
  templateSrcFn:  { type: Function, required: true },
})

const emit = defineEmits(['select'])

// Track load errors per index
import { ref } from 'vue'
const errors = ref({})
function onError(i) { errors.value[i] = true }
</script>

<template>
  <div class="gallery">
    <div
      v-for="i in maxTemplates"
      :key="i"
      class="thumb-wrap"
      :class="{ active: selectedIndex === i }"
      @click="emit('select', i)"
    >
      <img
        v-if="!errors[i]"
        :src="templateSrcFn(i)"
        class="thumb-img"
        draggable="false"
        @error="onError(i)"
      />
      <div v-else class="thumb-blank">
        <span>ស</span>
      </div>
      <div class="thumb-label">គំរូ {{ i }}</div>
      <div v-if="selectedIndex === i" class="thumb-check">✓</div>
    </div>
  </div>
</template>

<style scoped>
.gallery {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.thumb-wrap {
  position: relative;
  width: 70px;
  cursor: pointer;
  border-radius: 8px;
  border: 2px solid #e5e7eb;
  overflow: hidden;
  transition: border-color 0.15s, transform 0.15s;
}

.thumb-wrap:hover   { border-color: #a78bfa; transform: scale(1.04); }
.thumb-wrap.active  { border-color: #8b5cf6; box-shadow: 0 0 0 3px #ede9fe; }

.thumb-img {
  width: 100%;
  aspect-ratio: 210/297;
  object-fit: cover;
  display: block;
}

.thumb-blank {
  width: 100%;
  aspect-ratio: 210/297;
  background: #f3f4f6;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  color: #d1d5db;
}

.thumb-label {
  text-align: center;
  font-size: 10px;
  color: #6b7280;
  padding: 3px 0;
  background: #fafafa;
  font-family: 'Noto Sans Khmer', sans-serif;
}

.thumb-check {
  position: absolute;
  top: 4px;
  right: 4px;
  width: 18px;
  height: 18px;
  background: #8b5cf6;
  color: white;
  border-radius: 50%;
  font-size: 11px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>