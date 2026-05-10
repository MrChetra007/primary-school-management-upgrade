<script setup>
import { useRouter } from 'vue-router'
import { 
  School, 
  GraduationCap, 
  Users, 
  BookOpen, 
  ShieldCheck, 
  ArrowRight,
  CheckCircle2,
  Calendar,
  BarChart3
} from 'lucide-vue-next'

const router = useRouter()

const features = [
  {
    title: 'គ្រប់គ្រងវត្តមាន',
    desc: 'តាមដានវត្តមានសិស្ស និងគ្រូដោយស្វ័យប្រវត្តិជាមួយរបាយការណ៍លម្អិត។',
    icon: Calendar,
    color: 'text-emerald-600',
    bg: 'bg-emerald-50'
  },
  {
    title: 'ប្រព័ន្ធគ្រប់គ្រងពិន្ទុ',
    desc: 'បញ្ចូលពិន្ទុប្រចាំខែ និងឆមាស គណនាមធ្យមភាគ និងចំណាត់ថ្នាក់ដោយស្វ័យប្រវត្តិ។',
    icon: BarChart3,
    color: 'text-indigo-600',
    bg: 'bg-indigo-50'
  },
  {
    title: 'បណ្ណាល័យឌីជីថល',
    desc: 'គ្រប់គ្រងការខ្ចី-សងសៀវភៅ និងតាមដានសៀវភៅដែលហួសកាលកំណត់។',
    icon: BookOpen,
    color: 'text-amber-600',
    bg: 'bg-amber-50'
  },
  {
    title: 'សុខភាពសិស្ស',
    desc: 'កត់ត្រាការចាក់វ៉ាក់សាំង ការលូតលាស់ និងប្រវត្តិឈប់សម្រាកព្យាបាល។',
    icon: ShieldCheck,
    color: 'text-rose-600',
    bg: 'bg-rose-50'
  }
]
</script>

<template>
  <div class="min-h-screen bg-white">
    <!-- Nav -->
    <nav class="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between border-b border-slate-100">
      <div class="flex items-center gap-3">
        <div class="bg-indigo-600 p-2 rounded-xl">
          <GraduationCap class="w-6 h-6 text-white" />
        </div>
        <span class="text-xl font-bold text-slate-900 tracking-tight">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</span>
      </div>
      <button 
        @click="router.push('/login')"
        class="bg-indigo-600 text-white px-6 py-2.5 rounded-full font-semibold hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-200"
      >
        ចូលប្រើប្រាស់
      </button>
    </nav>

    <!-- Hero -->
    <section class="py-20 lg:py-32 px-6">
      <div class="max-w-7xl mx-auto grid lg:grid-cols-2 gap-16 items-center">
        <div>
          <div class="inline-flex items-center gap-2 bg-indigo-50 text-indigo-700 px-4 py-2 rounded-full text-sm font-bold mb-6">
            <CheckCircle2 class="w-4 h-4" />
            បច្ចេកវិទ្យាសម្រាប់អនាគតអប់រំ
          </div>
          <h1 class="text-5xl lg:text-6xl font-black text-slate-900 leading-[1.1] mb-8">
            ប្រព័ន្ធគ្រប់គ្រង <span class="text-indigo-600">សាលាបឋមសិក្សា</span> ទំនើប និងឆ្លាតវៃ
          </h1>
          <p class="text-xl text-slate-600 leading-relaxed mb-10 max-w-xl">
            ជួយសម្រួលដល់ការងាររដ្ឋបាល ការគ្រប់គ្រងសិស្ស គ្រូបង្រៀន និងការសិក្សា ឱ្យកាន់តែមានប្រសិទ្ធភាព និងតម្លាភាព។
          </p>
          <div class="flex flex-col sm:flex-row gap-4">
            <button 
              @click="router.push('/login')"
              class="group bg-slate-900 text-white px-8 py-4 rounded-2xl font-bold text-lg hover:bg-slate-800 transition-all flex items-center justify-center gap-2"
            >
              ចាប់ផ្តើមឥឡូវនេះ
              <ArrowRight class="w-5 h-5 group-hover:translate-x-1 transition-transform" />
            </button>
            <a 
              href="#features"
              class="bg-white border-2 border-slate-200 text-slate-900 px-8 py-4 rounded-2xl font-bold text-lg hover:border-indigo-600 hover:text-indigo-600 transition-all text-center"
            >
              ស្វែងយល់បន្ថែម
            </a>
          </div>
        </div>

        <div class="relative">
          <div class="absolute -inset-4 bg-indigo-600/5 blur-3xl rounded-[3rem]"></div>
          <div class="relative bg-slate-50 border border-slate-200 rounded-[2.5rem] p-4 shadow-2xl overflow-hidden aspect-square flex items-center justify-center">
             <div class="grid grid-cols-2 gap-4 w-full">
                <div v-for="i in 4" :key="i" class="aspect-video bg-white rounded-2xl border border-slate-100 shadow-sm animate-pulse"></div>
                <div class="col-span-2 aspect-video bg-white rounded-2xl border border-slate-100 shadow-sm animate-pulse"></div>
             </div>
             <!-- Overlay Stats Card -->
             <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white p-8 rounded-3xl shadow-2xl border border-slate-100 text-center">
                <div class="bg-indigo-100 w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <School class="w-8 h-8 text-indigo-600" />
                </div>
                <div class="text-3xl font-black text-slate-900 mb-1">១០០+</div>
                <div class="text-slate-500 font-medium">សាលារៀនប្រើប្រាស់</div>
             </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Features -->
    <section id="features" class="py-24 bg-slate-50 border-y border-slate-100">
      <div class="max-w-7xl mx-auto px-6 text-center">
        <h2 class="text-4xl font-black text-slate-900 mb-4">លក្ខណៈពិសេសរបស់ប្រព័ន្ធ</h2>
        <p class="text-slate-600 text-lg mb-16 max-w-2xl mx-auto">
          រចនាឡើងយ៉ាងសម្រិតសម្រាំងដើម្បីតម្រូវការជាក់ស្តែងរបស់សាលាបឋមសិក្សាក្នុងប្រទេសកម្ពុជា។
        </p>

        <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          <div 
            v-for="f in features" 
            :key="f.title"
            class="bg-white p-8 rounded-[2rem] border border-slate-100 shadow-sm hover:shadow-xl hover:-translate-y-2 transition-all group"
          >
            <div :class="[f.bg, f.color, 'w-14 h-14 rounded-2xl flex items-center justify-center mb-6 transition-transform group-hover:scale-110']">
              <component :is="f.icon" class="w-7 h-7" />
            </div>
            <h3 class="text-xl font-bold text-slate-900 mb-3">{{ f.title }}</h3>
            <p class="text-slate-500 leading-relaxed">{{ f.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Footer -->
    <footer class="py-12 border-t border-slate-100">
      <div class="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-6">
        <div class="flex items-center gap-3">
          <div class="bg-indigo-600 p-1.5 rounded-lg">
            <GraduationCap class="w-5 h-5 text-white" />
          </div>
          <span class="font-bold text-slate-900">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</span>
        </div>
        <div class="text-slate-500 text-sm">
          រក្សាសិទ្ធិគ្រប់យ៉ាង © ២០២៤ - សាលាបឋមសិក្សា
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Kantumruy+Pro:wght@100..700&display=swap');

:deep(body) {
  font-family: 'Kantumruy Pro', sans-serif;
}
</style>
