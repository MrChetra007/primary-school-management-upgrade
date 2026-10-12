# Landing Page Prompt — School Management System

Design a modern, high-converting landing page for a **Primary School Management System** built for Cambodian schools. The page should feel professional, trustworthy, and warm — appealing to school directors, teachers, and administrators.

---

## Brand Identity

- **Product Name:** School Management System (SMS)
- **Tagline:** "All-in-one digital school management for Cambodian primary schools"
- **Primary Color:** Deep blue `#1e5fa5` — conveys trust, education, professionalism
- **Secondary Color:** Emerald green `#16a34a` — success, growth, passing grades
- **Accent:** Amber `#f59e0b` — warnings, highlights
- **Font:** Clean, modern sans-serif (Inter or Noto Sans Khmer for bilingual support)
- **Tone:** Professional, warm, modern, reliable

---

## Sections & Content

### 1. Navigation Bar (sticky, glassmorphism)
- Logo: A simple graduation cap + book icon (SVG style) in blue
- Nav links: Features · Solutions · Pricing · Contact
- CTA button: "ចាប់ផ្តើមប្រើប្រាស់" (Get Started) — blue with hover lift effect
- Mobile: Hamburger menu with smooth slide-in drawer
- **Animation:** Nav bar has subtle backdrop-blur on scroll, nav links have underline hover animation

### 2. Hero Section (full-viewport height)
- **Layout:** Split left-right
- **Left side:**
  - Headline: "គ្រប់គ្រងសាលារៀនឌីជីថល" / "Digital School Management, Made Simple"
  - Subheadline: "From attendance to report cards, manage your entire school in one platform. Built for Cambodian primary schools."
  - Two CTA buttons:
    - Primary: "ចាប់ផ្តើមឥឡូវនេះ" (Start Now) — blue button with arrow icon
    - Secondary: "មើលវីដេអូ" (Watch Demo) — ghost button with play icon
  - Social proof: "សាលារៀនជាង ៥០ កំពុងប្រើប្រាស់" (50+ schools using it) with small avatar circles
- **Right side:**
  - Dashboard mockup image showing:
    - A tablet/screen displaying colorful analytics charts
    - Student attendance grid
    - Score table with grades A-F colored badges
    - The UI should look modern with sidebar navigation
  - **Animation:** The mockup floats gently (subtle Y-axis hover), a glowing blue gradient orb behind it
  - Background: Soft radial gradient from blue to white
  - **Transition:** Content fades in + slides up on page load with staggered timing (headline → subheadline → buttons → image)

### 3. Feature Section — "អ្វីដែលយើងផ្តល់ជូន" (What We Offer)
- **Layout:** 3-column card grid with 6 feature cards (2 rows)
- **Card design:** White card, subtle shadow, rounded corners (12px), hover lift animation (+ translateY -4px + shadow deepen)
- **Features (each with a colored icon):**

  | Feature | Icon | Color | Description |
  |---------|------|-------|-------------|
  | Student Management | Users icon | Blue | Register, track, and manage student profiles, health records, and growth charts |
  | Score & Ranking | BarChart3 icon | Emerald | Monthly & semester score entry with auto-ranking and PDF report cards |
  | Attendance Tracking | Calendar icon | Amber | Daily attendance marking with real-time stats and auto-calculated rates |
  | Library Management | BookOpen icon | Purple | Book catalog, borrow/return tracking, and overdue alerts |
  | Budget & Inventory | ShieldCheck icon | Teal | Track school finances and inventory with running balance |
  | Parent Reports | GraduationCap icon | Pink | Share report cards via link — no login needed, principal approval workflow |

- **Animation:** Cards stagger-fade-in on scroll (intersection observer), icon has subtle pulse on hover

### 4. How It Works — "របៀបប្រើប្រាស់" (How It Works)
- **Layout:** Horizontal timeline with 4 steps connected by a dashed line
- **Steps:**
  1. **Create Academic Year** — Set up your school year and classes
  2. **Add Students & Teachers** — Import from Excel or add manually
  3. **Track Daily Activities** — Mark attendance, enter scores, manage library
  4. **Generate Reports** — Print report cards, share parent links, export PDFs
- Each step has a numbered circle (1-4) with a small illustration icon
- **Animation:** Steps animate in sequentially as user scrolls, the connecting line draws progressively

### 5. Role-Based Features — "សម្រាប់អ្នកណាខ្លះ?" (Who Is It For?)
- **Layout:** 4 tab-style cards side by side
- **Roles:**
  - 👨‍💼 **Admin/Director** — Full control: users, classes, budget, approvals, reports
  - 👩‍🏫 **Teacher** — Score entry, attendance, health records, student messages
  - 📚 **Librarian** — Books, borrows, overdue tracking
  - 👨‍👩‍👧 **Parent** — View report cards via link, voice messages, teacher replies
