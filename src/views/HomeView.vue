<script setup>
import { useRouter } from "vue-router";
import { ref, onMounted, onUnmounted } from "vue";
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
  Globe,
  ChevronUp,
  Menu,
  X,
} from "lucide-vue-next";

const router = useRouter();
const visible = ref(false);
const mobileMenuOpen = ref(false);
const activeStep = ref(0);
const activeFaq = ref(null);
const scrolled = ref(false);

onMounted(() => {
  setTimeout(() => (visible.value = true), 100);
  window.addEventListener("scroll", onScroll);
});
onUnmounted(() => window.removeEventListener("scroll", onScroll));

function onScroll() {
  scrolled.value = window.scrollY > 40;
}

function toggleFaq(i) {
  activeFaq.value = activeFaq.value === i ? null : i;
}

const features = [
  {
    title: "គ្រប់គ្រងការស្រង់វត្តមាន",
    desc: "តាមដានវត្តមានសិស្ស និងគ្រូប្រចាំថ្ងៃ។ កត់ត្រាម៉ោងមកយឺត និងរបាយការណ៍សង្ខេបប្រចាំខែ។",
    icon: Calendar,
    color: "#1e5fa5",
    bg: "#e6f1fb",
  },
  {
    title: "ប្រព័ន្ធគ្រប់គ្រងពិន្ទុ",
    desc: "បញ្ចូលពិន្ទុប្រចាំខែ-ឆមាស គណនាមធ្យមភាគ និងចំណាត់ថ្នាក់ស្វ័យប្រវត្តិ។ អាចបោះពុម្ពជា PDF។",
    icon: BarChart3,
    color: "#3b6d11",
    bg: "#eaf3de",
  },
  {
    title: "បណ្ណាល័យឌីជីថល",
    desc: "គ្រប់គ្រងការខ្ចី-សងសៀវភៅតាមបច្ចេកវិទ្យា។ ជូនដំណឹងសៀវភៅដែលហួសកាលកំណត់។",
    icon: BookOpen,
    color: "#854f0b",
    bg: "#faeeda",
  },
  {
    title: "សុខភាព និងការលូតលាស់",
    desc: "កត់ត្រាប្រវត្តិវ៉ាក់សាំង ការពិនិត្យសុខភាព និងតាមដានការលូតលាស់របស់សិស្សម្នាក់ៗ។",
    icon: ShieldCheck,
    color: "#993556",
    bg: "#fbeaf0",
  },
  {
    title: "ព័ត៌មានសម្រាប់អាណាព្យាបាល",
    desc: "អាណាព្យាបាលអាចតាមដានការរៀនសូត្ររបស់កូនតាមរយៈ Link — ងាយស្រួល មិនចាំបាច់ប្រើពាក្យសម្ងាត់។",
    icon: Users,
    color: "#534ab7",
    bg: "#eeedfe",
  },
  {
    title: "សារពើភ័ណ្ឌ និងថវិកា",
    desc: "តាមដានចំណូល-ចំណាយសាលា។ គ្រប់គ្រងស្តុកសម្ភារៈឧបទេស ជាមួយប្រព័ន្ធជូនដំណឹងស្តុកទាប។",
    icon: Zap,
    color: "#a32d2d",
    bg: "#fcebeb",
  },
];

const steps = [
  {
    title: "ជ្រើសរើសឆ្នាំសិក្សា",
    desc: "គណៈគ្រប់គ្រងចូលប្រើប្រាស់ រួចជ្រើសរើសឆ្នាំសិក្សាចាស់ ឬបង្កើតឆ្នាំសិក្សាថ្មីដើម្បីចាប់ផ្ដើម។",
    screen: "year",
  },
  {
    title: "រៀបចំថ្នាក់ និងគ្រូ",
    desc: "បង្កើតថ្នាក់រៀន ចាត់តាំងគ្រូបន្ទុកថ្នាក់ និងកំណត់មុខវិជ្ជាទៅតាមកម្រិតថ្នាក់នីមួយៗ។",
    screen: "class",
  },
  {
    title: "ចុះឈ្មោះសិស្ស",
    desc: "បញ្ចូលទិន្នន័យសិស្សដោយផ្ទាល់ ឬទាញចូលពី Excel (Import) ប្រកបដោយភាពរហ័ស។",
    screen: "student",
  },
  {
    title: "ប្រតិបត្តិការប្រចាំថ្ងៃ",
    desc: "គ្រូស្រង់វត្តមាន បញ្ចូលពិន្ទុ និងគ្រប់គ្រងសកម្មភាពសិស្សតាមរយៈ Dashboard តែមួយ។",
    screen: "teacher",
  },
];

const faqs = [
  {
    q: "តើប្រព័ន្ធនេះឥតគិតថ្លៃពិតមែនទេ?",
    a: "បាទ/ចាស! ប្រព័ន្ធនេះត្រូវបានបង្កើតឡើងដើម្បីជួយសម្រួលដល់សាលាបឋមសិក្សារដ្ឋ ដោយមិនមានកម្រៃប្រើប្រាស់ប្រចាំខែឡើយ។",
  },
  {
    q: "តើសាលាត្រូវមានតម្រូវការបច្ចេកទេសអ្វីខ្លះ?",
    a: "លោកអ្នកគ្រាន់តែមានឧបករណ៍ដែលអាចភ្ជាប់ Internet បានដូចជា Computer, Tablet ឬ Smartphone ហើយប្រើប្រាស់តាមរយៈ Browser (Chrome, Safari) ជាការស្រេច។",
  },
  {
    q: "តើទិន្នន័យសាលាខ្ញុំមានសុវត្ថិភាពកម្រិតណា?",
    a: "សុវត្ថិភាពជាចម្បង! យើងប្រើប្រាស់បច្ចេកវិទ្យា Row Level Security (RLS) ដែលធានាថាទិន្នន័យសាលានីមួយៗត្រូវបានបំបែកដាច់ពីគ្នា ១០០%។",
  },
  {
    q: "តើអាណាព្យាបាលត្រូវបង្កើតគណនីដែរឬទេ?",
    a: "មិនចាំបាច់ទេ! អាណាព្យាបាលគ្រាន់តែចុចលើ Link ដែលផ្ញើដោយលោកគ្រូអ្នកគ្រូ ដើម្បីមើលរបាយការណ៍របស់កូនៗបានភ្លាមៗ។",
  },
  {
    q: "តើទិន្នន័យនឹងបាត់បង់ទេ ប្រសិនបើគ្មាន Internet?",
    a: "រាល់ទិន្នន័យដែលបានបញ្ចូលរួច នឹងត្រូវរក្សាទុកក្នុង Cloud ប្រកបដោយសុវត្ថិភាព។ លោកអ្នកអាចចូលមើលវិញបាននៅពេលមាន Internet ធម្មតា។",
  },
  {
    q: "តើប្រព័ន្ធតម្លើងថ្នាក់ (Rollup) ដំណើរការយ៉ាងដូចម្តេច?",
    a: "នៅចុងឆ្នាំសិក្សា Admin គ្រាន់តែប្រើមុខងារ Rollup ដើម្បីរៀបចំសិស្សឱ្យឡើងទៅថ្នាក់បន្ទាប់ដោយស្វ័យប្រវត្តិ និងកំណត់សិស្សថ្នាក់ទី៦ ថាបានបញ្ចប់ការសិក្សា។",
  },
];

