<script setup>
import { useRouter } from 'vue-router'
import { ref, onMounted } from 'vue'
import {
  GraduationCap,
  ArrowRight,
  CheckCircle2,
  Calendar,
  BarChart3,
  BookOpen,
  ShieldCheck,
  Users,
  School,
  ChevronDown,
  Mail,
  Send,
  Facebook,
  Star,
  Zap,
  Globe
} from 'lucide-vue-next'

const router = useRouter()

const visible = ref(false)
onMounted(() => setTimeout(() => (visible.value = true), 100))

const features = [
  {
    title: 'គ្រប់គ្រងវត្តមាន',
    desc: 'តាមដានវត្តមានសិស្ស និងគ្រូដោយស្វ័យប្រវត្តិ។ ប្រព័ន្ធចូលធ្វើការ ស្វ័យប្រវត្តិ ស្គាល់ពេលមកយឺត ជាមួយរបាយការណ៍ប្រចាំខែ។',
    icon: Calendar,
    color: 'text-emerald-600',
    bg: 'bg-emerald-50',
    border: 'border-emerald-100'
  },
  {
    title: 'ប្រព័ន្ធពិន្ទុ',
    desc: 'បញ្ចូលពិន្ទុប្រចាំខែ និងឆមាស គណនាមធ្យមភាគ និងចំណាត់ថ្នាក់ ក្នុងថ្នាក់ ដោយស្វ័យប្រវត្តិ។ អាចបោះពុម្ព PDF បាន។',
    icon: BarChart3,
    color: 'text-indigo-600',
    bg: 'bg-indigo-50',
    border: 'border-indigo-100'
  },
  {
    title: 'បណ្ណាល័យឌីជីថល',
    desc: 'គ្រប់គ្រងការខ្ចី-សងសៀវភៅ តាមដានសៀវភៅហួសកាលកំណត់ និងបង្ហាញការជូនដំណឹង។',
    icon: BookOpen,
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    border: 'border-amber-100'
  },
  {
    title: 'សុខភាពសិស្ស',
    desc: 'កត់ត្រាការចាក់វ៉ាក់សាំង ការលូតលាស់ ការត្រួតពិនិត្យ និងប្រវត្តិព្យាបាល របស់សិស្ស។',
    icon: ShieldCheck,
    color: 'text-rose-600',
    bg: 'bg-rose-50',
    border: 'border-rose-100'
  },
  {
    title: 'ព័ត៌មានអ្នកដឹកនាំ',
    desc: 'ឪពុកម្តាយ អាចមើលព័ត៌មានកូន — វត្តមាន ពិន្ទុ សុខភាព — បានគ្រប់ពេល តាមទូរស័ព្ទ។',
    icon: Users,
    color: 'text-purple-600',
    bg: 'bg-purple-50',
    border: 'border-purple-100'
  },
  {
    title: 'ថវិកា និងសម្ភារៈ',
    desc: 'តាមដានចំណូល-ចំណាយ គ្រប់គ្រងសម្ភារៈ និងការស្តុក ជាមួយការជូនដំណឹងពេលស្តុកទាប។',
    icon: Zap,
    color: 'text-orange-600',
    bg: 'bg-orange-50',
    border: 'border-orange-100'
  }
]

const roles = [
  { name: 'នាយកសាលា / Admin', desc: 'គ្រប់គ្រងទាំងអស់ — សិស្ស គ្រូ ថវិកា របាយការណ៍', color: 'bg-indigo-600' },
  { name: 'គ្រូបង្រៀន', desc: 'គ្រប់គ្រងថ្នាក់ — វត្តមាន ពិន្ទុ សុខភាពសិស្ស', color: 'bg-emerald-600' },
  { name: 'បណ្ណារក្ស', desc: 'គ្រប់គ្រងបណ្ណាល័យ — ខ្ចី-សងសៀវភៅ', color: 'bg-amber-500' },
  { name: 'ឪពុកម្តាយ', desc: 'មើលព័ត៌មានកូន — គ្មានចុះឈ្មោះ គ្មានពាក្យសម្ងាត់', color: 'bg-rose-500' }
]

const stats = [
  { num: '២០+', label: 'មុខងារគ្រប់គ្រង' },
  { num: '១០០%', label: 'ឥតគិតថ្លៃ' },
  { num: '១០០%', label: 'ភាសាខ្មែរ' },
  { num: '២៤/៧', label: 'អាចចូលប្រើ' }
]

