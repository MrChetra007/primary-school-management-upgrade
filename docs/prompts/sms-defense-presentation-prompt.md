# PROMPT FOR GLM 5.2 — Generate a Single-Page Dissertation Defense Presentation

Copy everything below this line into GLM 5.2.

---

You are a senior frontend engineer and presentation designer. Build a **single self-contained HTML file** (all CSS and JS inline, no build step, no external framework) that functions as a **slide-based presentation website** for a university dissertation defense. It will be presented live, on a laptop connected to a projector, by **3 speakers**, in **under 15 minutes total**.

Do not use React, Vue, or any bundler. Do not truncate the output. Do not explain your code outside of it — respond with the complete `index.html` file only.

## 1. Project Being Presented

**Title:** Primary School Management System (SMS) — A Multi-Tenant SaaS Platform for Cambodian Primary Schools

**Context:** Cambodian public primary schools currently run on paper records and manual processes. This system was designed and built as a real, deployed solution — it is **live in production at a primary school in Battambang, Cambodia**, not a mockup or prototype.

**Tech stack:** Vue 3 + Vite + Tailwind CSS (frontend), Supabase/PostgreSQL with Row Level Security (backend), Pinia (state), Chart.js (data viz), PWA via vite-plugin-pwa.

**Key facts to weave into the content (all real, use them accurately):**
- Multi-tenant architecture: every table scoped by `school_id`, with Postgres RLS enforcing tenant isolation — a single codebase serves unlimited schools.
- 5 roles: Super Admin (platform owner), Admin/Director, Teacher, Librarian, and Parent (anonymous, link-only — no login required).
- Core design principle: "every user is a teacher" — in Cambodian schools all staff (director, librarian) are also teachers, so every account has one unified profile record, and the `role` field only controls access, not identity.
- Parent Portal: parents access their child's report card via a private UUID link (no name/DOB search, no login). Only scores + attendance are shown — health, growth, and vaccination records stay private to staff.
- Report Link Approval Flow: teacher requests approval → principal (admin) approves/rejects via an in-app notification system with real-time badge counts → only then can the parent link be shared, and the approved report card carries the principal's digital signature and school stamp.
- Teacher Phrase Library: teachers build a personal, reusable bank of feedback phrases that appear as clickable chips when writing parent messages.
- ~30 database tables, 25+ performance indexes, PWA offline support, bilingual Khmer/English UI, Khmer-digit-aware student rollup automation (`ថ្នាក់ទី១ក` → grade parsing) for automated end-of-year grade promotion.
- Built solo, end-to-end, from schema design through deployment and real teacher training at the pilot school.

Use these facts for actual slide content — do not invent unrelated features, but you may phrase things persuasively for an academic committee audience.

## 2. Presentation Structure (Timed, 3 Speakers, ~13–14 min + buffer)

Build exactly these slides, in this order. Each slide's HTML must include a small, unobtrusive **speaker tag** (e.g. "Speaker 1") and a **target duration** in a corner badge — visible on screen to help pacing but subtle enough not to distract the committee.

**Speaker 1 — Problem & Objectives (~4 min)**
1. Title slide — project name, one-line subtitle, team member names (placeholder names: "Team Member 1", "Team Member 2", "Team Member 3" — make them easy to find/replace), university name placeholder, defense date placeholder.
2. Problem Statement — paper-based records, no software budget in public schools, fragmented health/attendance/score tracking.
3. Objectives & Scope — what the system sets out to solve, who the 5 user roles are.
4. Existing Gap — why generic tools (Excel, paper, generic SIS software) don't fit this context (cost, connectivity, language, multi-tenancy needs).

**Speaker 2 — System Design & Architecture (~5 min)**
5. Tech Stack — visual stack diagram (Vue3/Vite/Tailwind → Supabase/Postgres/RLS).
6. Data Model & Multi-Tenancy — schema scale (~30 tables), the `school_id` isolation pattern, one animated/visual diagram showing school → users → teachers → classes → students hierarchy.
7. Core Design Decision — "every user is a teacher" concept, illustrated simply.
8. Security Model — RLS policy layers per role, anon access scoped strictly to approved report links only (call out that even parents never get a login).

