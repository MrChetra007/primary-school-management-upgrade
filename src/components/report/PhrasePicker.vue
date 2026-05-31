<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { PlusIcon, XMarkIcon } from '@heroicons/vue/24/outline'

const emit = defineEmits(['pick'])
const auth = useAuthStore()

const phrases = ref([])
const loading = ref(true)
const newPhrase = ref('')
const adding = ref(false)

async function loadPhrases() {
  loading.value = true
  const { data } = await supabase
    .from('teacher_phrases')
    .select('*')
    .eq('school_id', auth.schoolId)
    .eq('teacher_id', auth.teacherProfile.id)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true })
  phrases.value = data || []
  loading.value = false
}

async function addPhrase() {
  const text = newPhrase.value.trim()
  if (!text) return
  adding.value = true
  const { data, error } = await supabase
    .from('teacher_phrases')
    .insert({
      school_id: auth.schoolId,
      teacher_id: auth.teacherProfile.id,
      phrase_text: text,
      sort_order: phrases.value.length
    })
    .select()
    .single()
  if (!error && data) {
    phrases.value.push(data)
    newPhrase.value = ''
  }
  adding.value = false
}

async function deletePhrase(id) {
  const { error } = await supabase
    .from('teacher_phrases')
    .delete()
    .eq('id', id)
  if (!error) {
    phrases.value = phrases.value.filter(p => p.id !== id)
  }
}

function pick(text) {
  emit('pick', text)
}

onMounted(loadPhrases)
</script>

<template>
  <div class="phrase-picker">
    <div class="phrase-picker-header">
      <span class="phrase-picker-label">ឃ្លាប្រើញឹកញាប់</span>
      <div class="phrase-add-row">
        <input
          v-model="newPhrase"
          class="form-control form-control-sm phrase-input"
          placeholder="បន្ថែមឃ្លាថ្មី..."
          @keyup.enter="addPhrase"
        />
        <button
          class="btn btn-sm btn-primary"
          :disabled="!newPhrase.trim() || adding"
          @click="addPhrase"
        >
          <PlusIcon class="w-4 h-4" />
        </button>
      </div>
    </div>
    <div v-if="loading" class="phrase-loading">កំពុងផ្ទុក...</div>
    <div v-else-if="phrases.length === 0" class="phrase-empty">
      មិនទាន់មានឃ្លាទេ — សូមបន្ថែមឃ្លាខាងលើ
    </div>
    <div v-else class="phrase-chips">
      <div
        v-for="p in phrases"
        :key="p.id"
        class="phrase-chip"
        @click="pick(p.phrase_text)"
      >
        <span class="phrase-chip-text">{{ p.phrase_text }}</span>
        <button
          class="phrase-chip-remove"
          title="លុប"
          @click.stop="deletePhrase(p.id)"
        >
          <XMarkIcon class="w-3 h-3" />
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.phrase-picker {
  border: 1px solid var(--border-default);
  border-radius: 8px;
  padding: 12px;
  background: #fafbfc;
}

.phrase-picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 8px;
  flex-wrap: wrap;
}

.phrase-picker-label {
  font-size: 12px;
  font-weight: 700;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.phrase-add-row {
  display: flex;
  gap: 6px;
  align-items: center;
}

.phrase-input {
  width: 200px;
}

.phrase-loading,
.phrase-empty {
  font-size: 13px;
  color: var(--text-muted);
  padding: 8px 0;
}

.phrase-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.phrase-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 16px;
  background: #eef2ff;
  border: 1px solid #c7d2fe;
  color: #4338ca;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
  user-select: none;
}

.phrase-chip:hover {
  background: #e0e7ff;
  border-color: #a5b4fc;
}

.phrase-chip-text {
  line-height: 1.4;
}

.phrase-chip-remove {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  border: none;
  background: transparent;
  color: #818cf8;
  border-radius: 50%;
  cursor: pointer;
  padding: 0;
  flex-shrink: 0;
}

.phrase-chip-remove:hover {
  background: #c7d2fe;
  color: #3730a3;
}
</style>