const contacts = [
  {
    name: 'Facebook',
    handle: 'Tra Dev',
    link: 'https://facebook.com',
    icon: Facebook,
    color: 'bg-blue-600',
    hover: 'hover:bg-blue-700',
    desc: 'ផ្ញើសារតាម Facebook'
  },
  {
    name: 'Telegram',
    handle: '@tra_dev',
    link: 'https://t.me/tra_dev',
    icon: Send,
    color: 'bg-sky-500',
    hover: 'hover:bg-sky-600',
    desc: 'ផ្ញើសារតាម Telegram'
  },
  {
    name: 'Gmail',
    handle: 'tra@gmail.com',
    link: 'mailto:tra@gmail.com',
    icon: Mail,
    color: 'bg-red-500',
    hover: 'hover:bg-red-600',
    desc: 'ផ្ញើអ៊ីមែលមកយើង'
  }
]
</script>

<template>
  <div class="min-h-screen bg-white font-khmer overflow-x-hidden">

    <!-- ── NAV ──────────────────────────────────────────────── -->
    <nav
      class="sticky top-0 z-50 bg-white/80 backdrop-blur-xl border-b border-slate-100"
      :class="visible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-4'"
      style="transition: all 0.6s cubic-bezier(.22,1,.36,1)"
    >
      <div class="max-w-7xl mx-auto px-6 h-18 py-3 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="bg-indigo-600 p-2 rounded-xl shadow-lg shadow-indigo-200">
            <GraduationCap class="w-6 h-6 text-white" />
          </div>
          <div>
            <div class="text-base font-black text-slate-900 leading-none">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</div>
            <div class="text-xs text-slate-400 font-medium">School Management System</div>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <a href="#contact" class="text-slate-600 font-semibold hover:text-indigo-600 transition-colors text-sm hidden sm:block">ទំនាក់ទំនង</a>
          <button
            @click="router.push('/login')"
            class="bg-indigo-600 text-white px-5 py-2.5 rounded-xl font-bold hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-200 text-sm flex items-center gap-2"
          >
            ចូលប្រើប្រាស់
            <ArrowRight class="w-4 h-4" />
          </button>
        </div>
      </div>
    </nav>

    <!-- ── HERO ──────────────────────────────────────────────── -->
    <section class="relative pt-24 pb-32 px-6 overflow-hidden">
      <!-- BG blobs -->
      <div class="absolute top-0 right-0 w-[600px] h-[600px] bg-indigo-50 rounded-full blur-3xl opacity-60 -translate-y-1/2 translate-x-1/2 pointer-events-none"></div>
      <div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-emerald-50 rounded-full blur-3xl opacity-60 translate-y-1/2 -translate-x-1/2 pointer-events-none"></div>

      <div
        class="max-w-7xl mx-auto text-center relative"
        :class="visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'"
        style="transition: all 0.8s cubic-bezier(.22,1,.36,1) 0.2s"
      >
        <!-- Badge -->
        <div class="inline-flex items-center gap-2 bg-indigo-50 border border-indigo-100 text-indigo-700 px-4 py-2 rounded-full text-sm font-bold mb-8">
          <Star class="w-4 h-4 fill-indigo-400 text-indigo-400" />
          ត្រូវបានប្រើប្រាស់នៅសាលាបឋមសិក្សារដ្ឋ ខេត្តបាត់ដំបង
        </div>

        <!-- Headline -->
        <h1 class="text-5xl lg:text-7xl font-black text-slate-900 leading-[1.05] mb-6 tracking-tight">
          ប្រព័ន្ធគ្រប់គ្រង<br/>
          <span class="text-indigo-600 relative">
            សាលាបឋមសិក្សា
            <svg class="absolute -bottom-2 left-0 w-full" viewBox="0 0 400 12" fill="none">
              <path d="M2 10 Q200 2 398 10" stroke="#6366f1" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.4"/>
            </svg>
          </span>
        </h1>

        <p class="text-xl text-slate-500 max-w-2xl mx-auto mb-12 leading-relaxed">
          ប្រព័ន្ធឌីជីថលពេញលេញ ជាភាសាខ្មែរ ១០០% — 
          គ្រប់គ្រងសិស្ស គ្រូ វត្តមាន ពិន្ទុ សុខភាព បណ្ណាល័យ និងថវិកា 
          ក្នុងប្រព័ន្ធតែមួយ ប្រើប្រាស់បានគ្រប់ឧបករណ៍។
        </p>

        <!-- CTAs -->
        <div class="flex flex-col sm:flex-row items-center justify-center gap-4 mb-20">
          <button
            @click="router.push('/login')"
            class="group bg-indigo-600 text-white px-10 py-4 rounded-2xl font-bold text-lg hover:bg-indigo-700 transition-all shadow-xl shadow-indigo-200 flex items-center gap-3"
          >
            ចូលប្រើប្រាស់ប្រព័ន្ធ
            <ArrowRight class="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </button>
          <a
            href="#about"
            class="group border-2 border-slate-200 text-slate-700 px-10 py-4 rounded-2xl font-bold text-lg hover:border-indigo-300 hover:text-indigo-600 transition-all flex items-center gap-2"
          >
            ស្វែងយល់បន្ថែម
            <ChevronDown class="w-5 h-5 group-hover:translate-y-1 transition-transform" />
          </a>
        </div>

        <!-- Stats -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 max-w-3xl mx-auto">
          <div
            v-for="(s, i) in stats"
            :key="s.label"
            class="bg-white border border-slate-100 rounded-2xl p-5 shadow-sm"
            :class="visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'"
            :style="`transition: all 0.6s cubic-bezier(.22,1,.36,1) ${0.4 + i * 0.1}s`"
          >
            <div class="text-3xl font-black text-indigo-600 mb-1">{{ s.num }}</div>
            <div class="text-sm text-slate-500 font-medium">{{ s.label }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── ABOUT ─────────────────────────────────────────────── -->
    <section id="about" class="py-24 bg-slate-900 px-6 relative overflow-hidden">
      <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-indigo-900/40 via-slate-900 to-slate-900 pointer-events-none"></div>

      <div class="max-w-7xl mx-auto relative">
        <div class="grid lg:grid-cols-2 gap-16 items-center">
          <div>
            <div class="inline-flex items-center gap-2 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 px-4 py-2 rounded-full text-sm font-bold mb-6">
              <Globe class="w-4 h-4" />
              អំពីប្រព័ន្ធ
            </div>
            <h2 class="text-4xl lg:text-5xl font-black text-white leading-tight mb-6">
              ត្រូវបានបង្កើតឡើងសម្រាប់ <span class="text-indigo-400">សាលារដ្ឋ</span> កម្ពុជា
            </h2>
            <p class="text-slate-400 text-lg leading-relaxed mb-6">
              ប្រព័ន្ធនេះត្រូវបានអភិវឌ្ឍន៍ដោយក្រុម Developer ខ្មែរ ដើម្បីផ្តល់ជូនសាលាបឋមសិក្សារដ្ឋ 
              ដែលមានចំណូលតិច ប៉ុន្តែត្រូវការឧបករណ៍ឌីជីថលប្រកបដោយប្រសិទ្ធភាព។
            </p>
            <p class="text-slate-400 text-lg leading-relaxed mb-10">
              ប្រព័ន្ធនេះ<span class="text-white font-semibold"> ឥតគិតថ្លៃ </span>
              សម្រាប់សាលារដ្ឋ — ភាសាខ្មែរ ១០០% ។ ងាយស្រួលប្រើ ។ អាចប្រើលើ Mobile ។
            </p>

            <!-- Role pills -->
            <div class="grid grid-cols-2 gap-3">
              <div
                v-for="r in roles"
                :key="r.name"
                class="bg-white/5 border border-white/10 rounded-2xl p-4 hover:bg-white/10 transition-colors"
              >
                <div class="flex items-center gap-2 mb-2">
                  <div :class="[r.color, 'w-2 h-2 rounded-full']"></div>
                  <span class="text-white font-bold text-sm">{{ r.name }}</span>
                </div>
                <p class="text-slate-400 text-xs leading-relaxed">{{ r.desc }}</p>
              </div>
            </div>
          </div>

          <!-- Visual side -->
          <div class="space-y-4">
            <div class="bg-white/5 border border-white/10 rounded-3xl p-6">
              <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 bg-indigo-500/20 rounded-xl flex items-center justify-center">
                  <School class="w-5 h-5 text-indigo-400" />
                </div>
                <div>
                  <div class="text-white font-bold">Multi-School Platform</div>
                  <div class="text-slate-400 text-sm">ប្រព័ន្ធចែករំលែកសម្រាប់ច្រើនសាលា</div>
                </div>
              </div>
              <p class="text-slate-400 text-sm leading-relaxed">
                សាលារៀនច្រើន អាចប្រើប្រព័ន្ធតែមួយ ។ ទិន្នន័យរបស់សាលាម្នាក់ ពុំអាចមើលឃើញដោយសាលាផ្សេង ។ 
                ប្រព័ន្ធ RLS ការពារ ១០០% ។
              </p>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div class="bg-indigo-600/20 border border-indigo-500/20 rounded-2xl p-5 text-center">
                <div class="text-3xl font-black text-indigo-400 mb-1">Mon–Sat</div>
                <div class="text-slate-400 text-sm">ថ្ងៃចូលរៀន</div>
              </div>
              <div class="bg-emerald-600/20 border border-emerald-500/20 rounded-2xl p-5 text-center">
                <div class="text-3xl font-black text-emerald-400 mb-1">2 វេន</div>
                <div class="text-slate-400 text-sm">ព្រឹក / រសៀល</div>
              </div>
            </div>
            <div class="bg-white/5 border border-white/10 rounded-2xl p-5 flex items-start gap-4">
              <CheckCircle2 class="w-6 h-6 text-emerald-400 mt-0.5 shrink-0" />
              <div>
                <div class="text-white font-bold mb-1">ទិន្នន័យមានសុវត្ថិភាព</div>
                <div class="text-slate-400 text-sm">ប្រព័ន្ធសុវត្ថិភាពខ្ពស់ ធានា ០% ការលេចទិន្នន័យ រវាងសាលា។</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── FEATURES ───────────────────────────────────────────── -->
    <section id="features" class="py-24 px-6 bg-slate-50">
      <div class="max-w-7xl mx-auto">
        <div class="text-center mb-16">
          <h2 class="text-4xl lg:text-5xl font-black text-slate-900 mb-4">លក្ខណៈពិសេស</h2>
          <p class="text-slate-500 text-lg max-w-xl mx-auto">
            គ្រប់អ្វីដែលសាលាបឋមសិក្សាត្រូវការ ក្នុងប្រព័ន្ធតែមួយ
          </p>
        </div>

        <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div
            v-for="(f, i) in features"
            :key="f.title"
            class="bg-white border rounded-3xl p-8 hover:shadow-xl hover:-translate-y-1 transition-all duration-300 group cursor-default"
            :class="f.border"
          >
            <div :class="[f.bg, 'w-14 h-14 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300']">
              <component :is="f.icon" :class="['w-7 h-7', f.color]" />
            </div>
            <h3 class="text-xl font-black text-slate-900 mb-3">{{ f.title }}</h3>
            <p class="text-slate-500 leading-relaxed">{{ f.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ── HOW TO JOIN ────────────────────────────────────────── -->
    <section class="py-24 px-6 bg-white">
      <div class="max-w-4xl mx-auto text-center">
        <h2 class="text-4xl lg:text-5xl font-black text-slate-900 mb-4">
          តើចូលប្រើប្រាស់ <span class="text-indigo-600">ដោយរបៀបណា?</span>
        </h2>
        <p class="text-slate-500 text-lg mb-16 max-w-xl mx-auto">
          ដើម្បីបង្កើតគណនី សម្រាប់សាលារបស់អ្នក ចូរទំនាក់ទំនងមកកាន់យើង
        </p>

        <!-- Steps -->
        <div class="grid md:grid-cols-3 gap-8 mb-16 text-left">
          <div
            v-for="(step, i) in [
              { num: '01', title: 'ទំនាក់ទំនង', desc: 'ផ្ញើសារតាម Facebook, Telegram ឬ Gmail ប្រាប់ឈ្មោះ និងទីតាំងសាលា' },
              { num: '02', title: 'ទទួលគណនី', desc: 'យើងនឹងបង្កើតគណនី Admin សម្រាប់សាលា ហើយផ្ញើ Email + Password ជូន' },
              { num: '03', title: 'ចាប់ផ្តើម', desc: 'ចូល Login ហើយចាប់ផ្តើម Setup — បង្កើតថ្នាក់ ចុះឈ្មោះសិស្ស ចូលធ្វើការ' }
            ]"
            :key="step.num"
            class="relative"
          >
            <div class="text-6xl font-black text-indigo-50 mb-4 leading-none select-none">{{ step.num }}</div>
            <h3 class="text-xl font-black text-slate-900 mb-2">{{ step.title }}</h3>
            <p class="text-slate-500 leading-relaxed">{{ step.desc }}</p>
            <div v-if="i < 2" class="hidden md:block absolute top-8 -right-4 text-slate-200 text-2xl font-black">→</div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── CONTACT ────────────────────────────────────────────── -->
    <section id="contact" class="py-24 px-6 bg-gradient-to-br from-indigo-600 to-indigo-800 relative overflow-hidden">
      <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_bottom_left,_var(--tw-gradient-stops))] from-indigo-500/30 to-transparent pointer-events-none"></div>
      <div class="absolute top-0 right-0 w-96 h-96 bg-white/5 rounded-full blur-3xl pointer-events-none"></div>

      <div class="max-w-4xl mx-auto text-center relative">
        <div class="inline-flex items-center gap-2 bg-white/10 border border-white/20 text-white px-4 py-2 rounded-full text-sm font-bold mb-8">
          <Mail class="w-4 h-4" />
          ទំនាក់ទំនង
        </div>
        <h2 class="text-4xl lg:text-5xl font-black text-white mb-4 leading-tight">
          ចង់ប្រើប្រព័ន្ធនេះ<br/>
          <span class="text-indigo-200">នៅសាលារបស់អ្នក?</span>
        </h2>
        <p class="text-indigo-200 text-lg mb-12 max-w-xl mx-auto leading-relaxed">
          ទំនាក់ទំនងមកកាន់យើង ដើម្បីបង្កើតគណនីសម្រាប់សាលា។ 
          ប្រព័ន្ធនេះ<strong class="text-white"> ឥតគិតថ្លៃ </strong>
          សម្រាប់សាលាបឋមសិក្សារដ្ឋ 🇰🇭
        </p>

        <!-- Contact cards -->
        <div class="grid md:grid-cols-3 gap-4 mb-12">
          <a
            v-for="c in contacts"
            :key="c.name"
            :href="c.link"
            target="_blank"
            class="group bg-white/10 backdrop-blur-sm border border-white/20 rounded-3xl p-6 hover:bg-white/20 transition-all duration-300 hover:-translate-y-1 text-left"
          >
            <div :class="[c.color, c.hover, 'w-12 h-12 rounded-2xl flex items-center justify-center mb-4 transition-colors shadow-lg']">
              <component :is="c.icon" class="w-6 h-6 text-white" />
            </div>
            <div class="text-white font-black text-lg mb-1">{{ c.name }}</div>
            <div class="text-indigo-200 text-sm font-medium mb-2">{{ c.handle }}</div>
            <div class="text-indigo-300 text-xs">{{ c.desc }}</div>
            <div class="mt-4 flex items-center gap-1 text-white/60 text-xs font-semibold group-hover:text-white transition-colors">
              ចុចទំនាក់ទំនង <ArrowRight class="w-3 h-3 group-hover:translate-x-1 transition-transform" />
            </div>
          </a>
        </div>

        <!-- Quick info -->
        <div class="bg-white/10 border border-white/20 rounded-2xl p-6 text-left max-w-2xl mx-auto">
          <p class="text-indigo-200 text-sm mb-3 font-bold">📋 ព័ត៌មានដែលត្រូវផ្ញើមកដើម្បីសុំគណនី:</p>
          <ul class="space-y-2 text-white text-sm">
            <li class="flex items-center gap-2"><CheckCircle2 class="w-4 h-4 text-emerald-400 shrink-0" /> ឈ្មោះសាលា (ខ្មែរ + អង់គ្លេស)</li>
            <li class="flex items-center gap-2"><CheckCircle2 class="w-4 h-4 text-emerald-400 shrink-0" /> ស្រុក / ខេត្ត</li>
            <li class="flex items-center gap-2"><CheckCircle2 class="w-4 h-4 text-emerald-400 shrink-0" /> ឈ្មោះ និង Email របស់នាយក/នាយិកា</li>
          </ul>
        </div>
      </div>
    </section>

    <!-- ── FOOTER ─────────────────────────────────────────────── -->
    <footer class="py-10 border-t border-slate-100 px-6">
      <div class="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
        <div class="flex items-center gap-3">
          <div class="bg-indigo-600 p-1.5 rounded-lg">
            <GraduationCap class="w-5 h-5 text-white" />
          </div>
          <div>
            <div class="font-black text-slate-900 text-sm">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</div>
            <div class="text-xs text-slate-400">School Management System</div>
          </div>
        </div>

        <div class="flex items-center gap-4">
          <a v-for="c in contacts" :key="c.name" :href="c.link" target="_blank"
            :class="[c.color, c.hover, 'w-9 h-9 rounded-xl flex items-center justify-center transition-colors shadow-sm']"
          >
            <component :is="c.icon" class="w-4 h-4 text-white" />
          </a>
        </div>

        <div class="text-slate-400 text-sm text-center">
          រក្សាសិទ្ធិគ្រប់យ៉ាង © ២០២៥ — ប្រព័ន្ធគ្រប់គ្រងសាលារៀន 🇰🇭
        </div>
      </div>
    </footer>

  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Kantumruy+Pro:ital,wght@0,100..700;1,100..700&display=swap');

.font-khmer {
  font-family: 'Kantumruy Pro', sans-serif;
}

/* Smooth scroll */
html {
  scroll-behavior: smooth;
}

/* Section fade-in on scroll */
section {
  animation: fadeUp 0.7s cubic-bezier(.22,1,.36,1) both;
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(24px); }
  to   { opacity: 1; transform: translateY(0); }
}
</style>