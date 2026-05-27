<script setup>
import { CalendarIcon, TrophyIcon } from '@heroicons/vue/24/outline'
</script>

<template>
  <div>
    <div class="page-header">
      <div>
        <h1 class="page-title">ពិន្ទុសិស្ស</h1>
        <p class="page-subtitle">បញ្ចូល និងគ្រប់គ្រងពិន្ទុប្រចាំខែ ឬពិន្ទុឆមាស</p>
      </div>
    </div>

    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:24px;">
      <!-- Monthly Scores -->
      <router-link to="/teacher/scores/monthly" class="card hover-card" style="text-decoration:none;">
        <div class="card-body" style="text-align:center; padding:48px 24px;">
          <CalendarIcon class="w-12 h-12 text-gray-400" style="margin-bottom:16px;" />
          <h2 style="font-size:20px; font-weight:800; color:var(--text-primary); margin-bottom:8px;">ពិន្ទុប្រចាំខែ</h2>
          <p style="color:var(--text-secondary); font-size:14px;">បញ្ចូលពិន្ទុប្រចាំខែសម្រាប់មុខវិជ្ជាទាំងអស់</p>
          <div class="btn btn-secondary" style="margin-top:24px;">បើកបញ្ចូលពិន្ទុប្រចាំខែ</div>
        </div>
      </router-link>

      <!-- Semester Exams -->
      <router-link to="/teacher/scores/semester" class="card hover-card" style="text-decoration:none;">
        <div class="card-body" style="text-align:center; padding:48px 24px;">
          <TrophyIcon class="w-12 h-12 text-gray-400" style="margin-bottom:16px;" />
          <h2 style="font-size:20px; font-weight:800; color:var(--text-primary); margin-bottom:8px;">ពិន្ទុប្រឡងឆមាស</h2>
          <p style="color:var(--text-secondary); font-size:14px;">កត់ត្រាលទ្ធផលប្រឡងចុងឆមាស</p>
          <div class="btn btn-primary" style="margin-top:24px;">បើកបញ្ចូលពិន្ទុឆមាស</div>
        </div>
      </router-link>

      <!-- Student Ranking -->
      <!-- <router-link to="/teacher/scores/ranking" class="card hover-card" style="text-decoration:none; grid-column: span 2;">
        <div class="card-body" style="text-align:center; padding:32px 24px; display:flex; align-items:center; justify-content:center; gap:24px;">
          <div style="background:var(--primary-color); padding:12px; border-radius:12px; color:white;">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="32" height="32">
              <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
            </svg>
          </div>
          <div style="text-align:left;">
            <h2 style="font-size:20px; font-weight:800; color:var(--text-primary); margin-bottom:4px;">ចំណាត់ថ្នាក់សិស្ស</h2>
            <p style="color:var(--text-secondary); font-size:14px;">មើលលំដាប់ពិន្ទុ និងមធ្យមភាគសិស្សក្នុងថ្នាក់</p>
          </div>
          <div class="btn btn-secondary" style="margin-left:24px;">មើលចំណាត់ថ្នាក់</div>
        </div>
      </router-link> -->
    </div>
  </div>
</template>

<style scoped>
.hover-card {
  transition: transform 0.2s, box-shadow 0.2s;
}
.hover-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-lg);
  border-color: var(--primary-color);
}
</style>