const contacts = [
  {
    name: "Facebook",
    handle: "Tra Dev",
    link: "https://facebook.com",
    icon: Facebook,
    color: "#1877f2",
    desc: "ផ្ញើសារសាកសួរ",
  },
  {
    name: "Telegram",
    handle: "@tra_dev",
    link: "https://t.me/tra_dev",
    icon: Send,
    color: "#0088cc",
    desc: "ប្រឹក្សាបច្ចេកទេស",
  },
  {
    name: "Gmail",
    handle: "tra@gmail.com",
    link: "mailto:tra@gmail.com",
    icon: Mail,
    color: "#ea4335",
    desc: "ផ្ញើអ៊ីមែល",
  },
];

const stats = [
  { num: "២០+", label: "មុខងារសំខាន់ៗ" },
  { num: "១០០%", label: "ភាសាខ្មែរ" },
  { num: "២ វេន", label: "ព្រឹក និង រសៀល" },
  { num: "២៤/៧", label: "សុវត្ថិភាពទិន្នន័យ" },
];
</script>

<template>
  <div class="landing font-khmer" :class="{ visible }">
    <!-- ══ NAV ══════════════════════════════════════════════════════ -->
    <nav class="nav" :class="{ scrolled }">
      <div class="nav-inner">
        <div class="logo">
          <div class="logo-icon">
            <GraduationCap :size="20" />
          </div>
          <div>
            <div class="logo-title">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</div>
            <div class="logo-sub">School Management System</div>
          </div>
        </div>
        <div class="nav-links">
          <a href="#features" class="nav-link">មុខងារ</a>
          <a href="#how" class="nav-link">របៀបប្រើ</a>
          <a href="#contact" class="nav-link">ទំនាក់ទំនង</a>
          <button class="btn-primary" @click="router.push('/login')">
            ចូលប្រើ <ArrowRight :size="14" />
          </button>
        </div>
        <button
          class="mobile-menu-btn"
          @click="mobileMenuOpen = !mobileMenuOpen"
        >
          <X v-if="mobileMenuOpen" :size="20" />
          <Menu v-else :size="20" />
        </button>
      </div>
      <div class="mobile-menu" :class="{ open: mobileMenuOpen }">
        <a href="#features" class="mobile-link" @click="mobileMenuOpen = false"
          >មុខងារ</a
        >
        <a href="#how" class="mobile-link" @click="mobileMenuOpen = false"
          >របៀបប្រើ</a
        >
        <a href="#contact" class="mobile-link" @click="mobileMenuOpen = false"
          >ទំនាក់ទំនង</a
        >
        <button class="btn-primary w-full" @click="router.push('/login')">
          ចូលប្រើប្រាស់
        </button>
      </div>
    </nav>

    <!-- ══ HERO ══════════════════════════════════════════════════════ -->
    <section class="hero">
      <div class="hero-bg-grid"></div>
      <div class="hero-inner">
        <!-- Left copy -->
        <div class="hero-copy anim-up" style="animation-delay: 0.1s">
          <div class="official-badge">
            <span class="kh-flag">🇰🇭</span>
            ត្រូវបានប្រើប្រាស់នៅ ខេត្តបាត់ដំបង
          </div>
          <h1 class="hero-title">
            ប្រព័ន្ធ<br />
            <span class="hero-accent">គ្រប់គ្រងសាលា</span><br />
            ឌីជីថល
          </h1>
          <p class="hero-desc">
            ជាភាសាខ្មែរ ១០០% — គ្រប់គ្រងសិស្ស គ្រូ វត្តមាន ពិន្ទុ បណ្ណាល័យ
            និងថវិកា ក្នុងប្រព័ន្ធតែមួយ ។
          </p>
          <div class="hero-ctas">
            <button class="btn-primary btn-lg" @click="router.push('/login')">
              ចូលប្រើប្រាស់ <ArrowRight :size="16" />
            </button>
            <a href="#how" class="btn-outline btn-lg">
              ស្វែងយល់បន្ថែម <ChevronDown :size="16" />
            </a>
          </div>
          <div class="stats-row">
            <div v-for="s in stats" :key="s.label" class="stat-item">
              <div class="stat-num">{{ s.num }}</div>
              <div class="stat-label">{{ s.label }}</div>
            </div>
          </div>
        </div>

        <!-- Right: dashboard mockup -->
        <div class="hero-mockup anim-up" style="animation-delay: 0.25s">
          <div class="mockup-browser">
            <div class="browser-bar">
              <span class="dot dot-r"></span>
              <span class="dot dot-y"></span>
              <span class="dot dot-g"></span>
              <span class="browser-url">school.edu.kh/admin/dashboard</span>
            </div>
            <div class="mockup-body">
              <!-- Sidebar -->
              <div class="mockup-sidebar">
                <div class="sidebar-logo-area">
                  <div class="sidebar-icon-box">
                    <GraduationCap :size="14" />
                  </div>
                  <span>SMS</span>
                </div>
                <div class="sidebar-item active">
                  <Calendar :size="13" />វត្តមាន
                </div>
                <div class="sidebar-item"><BarChart3 :size="13" />ពិន្ទុ</div>
                <div class="sidebar-item"><Users :size="13" />សិស្ស</div>
                <div class="sidebar-item"><BookOpen :size="13" />បណ្ណាល័យ</div>
                <div class="sidebar-item"><ShieldCheck :size="13" />សុខភាព</div>
                <div class="sidebar-item"><Zap :size="13" />ថវិកា</div>
              </div>
              <!-- Main content -->
              <div class="mockup-main">
                <div class="mockup-topbar">
                  <span class="mockup-page-title">Dashboard</span>
                  <span class="year-badge">ឆ្នាំ ២០២៤–២០២៥</span>
                </div>
                <!-- Stat cards -->
                <div class="mockup-cards">
                  <div class="mcard blue">
                    <div class="mcard-num">248</div>
                    <div class="mcard-lbl">សិស្សសរុប</div>
                  </div>
                  <div class="mcard green">
                    <div class="mcard-num">12</div>
                    <div class="mcard-lbl">ថ្នាក់</div>
                  </div>
                  <div class="mcard amber">
                    <div class="mcard-num">18</div>
                    <div class="mcard-lbl">គ្រូ</div>
                  </div>
                </div>
                <!-- Attendance bar -->
                <div class="mockup-section-title">វត្តមានថ្ងៃនេះ</div>
                <div class="attendance-bars">
                  <div
                    v-for="(b, i) in [
                      { lbl: 'ថ្នាក់ ១ក', pct: 96, color: '#1e5fa5' },
                      { lbl: 'ថ្នាក់ ២ខ', pct: 88, color: '#3b6d11' },
                      { lbl: 'ថ្នាក់ ៣ក', pct: 100, color: '#1e5fa5' },
                      { lbl: 'ថ្នាក់ ៤ខ', pct: 92, color: '#3b6d11' },
                    ]"
                    :key="i"
                    class="att-row"
                  >
                    <span class="att-lbl">{{ b.lbl }}</span>
                    <div class="att-track">
                      <div
                        class="att-fill"
                        :style="{ width: b.pct + '%', background: b.color }"
                      ></div>
                    </div>
                    <span class="att-pct">{{ b.pct }}%</span>
                  </div>
                </div>
                <!-- Recent activity -->
                <div class="mockup-section-title">សកម្មភាពថ្មី</div>
                <div class="activity-list">
                  <div
                    v-for="a in [
                      {
                        icon: '👤',
                        text: 'ចាន់ សុភា — ពិន្ទុខែ ១០ បានបន្ថែម',
                        time: 'ម៉ោង ១០:២៣',
                      },
                      {
                        icon: '📚',
                        text: 'សៀវភៅ គណិតវិទ្យា — ត្រូវបានខ្ចី',
                        time: 'ម៉ោង ០៩:៤៥',
                      },
                      {
                        icon: '✅',
                        text: 'វត្តមានថ្នាក់ ៣ — mark រួច',
                        time: 'ម៉ោង ០៨:០០',
                      },
                    ]"
                    :key="a.text"
                    class="act-row"
                  >
                    <span class="act-icon">{{ a.icon }}</span>
                    <span class="act-text">{{ a.text }}</span>
                    <span class="act-time">{{ a.time }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <!-- Floating badge -->
          <div class="float-badge float-badge-1">
            <CheckCircle2 :size="14" color="#3b6d11" />
            <span>Multi-School · RLS</span>
          </div>
          <div class="float-badge float-badge-2">
            <Star :size="14" color="#854f0b" fill="#854f0b" />
            <span>ឥតគិតថ្លៃ ១០០%</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ OFFICIAL BANNER ══════════════════════════════════════════ -->
    <div class="official-banner">
      <div class="official-banner-inner">
        <School :size="18" />
        <span
          >ត្រូវបានប្រើប្រាស់ជាក់ស្ដែងនៅ
          <strong>សាលាបឋមសិក្សាស្វាយជាតិ ខេត្តបាត់ដំបង</strong></span
        >
      </div>
    </div>

    <!-- ══ FEATURES ══════════════════════════════════════════════════ -->
    <section id="features" class="section features-section">
      <div class="section-inner">
        <div class="section-header">
          <div class="section-tag">លក្ខណៈពិសេស</div>
          <h2 class="section-title">គ្រប់អ្វីដែលសាលាត្រូវការ</h2>
          <p class="section-desc">
            ក្នុងប្រព័ន្ធតែមួយ — ជាភាសាខ្មែរ — ងាយស្រួលប្រើ
          </p>
        </div>
        <div class="features-grid">
          <div v-for="f in features" :key="f.title" class="feature-card">
            <div
              class="feature-icon"
              :style="{ background: f.bg, color: f.color }"
            >
              <component :is="f.icon" :size="22" />
            </div>
            <h3 class="feature-title">{{ f.title }}</h3>
            <p class="feature-desc">{{ f.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ HOW IT WORKS ══════════════════════════════════════════════ -->
    <section id="how" class="section how-section">
      <div class="section-inner">
        <div class="section-header">
          <div class="section-tag">របៀបប្រើ</div>
          <h2 class="section-title">ចាប់ផ្ដើមក្នុង ៤ ជំហាន</h2>
          <p class="section-desc">
            ពី Login រហូតដល់ Dashboard ក្នុងពេលតិចជាង ១ ម៉ោង
          </p>
        </div>
        <div class="how-layout">
          <!-- Step nav -->
          <div class="step-nav">
            <div
              v-for="(s, i) in steps"
              :key="i"
              class="step-nav-item"
              :class="{ active: activeStep === i }"
              @click="activeStep = i"
            >
              <div class="step-num">{{ String(i + 1).padStart(2, "0") }}</div>
              <div class="step-info">
                <div class="step-name">{{ s.title }}</div>
                <div class="step-short">{{ s.desc }}</div>
              </div>
            </div>
          </div>
          <!-- Screen mockup -->
          <div class="step-screen">
            <!-- Year selection screen -->
            <div
              v-if="steps[activeStep].screen === 'year'"
              class="screen-mockup"
            >
              <div class="screen-topbar">ជ្រើសរើសឆ្នាំសិក្សា</div>
              <div
                class="screen-body"
                style="
                  padding: 20px;
                  gap: 12px;
                  display: flex;
                  flex-direction: column;
                "
              >
                <div
                  v-for="y in [
                    '២០២៤–២០២៥ (បច្ចុប្បន្ន)',
                    '២០២៣–២០២៤',
                    '២០២២–២០២៣',
                  ]"
                  :key="y"
                  class="year-row"
                  :class="{ 'year-row-active': y.includes('បច្ចុប្បន្ន') }"
                >
                  <Calendar :size="14" />
                  <span>{{ y }}</span>
                  <span v-if="y.includes('បច្ចុប្បន្ន')" class="badge-active"
                    >មើល</span
                  >
                </div>
                <button class="screen-btn">+ បង្កើតឆ្នាំថ្មី</button>
              </div>
            </div>
            <!-- Class screen -->
            <div
              v-else-if="steps[activeStep].screen === 'class'"
              class="screen-mockup"
            >
              <div class="screen-topbar">ថ្នាក់រៀន</div>
              <div
                class="screen-body"
                style="
                  padding: 16px;
                  gap: 10px;
                  display: flex;
                  flex-direction: column;
                "
              >
                <div
                  v-for="c in [
                    {
                      name: 'ថ្នាក់ ១-ក',
                      teacher: 'ស្រី ចាន់',
                      students: 32,
                      turn: 'ព្រឹក',
                    },
                    {
                      name: 'ថ្នាក់ ២-ខ',
                      teacher: 'លោក សុខ',
                      students: 28,
                      turn: 'ព្រឹក',
                    },
                    {
                      name: 'ថ្នាក់ ៣-ក',
                      teacher: 'ស្រី លី',
                      students: 30,
                      turn: 'រសៀល',
                    },
                  ]"
                  :key="c.name"
                  class="class-row"
                >
                  <div class="class-icon"><School :size="12" /></div>
                  <div style="flex: 1">
                    <div class="class-name">{{ c.name }}</div>
                    <div class="class-meta">
                      {{ c.teacher }} · {{ c.students }} នាក់ · {{ c.turn }}
                    </div>
                  </div>
                  <span class="badge-turn">{{ c.turn }}</span>
                </div>
                <button class="screen-btn">+ បន្ថែមថ្នាក់</button>
              </div>
            </div>
            <!-- Student screen -->
            <div
              v-else-if="steps[activeStep].screen === 'student'"
              class="screen-mockup"
            >
              <div class="screen-topbar">សិស្ស — ថ្នាក់ ៣-ក</div>
              <div
                class="screen-body"
                style="
                  padding: 16px;
                  gap: 10px;
                  display: flex;
                  flex-direction: column;
                "
              >
                <div class="screen-import-bar">
                  <div class="import-icon">📥</div>
                  <div style="flex: 1">
                    <div
                      style="font-size: 12px; font-weight: 600; color: #1e5fa5"
                    >
                      Import ពី Excel
                    </div>
                    <div style="font-size: 11px; color: #888">
                      ទាញឯកសារគំរូ → បំពេញ → Upload
                    </div>
                  </div>
                  <div
                    style="font-size: 11px; color: #3b6d11; font-weight: 600"
                  >
                    30 នាក់ OK
                  </div>
                </div>
                <div
                  v-for="s in [
                    { name: 'ចាន់ សុភា', gender: 'ប្រុស', dob: '01/03/2012' },
                    { name: 'លី ស្រីមុំ', gender: 'ស្រី', dob: '15/07/2013' },
                    {
                      name: 'ហ៊ិន ពិសិដ្ឋ',
                      gender: 'ប្រុស',
                      dob: '20/11/2012',
                    },
                  ]"
                  :key="s.name"
                  class="student-row"
                >
                  <div class="avatar-sm">{{ s.name[0] }}</div>
                  <div style="flex: 1">
                    <div style="font-size: 12px; font-weight: 600">
                      {{ s.name }}
                    </div>
                    <div style="font-size: 11px; color: #888">
                      {{ s.gender }} · {{ s.dob }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <!-- Teacher screen -->
            <div v-else class="screen-mockup">
              <div class="screen-topbar">Dashboard គ្រូ — ថ្នាក់ ៣-ក</div>
              <div
                class="screen-body"
                style="
                  padding: 16px;
                  gap: 10px;
                  display: flex;
                  flex-direction: column;
                "
              >
                <div class="teacher-cards">
                  <div class="t-card blue">
                    <div class="t-num">30</div>
                    <div class="t-lbl">សិស្ស</div>
                  </div>
                  <div class="t-card green">
                    <div class="t-num">28</div>
                    <div class="t-lbl">មកថ្ងៃនេះ</div>
                  </div>
                  <div class="t-card amber">
                    <div class="t-num">6</div>
                    <div class="t-lbl">មុខវិជ្ជា</div>
                  </div>
                </div>
                <div class="teacher-actions">
                  <div
                    v-for="a in [
                      'Mark វត្តមាន',
                      'បញ្ចូលពិន្ទុ',
                      'ចុះបញ្ជីសុខភាព',
                      'ទំនាក់ទំនង',
                    ]"
                    :key="a"
                    class="teacher-action"
                  >
                    <CheckCircle2 :size="13" color="#3b6d11" /> {{ a }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ MOBILE PREVIEW ════════════════════════════════════════════ -->
    <section class="section mobile-section">
      <div class="section-inner mobile-layout">
        <div class="mobile-copy">
          <div class="section-tag">Mobile Ready</div>
          <h2 class="section-title">ប្រើបានគ្រប់ឧបករណ៍</h2>
          <p class="section-desc" style="text-align: left">
            ប្រព័ន្ធបង្ហាញប្រកបដោយភាពងាយស្រួល លើ Computer, Tablet ឬ Smartphone ។
            គ្រូ mark វត្តមានលើ Phone ក្នុងថ្នាក់ ។ ឪពុកម្តាយ មើលពិន្ទុ
            ពេលណាក៏បាន ។
          </p>
          <ul class="mobile-bullets">
            <li
              v-for="b in [
                'Responsive design — auto-adjust',
                'Touch-friendly buttons',
                'ភាសាខ្មែរ ១០០% គ្រប់ទំព័រ',
                'គ្មាន App install — Chrome/Safari',
              ]"
              :key="b"
            >
              <CheckCircle2 :size="15" color="#3b6d11" /> {{ b }}
            </li>
          </ul>
        </div>
        <!-- Phone mockup -->
        <div class="phone-wrap">
          <div class="phone-frame">
            <div class="phone-notch"></div>
            <div class="phone-screen">
              <div class="phone-header">
                <div style="font-size: 10px; font-weight: 700; color: #1e5fa5">
                  Dashboard — គ្រូ
                </div>
                <div style="font-size: 9px; color: #888">
                  ថ្នាក់ ៣-ក · ព្រឹក
                </div>
              </div>
              <div class="phone-cards">
                <div class="ph-card blue">
                  <div class="ph-num">30</div>
                  <div class="ph-lbl">សិស្ស</div>
                </div>
                <div class="ph-card green">
                  <div class="ph-num">28</div>
                  <div class="ph-lbl">មានវត្តមាន</div>
                </div>
              </div>
              <div class="phone-section">វត្តមានថ្ងៃនេះ</div>
              <div
                v-for="s in [
                  'ចាន់ សុភា',
                  'លី ស្រីមុំ',
                  'ហ៊ិន ពិសិដ្ឋ',
                  'ឈុន ស្រីណាត',
                ]"
                :key="s"
                class="phone-student-row"
              >
                <div class="ph-avatar">{{ s[0] }}</div>
                <span style="font-size: 10px; flex: 1">{{ s }}</span>
                <div class="ph-check">
                  <CheckCircle2 :size="12" color="#3b6d11" />
                </div>
              </div>
              <button class="phone-btn">Mark វត្តមានទាំងអស់</button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ TESTIMONIAL ═══════════════════════════════════════════════ -->
    <section class="section testimonial-section">
      <div class="section-inner">
        <div class="testimonial-card">
          <div class="testimonial-quote">"</div>
          <p class="testimonial-text">
            ប្រព័ន្ធនេះ ជួយសន្សំពេលវេលាបានច្រើន ។ មុននេះ ខ្ញុំត្រូវចំណាយពេល ២-៣
            ម៉ោង ដើម្បីបញ្ចូលពិន្ទុ ។ ឥឡូវ គ្រួ បញ្ចូលហើយ PDF ចេញស្រេច ។
            ភាសាខ្មែរ ១០០% ធ្វើឲ្យគ្រូ ទាំងអស់ ងាយស្រួលប្រើ ។
          </p>
          <div class="testimonial-author">
            <div class="testimonial-avatar">ន</div>
            <div>
              <div class="testimonial-name">
                នាយក នៃ​ សាលាបឋមសិក្សាស្វាយជាតិ
              </div>
              <div class="testimonial-school">ខេត្តបាត់ដំបង · ២០២៤</div>
            </div>
            <div style="margin-left: auto">
              <Star
                v-for="i in 5"
                :key="i"
                :size="16"
                color="#854f0b"
                fill="#854f0b"
              />
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ FAQ ═══════════════════════════════════════════════════════ -->
    <section class="section faq-section">
      <div class="section-inner faq-inner">
        <div class="section-header">
          <div class="section-tag">FAQ</div>
          <h2 class="section-title">សំណួរដែលសួរច្រើន</h2>
        </div>
        <div class="faq-list">
          <div
            v-for="(f, i) in faqs"
            :key="i"
            class="faq-item"
            :class="{ open: activeFaq === i }"
          >
            <button class="faq-q" @click="toggleFaq(i)">
              <span>{{ f.q }}</span>
              <ChevronDown :size="16" class="faq-arrow" />
            </button>
            <div class="faq-a">{{ f.a }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ CONTACT ════════════════════════════════════════════════════ -->
    <section id="contact" class="section contact-section">
      <div class="section-inner">
        <div class="section-header">
          <div class="section-tag light">ទំនាក់ទំនង</div>
          <h2 class="section-title light">ចង់ប្រើប្រព័ន្ធនេះ?</h2>
          <p class="section-desc light">
            ផ្ញើមកយើង — ប្រព័ន្ធ
            <strong>ឥតគិតថ្លៃ</strong> សម្រាប់សាលាបឋមសិក្សារដ្ឋ 🇰🇭
          </p>
        </div>
        <div class="contact-grid">
          <a
            v-for="c in contacts"
            :key="c.name"
            :href="c.link"
            target="_blank"
            class="contact-card"
          >
            <div class="contact-icon" :style="{ background: c.color }">
              <component :is="c.icon" :size="22" />
            </div>
            <div class="contact-name">{{ c.name }}</div>
            <div class="contact-handle">{{ c.handle }}</div>
            <div class="contact-cta">
              {{ c.desc }} <ArrowRight :size="12" />
            </div>
          </a>
        </div>
        <div class="contact-info-box">
          <div class="contact-info-title">📋 ព័ត៌មានដែលត្រូវផ្ញើ</div>
          <div class="contact-info-list">
            <div
              v-for="i in [
                'ឈ្មោះសាលា (ខ្មែរ + អង់គ្លេស)',
                'ស្រុក / ខេត្ត',
                'ឈ្មោះ និង Email របស់នាយក',
              ]"
              :key="i"
              class="contact-info-item"
            >
              <CheckCircle2 :size="14" color="#3b6d11" /> {{ i }}
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══ FOOTER ════════════════════════════════════════════════════ -->
    <footer class="footer">
      <div class="footer-inner">
        <div class="logo">
          <div class="logo-icon small"><GraduationCap :size="16" /></div>
          <div>
            <div class="logo-title sm">ប្រព័ន្ធគ្រប់គ្រងសាលារៀន</div>
            <div class="logo-sub">School Management System</div>
          </div>
        </div>
        <div class="footer-links">
          <a
            v-for="c in contacts"
            :key="c.name"
            :href="c.link"
            target="_blank"
            class="footer-icon-link"
            :style="{ background: c.color }"
          >
            <component :is="c.icon" :size="15" />
          </a>
        </div>
        <div class="footer-copy">រក្សាសិទ្ធិ © ២០២៥ — SMS 🇰🇭</div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
