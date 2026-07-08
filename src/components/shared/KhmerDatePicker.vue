<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import { GREGORIAN_MONTHS_KM, DAYS_OF_WEEK_KM, toKhmerNumber, toKhmerLunarDate } from "khmer-chhankitek-calendar";

const props = defineProps({
  modelValue: { type: String, default: "" },
  placeholder: { type: String, default: "ជ្រើសរើសកាលបរិច្ឆេទ" },
});

const emit = defineEmits(["update:modelValue"]);

const open = ref(false);
const viewDate = ref(new Date());
const pickerRef = ref(null);

const year = computed(() => viewDate.value.getFullYear());
const month = computed(() => viewDate.value.getMonth());

const khmerMonth = computed(() => GREGORIAN_MONTHS_KM[month.value]);
const khmerYear = computed(() => toKhmerNumber(year.value));

const selectedDate = computed(() => {
  if (!props.modelValue) return null;
  const d = new Date(props.modelValue + "T00:00:00");
  return isNaN(d.getTime()) ? null : d;
});

const lunarInfo = computed(() => {
  if (!selectedDate.value) return null;
  return toKhmerLunarDate(selectedDate.value);
});

const displayText = computed(() => {
  if (!selectedDate.value) return "";
  const d = selectedDate.value;
  const day = toKhmerNumber(d.getDate());
  const m = GREGORIAN_MONTHS_KM[d.getMonth()];
  const y = toKhmerNumber(d.getFullYear());
  return `ថ្ងៃទី${day} ខែ${m} ឆ្នាំ${y}`;
});

function daysInMonth(y, m) {
  return new Date(y, m + 1, 0).getDate();
}

function firstDayOfMonth(y, m) {
  return new Date(y, m, 1).getDay();
}

const calendarDays = computed(() => {
  const y = year.value;
  const m = month.value;
  const total = daysInMonth(y, m);
  const start = firstDayOfMonth(y, m);
  const days = [];
  for (let i = 0; i < start; i++) days.push(null);
  for (let i = 1; i <= total; i++) days.push(i);
  return days;
});

function isToday(day) {
  if (!day) return false;
  const t = new Date();
  return t.getFullYear() === year.value && t.getMonth() === month.value && t.getDate() === day;
}

function isSelected(day) {
  if (!day || !selectedDate.value) return false;
  return selectedDate.value.getFullYear() === year.value && selectedDate.value.getMonth() === month.value && selectedDate.value.getDate() === day;
}

function selectDay(day) {
  if (!day) return;
  const d = new Date(year.value, month.value, day);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  emit("update:modelValue", `${yyyy}-${mm}-${dd}`);
  open.value = false;
}

function prevMonth() {
  viewDate.value = new Date(year.value, month.value - 1, 1);
}

function nextMonth() {
  viewDate.value = new Date(year.value, month.value + 1, 1);
}

function goToday() {
  const t = new Date();
  viewDate.value = new Date(t.getFullYear(), t.getMonth(), 1);
  const yyyy = t.getFullYear();
  const mm = String(t.getMonth() + 1).padStart(2, "0");
  const dd = String(t.getDate()).padStart(2, "0");
  emit("update:modelValue", `${yyyy}-${mm}-${dd}`);
  open.value = false;
}

function toggle() {
  open.value = !open.value;
  if (open.value && selectedDate.value) {
    viewDate.value = new Date(selectedDate.value.getFullYear(), selectedDate.value.getMonth(), 1);
  }
}

function onClickOutside(e) {
  if (pickerRef.value && !pickerRef.value.contains(e.target)) {
    open.value = false;
  }
}

onMounted(() => document.addEventListener("click", onClickOutside));
onUnmounted(() => document.removeEventListener("click", onClickOutside));
</script>