- Each card has a role-specific illustration/icon, role name, key features bullet list
- **Animation:** Cards have hover scale effect, active card has a colored top border matching role

### 6. Stats Counter Section — "ដោយលេខ" (By the Numbers)
- **Layout:** Full-width colored section (blue gradient background) with 4 large numbers
- **Stats (animated counters):**
  - ៥០+ Schools
  - ៥០០+ Teachers
  - ១០,០០០+ Students  
  - ៩៩.៩% Uptime
- **Animation:** Numbers count up on scroll (0 → target), each stat has a small icon above it
- Background: subtle wave pattern or geometric dots overlay

### 7. Testimonials Section — "អ្វីដែលអតិថិជននិយាយ" (What Clients Say)
- **Layout:** Carousel/slider with 3 testimonial cards
- Each card: Avatar (circular), name, school name, quote in speech marks
- Example quote: *"This system has transformed how we manage our school. Score entry that used to take days now takes hours."*
- **Animation:** Auto-scroll carousel with pause-on-hover, smooth slide transition, active dot indicator

### 8. CTA Section — "ត្រៀមខ្លួនហើយឬនៅ?" (Ready to Get Started?)
- **Layout:** Centered content with large heading
- Headline: "ត្រៀមខ្លួនហើយឬនៅ? ចាប់ផ្តើមថ្ងៃនេះ" 
- Subheadline: "សាកល្បងប្រើប្រាស់ដោយឥតគិតថ្លៃ" (Free trial)
- CTA: Large blue button "ចុះឈ្មោះប្រើប្រាស់" (Register Now)
- Below: tiny text "No credit card required · Free setup support"
- **Animation:** Subtle pulse glow on the CTA button, background has floating geometric shapes

### 9. Footer
- **Layout:** 4-column grid
- Column 1: Logo + short description + social media icons (Facebook, Telegram, YouTube)
- Column 2: Product links (Features, Pricing, FAQ)
- Column 3: Support (Contact, Help Center, Privacy Policy)
- Column 4: Contact (Email, Phone, Address in Cambodia)
- Bottom bar: "© 2026 School Management System. All rights reserved."

---

## Design & Visual Guidelines

### Color Palette
```css
--primary-500: #1e5fa5;
--primary-700: #184d8a;
--success: #16a34a;
--warning: #f59e0b;
--danger: #dc2626;
--bg-light: #f8fafc;
--text-primary: #1e293b;
--text-secondary: #64748b;
```

### Animations & Transitions
- Page load: Staggered fade-in + slide-up for hero elements (0.2s delay between each)
- Scroll reveal: `fade-in-up` animation with Intersection Observer (0.6s duration, ease-out)
- Hover effects: Cards lift (`translateY(-4px)`) + shadow deepen (`box-shadow` transition 0.3s)
- Button hover: Slight scale (1.03) + brighter color
- Navigation: Backdrop-blur activates on scroll, links have underline slide-in on hover
- Counters: Animated counting with `requestAnimationFrame` easing
- Testimonial carousel: Auto-slide every 4s with CSS scroll-snap
- Mobile menu: Slide-in from right with backdrop blur overlay

### Images & Illustrations Needed
1. **Hero mockup** — A browser/tablet frame showing the admin dashboard with colorful charts, a sidebar, and a score table. Modern UI, not a real screenshot but a polished design mockup
2. **Feature illustrations** — Simple 2D illustrations (or SVG icons) for each of the 6 features:
   - Students: A group of diverse children
   - Scores: A clipboard with A+ grade
   - Attendance: A calendar with checkmarks
   - Library: A bookshelf with open book
   - Budget: A piggy bank or coins
   - Parents: A family with a report card
3. **Step icons** for How It Works section (calendar, people, chart, document)
4. **Role illustrations** — Simple character illustrations for Admin, Teacher, Librarian, Parent
5. **Hero background** — Subtle grid pattern or soft gradient with abstract shapes
6. **Divider graphics** — Wave SVG separators between sections (optional)
7. **Footer logo** — Graduation cap + book combination mark

### Responsive Breakpoints
- Desktop: 1200px+ — full layout with all columns
- Tablet: 768–1199px — features go to 2 columns, cards resize
- Mobile: <768px — everything stacks vertically, hamburger menu, smaller text

---

## Technical Notes for Generation

- Generate as a **single HTML file** with embedded CSS + JS
- Use **CSS variables** for theming
- Animations should use **CSS `@keyframes`** + **Intersection Observer API** for scroll reveals
- Smooth scrolling for anchor links
- Testimonial carousel should be pure CSS (no library needed)
- Counter animation uses vanilla JS with `requestAnimationFrame`
- All text should be in **English** (the brand can have Khmer subtext but English is primary)
- The page should score well on Lighthouse (performance, accessibility)
- Favicon: graduation cap emoji or simple icon