@import url("https://fonts.googleapis.com/css2?family=Kantumruy+Pro:wght@300;400;600;700&display=swap");

/* ── Base ──────────────────────────────────────────────────── */
*,
*::before,
*::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
.landing {
  font-family: "Kantumruy Pro", sans-serif;
  color: #1a1f2e;
  background: #fff;
  overflow-x: hidden;
  opacity: 0;
  transition: opacity 0.5s ease;
}
.landing.visible {
  opacity: 1;
}

/* ── Nav ───────────────────────────────────────────────────── */
.nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(16px);
  border-bottom: 1px solid transparent;
  transition:
    border-color 0.3s,
    box-shadow 0.3s;
}
.nav.scrolled {
  border-color: #e2e8f0;
  box-shadow: 0 1px 12px rgba(0, 0, 0, 0.06);
}
.nav-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.logo {
  display: flex;
  align-items: center;
  gap: 10px;
}
.logo-icon {
  background: #1e5fa5;
  color: #fff;
  width: 36px;
  height: 36px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.logo-icon.small {
  width: 30px;
  height: 30px;
}
.logo-title {
  font-size: 14px;
  font-weight: 700;
  color: #1a1f2e;
  line-height: 1.2;
}
.logo-title.sm {
  font-size: 13px;
}
.logo-sub {
  font-size: 10px;
  color: #94a3b8;
}
.nav-links {
  display: flex;
  align-items: center;
  gap: 8px;
}
.nav-link {
  font-size: 13px;
  font-weight: 600;
  color: #475569;
  text-decoration: none;
  padding: 6px 12px;
  border-radius: 6px;
  transition:
    color 0.2s,
    background 0.2s;
}
.nav-link:hover {
  color: #1e5fa5;
  background: #e6f1fb;
}
.mobile-menu-btn {
  display: none;
  background: none;
  border: none;
  cursor: pointer;
  color: #475569;
  padding: 4px;
}
.mobile-menu {
  display: none;
  flex-direction: column;
  gap: 8px;
  padding: 12px 24px 16px;
  border-top: 1px solid #f1f5f9;
}
.mobile-menu.open {
  display: flex;
}
.mobile-link {
  font-size: 14px;
  font-weight: 600;
  color: #475569;
  text-decoration: none;
  padding: 8px 0;
}

/* ── Buttons ───────────────────────────────────────────────── */
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: #1e5fa5;
  color: #fff;
  border: none;
  border-radius: 8px;
  font-family: "Kantumruy Pro", sans-serif;
  font-size: 13px;
  font-weight: 700;
  padding: 8px 18px;
  cursor: pointer;
  transition:
    background 0.2s,
    transform 0.15s;
}
.btn-primary:hover {
  background: #184d8a;
  transform: translateY(-1px);
}
.btn-primary.btn-lg {
  font-size: 15px;
  padding: 12px 28px;
  border-radius: 10px;
}
.btn-outline {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  color: #475569;
  border: 1.5px solid #cbd5e1;
  border-radius: 10px;
  font-family: "Kantumruy Pro", sans-serif;
  font-size: 15px;
  font-weight: 600;
  padding: 12px 28px;
  cursor: pointer;
  text-decoration: none;
  transition:
    border-color 0.2s,
    color 0.2s;
}
.btn-outline:hover {
  border-color: #1e5fa5;
  color: #1e5fa5;
}
.w-full {
  width: 100%;
  justify-content: center;
}