**Speaker 3 — Features, Results & Conclusion (~4–5 min)**
9. Feature Spotlight: Parent Portal — link-only flow, privacy boundaries (what's shown vs. hidden).
10. Feature Spotlight: Approval Flow + Notifications — teacher requests → admin approves → signature/stamp appears, with a simple 3-step visual.
11. Real-World Deployment — live at a Battambang primary school, PWA installable, works low-bandwidth/offline-first.
12. Challenges & Solutions — 2–3 concrete technical challenges (e.g., Khmer digit parsing for rollups, RLS design for anonymous multi-step access) and how they were solved.
13. Future Work — potential NGO/government partnerships (placeholders: MoEYS, UNICEF Cambodia, etc.), roadmap ahead.
14. Thank You / Q&A — clean closing slide, all 3 team member names again, contact placeholder.

Include a compact **agenda/overview slide** logic via an on-screen slide counter (e.g. "Slide 6 / 14") rather than a separate agenda slide, to save time.

## 3. Visual Design System (set these exactly)

**Color palette (CSS custom properties in `:root`):**
```css
--color-primary: #0F2C59;      /* deep academic navy — headers, backgrounds */
--color-primary-light: #1E4B8F;
--color-accent: #F2B705;       /* warm gold — highlights, CTAs, active states */
--color-accent-soft: #FCE7A8;
--color-secondary: #14B8A6;    /* teal — secondary highlights, icons, charts */
--color-bg: #F8FAFC;           /* slide background, light mode */
--color-surface: #FFFFFF;      /* cards/panels */
--color-text: #16213E;         /* primary text on light backgrounds */
--color-text-muted: #5B6B8C;
--color-text-inverse: #F8FAFC; /* text on navy backgrounds */
--color-border: #E2E8F0;
```
Use the navy as the dominant slide background for title/section-break slides (white text), and the light background for content-heavy slides (dark text), alternating deliberately so the deck has visual rhythm rather than being monotone.

**Typography:**
- Headings: `'Poppins', sans-serif` — weight 600–700, slightly tight letter-spacing.
- Body/UI text: `'Inter', sans-serif` — weight 400–500.
- Khmer text (used sparingly for terms like ថ្នាក់ទី១ក or captions): `'Noto Sans Khmer', sans-serif`.
- Load all three from Google Fonts CDN in the `<head>`.
- Type scale: H1 ~clamp(2.5rem, 5vw, 4rem), H2 ~clamp(1.75rem, 3vw, 2.5rem), body ~1.125rem, small/meta ~0.85rem.

**Layout:**
- 16:9 slide canvas, full viewport, one slide visible at a time, centered content with generous padding (`clamp` based, responsive).
- Consistent slide "chrome": slide number bottom-right, thin progress bar along the very top or bottom edge that fills as the deck advances, subtle team/speaker tag top-left.

## 4. Motion & Interaction Design

- **Slide transitions:** smooth cross-fade + slight vertical slide (translateY 20px → 0) on slide change, ~450ms, `cubic-bezier(0.22, 1, 0.36, 1)` easing.
- **Content entrance:** stagger-in bullet points and cards (each child delayed ~80–120ms after the previous) using CSS animations triggered when a slide becomes active — not on page load.
- **Micro-interactions:** buttons/nav dots scale slightly on hover (transform: scale(1.05)), active nav dot pulses with the accent gold color.
- **One signature animated diagram:** on the architecture/data-model slide, animate the hierarchy diagram (school → users → teachers → classes → students) drawing itself in sequence (e.g., nodes fade/scale in one after another, connecting lines draw via stroke-dashoffset if using SVG).
- **Respect `prefers-reduced-motion: reduce`** — fall back to instant/opacity-only transitions for that media query.
- Keep animations subtle and fast — this is an academic defense, not a marketing site. No bouncy/playful easing, no confetti, no gimmicks.

## 5. Navigation & Presenter Tools

Implement in vanilla JS:
- **Keyboard:** Right arrow / Space → next slide, Left arrow → previous slide, `Home`/`End` → first/last slide, `O` → toggle an overview grid (small thumbnails of all slides, click to jump).
- **Click navigation:** small dot/number indicator at the bottom, click any dot to jump directly.
- **On-screen countdown timer:** a small persistent timer in a corner that counts down from 15:00 once the presenter starts it (a discreet "Start" control on the title slide, and a "Reset" in the overview). Turn the timer text/badge to the accent gold at 3 minutes remaining and to a warm red tone at 1 minute remaining.
- **Fullscreen toggle** button (uses the Fullscreen API) for projector use.
- Do **not** use `localStorage`/`sessionStorage` — keep all state (current slide, timer) in JS variables only, since this must work reliably as a standalone file opened directly in a browser.

## 6. Content Details Per Slide

For each slide, include real, specific bullet text (not lorem ipsum) based on Section 1's facts above — concise, presentation-appropriate phrasing (short phrases, not paragraphs; a committee will be listening, not reading). Where a diagram is described (architecture, data hierarchy, approval flow), render it as inline SVG or styled HTML/CSS boxes with connecting lines — do not use an external image.

Include 2–3 simple animated stat counters somewhere in the deck (e.g., "30+ database tables", "5 user roles", "1 live deployment") that count up from 0 when their slide becomes active.

## 7. Technical Requirements

- Single `index.html` file, fully self-contained except for the Google Fonts CDN link.
- Fully responsive: must degrade gracefully on a laptop screen (not just projector 16:9) for rehearsal.
- Print-friendly fallback: `@media print` rules that stack all slides vertically, one per page, in case the committee wants a printed handout.
- Clean, commented code, organized into clear sections (`/* ===== COLORS ===== */`, `/* ===== SLIDE BASE ===== */`, `// ===== NAVIGATION ===== `, etc.).
- No console errors, no broken layout at 1280×720, 1920×1080, and 1366×768 (common projector/laptop resolutions).
- Accessible: sufficient color contrast (navy/white and dark-text/light-bg pairs should meet WCAG AA), semantic headings per slide, visible focus states for keyboard nav.

## 8. Output

Respond with **only the complete HTML file**, starting with `<!DOCTYPE html>`, nothing else — no preamble, no markdown fences, no explanation.