<template>
  <div ref="pickerRef" class="khmer-date-picker">
    <div class="picker-input" :class="{ 'picker-input--open': open }" @click="toggle">
      <span v-if="displayText" class="picker-text">{{ displayText }}</span>
      <span v-else class="picker-placeholder">{{ placeholder }}</span>
      <svg class="picker-chevron" :class="{ 'picker-chevron--up': open }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
        <path d="M6 9l6 6 6-6" />
      </svg>
    </div>

    <div v-if="lunarInfo" class="picker-lunar-hint">
      <span class="lunar-text">{{ lunarInfo.lunarDateText }}</span>
    </div>

    <transition name="fade">
      <div v-if="open" class="picker-dropdown">
        <div class="picker-header">
          <button class="picker-nav" @click="prevMonth" type="button" aria-label="ខែមុន">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </button>
          <span class="picker-header-title">{{ khmerMonth }} {{ khmerYear }}</span>
          <button class="picker-nav" @click="nextMonth" type="button" aria-label="ខែបន្ទាប់">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M9 18l6-6-6-6" />
            </svg>
          </button>
        </div>

        <div class="picker-weekdays">
          <span v-for="d in DAYS_OF_WEEK_KM" :key="d" class="picker-weekday">{{ d.slice(0, 2) }}</span>
        </div>

        <div class="picker-grid">
          <div
            v-for="(day, i) in calendarDays"
            :key="i"
            class="picker-day"
            :class="{ 'picker-day--empty': !day, 'picker-day--today': isToday(day), 'picker-day--selected': isSelected(day) }"
            @click="selectDay(day)"
          >
            <span v-if="day">{{ toKhmerNumber(day) }}</span>
          </div>
        </div>

        <div class="picker-footer">
          <button class="picker-today-btn" type="button" @click="goToday">ថ្ងៃនេះ</button>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.khmer-date-picker {
  position: relative;
  width: 100%;
}

.picker-input {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 12px;
  border: 1px solid var(--border-default, #d1d5db);
  border-radius: 8px;
  font-size: 13px;
  color: var(--text-primary, #1f2937);
  background: white;
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s;
  user-select: none;
  min-height: 40px;
}
.picker-input:hover {
  border-color: var(--primary-500, #3b82f6);
}
.picker-input--open {
  border-color: var(--primary-500, #3b82f6);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.12);
}
.picker-text {
  flex: 1;
  font-weight: 500;
}
.picker-placeholder {
  flex: 1;
  color: var(--text-muted, #9ca3af);
}
.picker-chevron {
  flex-shrink: 0;
  color: var(--text-muted, #9ca3af);
  transition: transform 0.2s;
}
.picker-chevron--up {
  transform: rotate(180deg);
}

.picker-lunar-hint {
  margin-top: 6px;
  font-size: 12px;
  color: var(--text-muted, #6b7280);
  line-height: 1.4;
}
.lunar-text {
  font-style: italic;
}

.picker-dropdown {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  right: 0;
  z-index: 200;
  background: white;
  border: 1px solid var(--border-default, #d1d5db);
  border-radius: 10px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
  padding: 12px;
  min-width: 280px;
}

.picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}
.picker-nav {
  width: 32px;
  height: 32px;
  border-radius: 6px;
  border: none;
  background: transparent;
  color: var(--text-primary, #1f2937);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.15s;
}
.picker-nav:hover {
  background: var(--bg-secondary, #f3f4f6);
}
.picker-header-title {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-primary, #1f2937);
}

.picker-weekdays {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 2px;
  margin-bottom: 6px;
}
.picker-weekday {
  text-align: center;
  font-size: 11px;
  font-weight: 600;
  color: var(--text-muted, #9ca3af);
  padding: 4px 0;
}

.picker-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 2px;
}
.picker-day {
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-primary, #1f2937);
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
}
.picker-day:hover {
  background: var(--bg-secondary, #f3f4f6);
}
.picker-day--empty {
  cursor: default;
}
.picker-day--today {
  font-weight: 700;
  color: var(--primary-500, #3b82f6);
  background: rgba(59, 130, 246, 0.06);
}
.picker-day--selected {
  background: var(--primary-500, #1e5fa5);
  color: white;
  font-weight: 700;
}
.picker-day--selected:hover {
  background: var(--primary-600, #184d8a);
}

.picker-footer {
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid var(--border-default, #e5e7eb);
  display: flex;
  justify-content: center;
}
.picker-today-btn {
  background: transparent;
  border: none;
  font-size: 12px;
  font-weight: 600;
  color: var(--primary-500, #1e5fa5);
  cursor: pointer;
  padding: 6px 16px;
  border-radius: 6px;
  transition: background 0.15s;
  font-family: inherit;
}
.picker-today-btn:hover {
  background: rgba(30, 95, 165, 0.08);
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