/* ── Animations ────────────────────────────────────────────── */
.anim-up {
  opacity: 0;
  transform: translateY(24px);
  animation: fadeUp 0.8s cubic-bezier(0.22, 1, 0.36, 1) forwards;
}
@keyframes fadeUp {
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* ── Hero ──────────────────────────────────────────────────── */
.hero {
  position: relative;
  padding: 80px 24px 80px;
  background: linear-gradient(135deg, #f8faff 0%, #eef4fc 50%, #f0f9f4 100%);
  overflow: hidden;
}
.hero-bg-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(30, 95, 165, 0.04) 1px, transparent 1px),
    linear-gradient(90deg, rgba(30, 95, 165, 0.04) 1px, transparent 1px);
  background-size: 40px 40px;
  pointer-events: none;
}
.hero-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 60px;
  align-items: center;
}
.official-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 100px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 600;
  color: #475569;
  margin-bottom: 20px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}
.hero-title {
  font-size: 52px;
  font-weight: 700;
  line-height: 1.1;
  color: #0f172a;
  margin-bottom: 18px;
  letter-spacing: -0.5px;
}
.hero-accent {
  color: #1e5fa5;
}
.hero-desc {
  font-size: 16px;
  color: #475569;
  line-height: 1.8;
  margin-bottom: 28px;
  max-width: 460px;
}
.hero-ctas {
  display: flex;
  gap: 12px;
  margin-bottom: 40px;
  flex-wrap: wrap;
}
.stats-row {
  display: flex;
  gap: 0;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  background: #fff;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
}
.stat-item {
  flex: 1;
  text-align: center;
  padding: 12px 8px;
  border-right: 1px solid #e2e8f0;
}
.stat-item:last-child {
  border-right: none;
}
.stat-num {
  font-size: 18px;
  font-weight: 700;
  color: #1e5fa5;
}
.stat-label {
  font-size: 11px;
  color: #94a3b8;
  margin-top: 2px;
}

