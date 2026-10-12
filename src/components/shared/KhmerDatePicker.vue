<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from "vue";
import { GREGORIAN_MONTHS_KM, DAYS_OF_WEEK_KM, toKhmerNumber, toKhmerLunarDate } from "khmer-chhankitek-calendar";

const props = defineProps({
  modelValue: { type: String, default: "" },
  placeholder: { type: String, default: "ជ្រើសរើសកាលបរិច្ឆេទ" },
});

const emit = defineEmits(["update:modelValue"]);

const open = ref(false);
const viewDate = ref(new Date());
const pickerRef = ref(null);
const dropdownRef = ref(null);
const dropUp = ref(false);
const hAlign = ref("left");

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
  positionDropdown();
}

function nextMonth() {
  viewDate.value = new Date(year.value, month.value + 1, 1);
  positionDropdown();
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

function clearValue() {
  emit("update:modelValue", "");
}

async function positionDropdown() {
  await nextTick();
  const el = pickerRef.value;
  const dd = dropdownRef.value;
  if (!el || !dd) return;
  const rect = el.getBoundingClientRect();
  const ddH = dd.offsetHeight || 340;
  const ddW = dd.offsetWidth || 300;
  const spaceBelow = window.innerHeight - rect.bottom;
  const spaceAbove = rect.top;
  dropUp.value = spaceBelow < ddH + 12 && spaceAbove > spaceBelow;
  hAlign.value = window.innerWidth - rect.left < ddW + 12 ? "right" : "left";
}

function toggle() {
  open.value = !open.value;
  if (open.value) {
    if (selectedDate.value) {
      viewDate.value = new Date(selectedDate.value.getFullYear(), selectedDate.value.getMonth(), 1);
    }
    positionDropdown();
  }
}

function onClickOutside(e) {
  if (pickerRef.value && !pickerRef.value.contains(e.target)) {
    open.value = false;
  }
}

function onReposition() {
  if (open.value) positionDropdown();
}

onMounted(() => {
  document.addEventListener("click", onClickOutside);
  window.addEventListener("resize", onReposition);
  window.addEventListener("scroll", onReposition, true);
});
onUnmounted(() => {
  document.removeEventListener("click", onClickOutside);
  window.removeEventListener("resize", onReposition);
  window.removeEventListener("scroll", onReposition, true);
});
</script>

<template>
  <div ref="pickerRef" class="khmer-date-picker">
    <div class="picker-input" :class="{ 'picker-input--open': open }" @click="toggle">
      <svg class="picker-cal-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="16" height="16">
        <rect x="3" y="4.5" width="18" height="16" rx="2.5" />
        <path d="M3 9h18M8 2.5v4M16 2.5v4" stroke-linecap="round" />
      </svg>
      <span v-if="displayText" class="picker-text">{{ displayText }}</span>
      <span v-else class="picker-placeholder">{{ placeholder }}</span>

      <button
        v-if="selectedDate"
        class="picker-clear"
        type="button"
        aria-label="សម្អាតកាលបរិច្ឆេទ"
        @click.stop="clearValue"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
          <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round" />
        </svg>
      </button>

      <svg class="picker-chevron" :class="{ 'picker-chevron--up': open }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
        <path d="M6 9l6 6 6-6" />
      </svg>
    </div>

    <div v-if="lunarInfo" class="picker-lunar-hint">
      <span class="lunar-text">{{ lunarInfo.lunarDateText }}</span>
    </div>

    <transition name="fade">
      <div
        v-if="open"
        ref="dropdownRef"
        class="picker-dropdown"
        :class="{ 'picker-dropdown--up': dropUp, 'picker-dropdown--right': hAlign === 'right' }"
      >
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
          <button class="picker-action" type="button" @click="goToday">ថ្ងៃនេះ</button>
          <button v-if="selectedDate" class="picker-action picker-action--muted" type="button" @click.stop="clearValue">សម្អាត</button>
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
  background: var(--bg-card, #fff);
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s;
  user-select: none;
  min-height: 40px;
}
.picker-input:hover {
  border-color: var(--primary-500, #4a7fa5);
}
.picker-input--open {
  border-color: var(--primary-500, #4a7fa5);
  box-shadow: 0 0 0 3px rgba(74, 127, 165, 0.15);
}
.picker-cal-icon {
  flex-shrink: 0;
  color: var(--primary-500, #4a7fa5);
}
.picker-text {
  flex: 1;
  font-weight: 500;
}
.picker-placeholder {
  flex: 1;
  color: var(--text-muted, #9ca3af);
}
.picker-clear {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border: none;
  border-radius: 999px;
  background: var(--gray-100, #f3f4f6);
  color: var(--text-muted, #6b7280);
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
}
.picker-clear:hover {
  background: var(--bg-danger, #fff5f5);
  color: var(--color-danger, #9b2c2c);
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
  z-index: 200;
  width: 300px;
  max-width: calc(100vw - 24px);
  background: var(--bg-card, #fff);
  border: 1px solid var(--border-default, #d1d5db);
  border-radius: 14px;
  box-shadow: 0 12px 40px rgba(15, 23, 42, 0.18);
  padding: 14px;
}
.picker-dropdown--up {
  top: auto;
  bottom: calc(100% + 6px);
}
.picker-dropdown--right {
  left: auto;
  right: 0;
}

.picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.picker-nav {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  border: none;
  background: transparent;
  color: var(--text-primary, #1f2937);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.15s, color 0.15s;
}
.picker-nav:hover {
  background: var(--primary-50, #f0f4f8);
  color: var(--primary-700, #2c5282);
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
  color: var(--text-secondary, #4b5563);
  padding: 4px 0;
}

.picker-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 3px;
}
.picker-day {
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 9px;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-primary, #1f2937);
  cursor: pointer;
  transition: background 0.15s, color 0.15s, box-shadow 0.15s;
}
.picker-day:hover {
  background: var(--primary-50, #f0f4f8);
  color: var(--primary-700, #2c5282);
}
.picker-day--empty {
  cursor: default;
}
.picker-day--empty:hover {
  background: transparent;
}
.picker-day--today {
  font-weight: 700;
  color: var(--primary-700, #2c5282);
  box-shadow: inset 0 0 0 1.5px var(--primary-500, #4a7fa5);
}
.picker-day--selected {
  background: var(--primary-500, #4a7fa5);
  color: #fff;
  font-weight: 700;
  box-shadow: 0 2px 8px rgba(74, 127, 165, 0.35);
}
.picker-day--selected:hover {
  background: var(--primary-700, #2c5282);
  color: #fff;
}

.picker-footer {
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid var(--border-default, #e5e7eb);
  display: flex;
  justify-content: space-between;
  gap: 8px;
}
.picker-action {
  flex: 1;
  border: none;
  font-size: 12px;
  font-weight: 600;
  color: var(--primary-700, #2c5282);
  background: var(--primary-50, #f0f4f8);
  cursor: pointer;
  padding: 8px 16px;
  border-radius: 9px;
  transition: background 0.15s;
  font-family: inherit;
}
.picker-action:hover {
  background: var(--primary-100, #d9e8f5);
}
.picker-action--muted {
  color: var(--text-secondary, #4b5563);
  background: var(--gray-100, #f3f4f6);
}
.picker-action--muted:hover {
  background: var(--gray-200, #e5e7eb);
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