/* ── Browser Mockup ────────────────────────────────────────── */
.hero-mockup {
  position: relative;
}
.mockup-browser {
  background: #fff;
  border-radius: 12px;
  border: 1px solid #d1dae8;
  box-shadow:
    0 20px 60px rgba(30, 95, 165, 0.12),
    0 4px 16px rgba(0, 0, 0, 0.06);
  overflow: hidden;
}
.browser-bar {
  background: #f1f5f9;
  border-bottom: 1px solid #e2e8f0;
  padding: 8px 14px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}
.dot-r {
  background: #fc5f57;
}
.dot-y {
  background: #fdbc2c;
}
.dot-g {
  background: #27c840;
}
.browser-url {
  flex: 1;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  padding: 3px 10px;
  font-size: 10px;
  color: #64748b;
  font-family: monospace;
  margin: 0 8px;
}
.mockup-body {
  display: flex;
  height: 340px;
}
.mockup-sidebar {
  width: 120px;
  background: #0f172a;
  padding: 12px 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.sidebar-logo-area {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px 14px;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  margin-bottom: 4px;
}
.sidebar-icon-box {
  background: #1e5fa5;
  border-radius: 4px;
  width: 22px;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
}
.sidebar-item {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 8px 12px;
  font-size: 10px;
  color: rgba(255, 255, 255, 0.5);
  cursor: default;
  border-radius: 0;
  transition: background 0.15s;
}
.sidebar-item.active {
  background: #1e5fa5;
  color: #fff;
}
.mockup-main {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.mockup-topbar {
  padding: 10px 14px;
  border-bottom: 1px solid #f1f5f9;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
}
.mockup-page-title {
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
}
.year-badge {
  font-size: 9px;
  background: #e6f1fb;
  color: #1e5fa5;
  padding: 2px 8px;
  border-radius: 100px;
  font-weight: 600;
}
.mockup-cards {
  display: flex;
  gap: 8px;
  padding: 10px 14px;
}
.mcard {
  flex: 1;
  border-radius: 6px;
  padding: 8px;
  text-align: center;
}
.mcard.blue {
  background: #e6f1fb;
}
.mcard.green {
  background: #eaf3de;
}
.mcard.amber {
  background: #faeeda;
}
.mcard-num {
  font-size: 18px;
  font-weight: 700;
}
.mcard.blue .mcard-num {
  color: #1e5fa5;
}
.mcard.green .mcard-num {
  color: #3b6d11;
}
.mcard.amber .mcard-num {
  color: #854f0b;
}
.mcard-lbl {
  font-size: 9px;
  color: #64748b;
  margin-top: 2px;
}
.mockup-section-title {
  font-size: 10px;
  font-weight: 700;
  color: #64748b;
  padding: 0 14px 6px;
  margin-top: 4px;
}
.attendance-bars {
  padding: 0 14px;
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.att-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.att-lbl {
  font-size: 9px;
  color: #475569;
  width: 48px;
}
.att-track {
  flex: 1;
  height: 5px;
  background: #f1f5f9;
  border-radius: 100px;
  overflow: hidden;
}
.att-fill {
  height: 100%;
  border-radius: 100px;
}
.att-pct {
  font-size: 9px;
  color: #64748b;
  width: 28px;
  text-align: right;
}
.activity-list {
  padding: 0 14px 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.act-row {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 5px 8px;
  background: #f8fafc;
  border-radius: 5px;
}
.act-icon {
  font-size: 11px;
}
.act-text {
  font-size: 9px;
  color: #334155;
  flex: 1;
}
.act-time {
  font-size: 8px;
  color: #94a3b8;
}

/* ── Floating badges ───────────────────────────────────────── */
.float-badge {
  position: absolute;
  display: flex;
  align-items: center;
  gap: 6px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 100px;
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 600;
  color: #334155;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  white-space: nowrap;
}
.float-badge-1 {
  bottom: -14px;
  left: -24px;
}
.float-badge-2 {
  top: -14px;
  right: -16px;
}

/* ── Official banner ───────────────────────────────────────── */
.official-banner {
  background: #0f172a;
  color: #94a3b8;
  padding: 12px 24px;
}
.official-banner-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  font-size: 13px;
}
.official-banner-inner strong {
  color: #e2e8f0;
}

/* ── Sections ──────────────────────────────────────────────── */
.section {
  padding: 80px 24px;
}
.section-inner {
  max-width: 1200px;
  margin: 0 auto;
}
.section-header {
  text-align: center;
  margin-bottom: 52px;
}
.section-tag {
  display: inline-block;
  background: #e6f1fb;
  color: #1e5fa5;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 5px 14px;
  border-radius: 100px;
  margin-bottom: 14px;
}
.section-tag.light {
  background: rgba(255, 255, 255, 0.15);
  color: #fff;
}
.section-title {
  font-size: 36px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 10px;
  line-height: 1.25;
}
.section-title.light {
  color: #fff;
}
.section-desc {
  font-size: 15px;
  color: #64748b;
  max-width: 480px;
  margin: 0 auto;
  line-height: 1.7;
}
.section-desc.light {
  color: rgba(255, 255, 255, 0.75);
}

/* ── Features ──────────────────────────────────────────────── */
.features-section {
  background: #f8faff;
}
.features-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}
.feature-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 28px;
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}
.feature-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.08);
}
.feature-icon {
  width: 48px;
  height: 48px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16px;
}
.feature-title {
  font-size: 15px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 8px;
}
.feature-desc {
  font-size: 13px;
  color: #64748b;
  line-height: 1.7;
}

/* ── How it works ──────────────────────────────────────────── */
.how-section {
  background: #fff;
}
.how-layout {
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 40px;
  align-items: start;
}
.step-nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.step-nav-item {
  display: flex;
  gap: 14px;
  align-items: flex-start;
  padding: 14px 16px;
  border-radius: 10px;
  cursor: pointer;
  border: 1.5px solid transparent;
  transition:
    background 0.2s,
    border-color 0.2s;
}
.step-nav-item:hover {
  background: #f8faff;
}
.step-nav-item.active {
  background: #e6f1fb;
  border-color: #b5d4f4;
}
.step-num {
  font-size: 22px;
  font-weight: 700;
  color: #cbd5e1;
  line-height: 1;
  min-width: 36px;
  transition: color 0.2s;
}
.step-nav-item.active .step-num {
  color: #1e5fa5;
}
.step-name {
  font-size: 14px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 4px;
}
.step-short {
  font-size: 12px;
  color: #64748b;
  line-height: 1.5;
}

/* ── Screen mockups ────────────────────────────────────────── */
.step-screen {
  background: #f8faff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 8px 32px rgba(30, 95, 165, 0.08);
}
.screen-mockup {
  display: flex;
  flex-direction: column;
}
.screen-topbar {
  background: #0f172a;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  padding: 10px 16px;
}
.screen-body {
  background: #fff;
  min-height: 220px;
}
.year-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 12px;
  color: #334155;
  cursor: default;
}
.year-row-active {
  border-color: #1e5fa5;
  background: #e6f1fb;
  color: #1e5fa5;
  font-weight: 600;
}
.badge-active {
  margin-left: auto;
  background: #1e5fa5;
  color: #fff;
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 100px;
}
.screen-btn {
  background: none;
  border: 1.5px dashed #cbd5e1;
  border-radius: 8px;
  padding: 9px;
  width: 100%;
  font-family: "Kantumruy Pro", sans-serif;
  font-size: 12px;
  color: #64748b;
  cursor: pointer;
  transition:
    border-color 0.2s,
    color 0.2s;
}
.screen-btn:hover {
  border-color: #1e5fa5;
  color: #1e5fa5;
}
.class-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px;
  background: #f8fafc;
  border-radius: 8px;
}
.class-icon {
  width: 28px;
  height: 28px;
  background: #e6f1fb;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #1e5fa5;
}
.class-name {
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
}
.class-meta {
  font-size: 10px;
  color: #94a3b8;
}
.badge-turn {
  font-size: 9px;
  background: #eaf3de;
  color: #3b6d11;
  padding: 2px 7px;
  border-radius: 100px;
  font-weight: 600;
}
.screen-import-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  background: #f0f7ff;
  border: 1px solid #b5d4f4;
  border-radius: 8px;
  padding: 10px;
}
.import-icon {
  font-size: 18px;
}
.student-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px;
  border-radius: 6px;
  border: 1px solid #f1f5f9;
}
.avatar-sm {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #e6f1fb;
  color: #1e5fa5;
  font-size: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.teacher-cards {
  display: flex;
  gap: 8px;
}
.t-card {
  flex: 1;
  border-radius: 8px;
  padding: 10px;
  text-align: center;
}
.t-card.blue {
  background: #e6f1fb;
}
.t-card.green {
  background: #eaf3de;
}
.t-card.amber {
  background: #faeeda;
}
.t-num {
  font-size: 20px;
  font-weight: 700;
}
.t-card.blue .t-num {
  color: #1e5fa5;
}
.t-card.green .t-num {
  color: #3b6d11;
}
.t-card.amber .t-num {
  color: #854f0b;
}
.t-lbl {
  font-size: 9px;
  color: #64748b;
}
.teacher-actions {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.teacher-action {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: #334155;
  padding: 8px 10px;
  background: #f8fafc;
  border-radius: 6px;
}

/* ── Mobile section ────────────────────────────────────────── */
.mobile-section {
  background: #f8faff;
}
.mobile-layout {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 60px;
  align-items: center;
}
.mobile-copy .section-tag {
  text-align: left;
  display: inline-block;
}
.mobile-copy .section-title {
  text-align: left;
}
.mobile-bullets {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 20px;
}
.mobile-bullets li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 13px;
  color: #334155;
}
.phone-wrap {
  display: flex;
  justify-content: center;
}
.phone-frame {
  width: 200px;
  background: #0f172a;
  border-radius: 32px;
  padding: 12px 8px;
  box-shadow: 0 24px 64px rgba(15, 23, 42, 0.25);
  position: relative;
}
.phone-notch {
  width: 60px;
  height: 20px;
  background: #0f172a;
  border-radius: 0 0 12px 12px;
  margin: 0 auto 8px;
  position: relative;
  z-index: 2;
}
.phone-screen {
  background: #fff;
  border-radius: 22px;
  padding: 10px;
  min-height: 380px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  overflow: hidden;
}
.phone-header {
  padding-bottom: 6px;
  border-bottom: 1px solid #f1f5f9;
}
.phone-cards {
  display: flex;
  gap: 6px;
}
.ph-card {
  flex: 1;
  border-radius: 8px;
  padding: 8px;
  text-align: center;
}
.ph-card.blue {
  background: #e6f1fb;
}
.ph-card.green {
  background: #eaf3de;
}
.ph-num {
  font-size: 18px;
  font-weight: 700;
}
.ph-card.blue .ph-num {
  color: #1e5fa5;
}
.ph-card.green .ph-num {
  color: #3b6d11;
}
.ph-lbl {
  font-size: 8px;
  color: #94a3b8;
}
.phone-section {
  font-size: 9px;
  font-weight: 700;
  color: #64748b;
}
.phone-student-row {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 5px 6px;
  background: #f8fafc;
  border-radius: 6px;
}
.ph-avatar {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: #e6f1fb;
  color: #1e5fa5;
  font-size: 9px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.ph-check {
  display: flex;
}
.phone-btn {
  margin-top: auto;
  background: #1e5fa5;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 9px;
  font-family: "Kantumruy Pro", sans-serif;
  font-size: 10px;
  font-weight: 700;
  width: 100%;
  cursor: pointer;
}

/* ── Testimonial ───────────────────────────────────────────── */
.testimonial-section {
  background: #0f172a;
}
.testimonial-card {
  max-width: 760px;
  margin: 0 auto;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  padding: 48px;
  position: relative;
}
.testimonial-quote {
  font-size: 80px;
  line-height: 1;
  color: #1e5fa5;
  font-family: Georgia, serif;
  margin-bottom: 16px;
  opacity: 0.6;
}
.testimonial-text {
  font-size: 18px;
  color: #e2e8f0;
  line-height: 1.8;
  margin-bottom: 28px;
}
.testimonial-author {
  display: flex;
  align-items: center;
  gap: 14px;
}
.testimonial-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: #1e5fa5;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.testimonial-name {
  font-size: 13px;
  font-weight: 700;
  color: #fff;
}
.testimonial-school {
  font-size: 12px;
  color: #64748b;
  margin-top: 2px;
}

/* ── FAQ ───────────────────────────────────────────────────── */
.faq-section {
  background: #fff;
}
.faq-inner {
  max-width: 720px;
}
.faq-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.faq-item {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  overflow: hidden;
  transition: border-color 0.2s;
}
.faq-item.open {
  border-color: #b5d4f4;
}
.faq-q {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  background: none;
  border: none;
  cursor: pointer;
  font-family: "Kantumruy Pro", sans-serif;
  font-size: 14px;
  font-weight: 600;
  color: #0f172a;
  text-align: left;
  gap: 12px;
}
.faq-q:hover {
  background: #f8faff;
}
.faq-item.open .faq-q {
  background: #e6f1fb;
  color: #1e5fa5;
}
.faq-arrow {
  transition: transform 0.25s;
  flex-shrink: 0;
}
.faq-item.open .faq-arrow {
  transform: rotate(180deg);
}
.faq-a {
  max-height: 0;
  overflow: hidden;
  font-size: 13px;
  color: #475569;
  line-height: 1.7;
  transition:
    max-height 0.3s ease,
    padding 0.3s ease;
  padding: 0 20px;
}
.faq-item.open .faq-a {
  max-height: 120px;
  padding: 12px 20px 16px;
}

/* ── Contact ───────────────────────────────────────────────── */
.contact-section {
  background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 100%);
}
.contact-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-bottom: 24px;
}
.contact-card {
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  padding: 28px 24px;
  text-decoration: none;
  text-align: center;
  transition:
    background 0.2s,
    transform 0.2s;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}
.contact-card:hover {
  background: rgba(255, 255, 255, 0.12);
  transform: translateY(-3px);
}
.contact-icon {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  margin-bottom: 4px;
}
.contact-name {
  font-size: 16px;
  font-weight: 700;
  color: #fff;
}
.contact-handle {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.5);
}
.contact-cta {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.4);
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 6px;
  transition: color 0.2s;
}
.contact-card:hover .contact-cta {
  color: rgba(255, 255, 255, 0.8);
}
.contact-info-box {
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  padding: 20px 24px;
  max-width: 480px;
  margin: 0 auto;
}
.contact-info-title {
  font-size: 13px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.8);
  margin-bottom: 12px;
}
.contact-info-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.contact-info-item {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.7);
}

/* ── Footer ────────────────────────────────────────────────── */
.footer {
  border-top: 1px solid #f1f5f9;
  background: #fff;
  padding: 24px;
}
.footer-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}
.footer-links {
  display: flex;
  gap: 8px;
}
.footer-icon-link {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  transition: opacity 0.2s;
}
.footer-icon-link:hover {
  opacity: 0.85;
}
.footer-copy {
  font-size: 12px;
  color: #94a3b8;
}

/* ── Responsive ────────────────────────────────────────────── */
@media (max-width: 900px) {
  .hero-inner {
    grid-template-columns: 1fr;
  }
  .hero-mockup {
    display: none;
  }
  .hero-title {
    font-size: 36px;
  }
  .features-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .how-layout {
    grid-template-columns: 1fr;
  }
  .mobile-layout {
    grid-template-columns: 1fr;
  }
  .phone-wrap {
    display: none;
  }
  .contact-grid {
    grid-template-columns: 1fr;
  }
  .nav-links {
    display: none;
  }
  .mobile-menu-btn {
    display: flex;
  }
}
@media (max-width: 600px) {
  .features-grid {
    grid-template-columns: 1fr;
  }
  .hero-title {
    font-size: 30px;
  }
  .section {
    padding: 60px 16px;
  }
  .testimonial-card {
    padding: 28px 20px;
  }
  .testimonial-text {
    font-size: 15px;
  }
}
</style>
