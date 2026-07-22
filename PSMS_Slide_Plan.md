# PSMS Thesis Defense — Slide-by-Slide Plan

**File:** `PSMS_Thesis_Defense.pptx`
**Total slides:** 20 (14 timed + 1 divider + 5 appendix + folded into Thank You)
**Time budget:** 15 minutes for 3 presenters
**Theme:** Midnight Executive (navy `1E2761` / ice blue `CADCFC` / white / amber accent `E8A33D`)

---

## How to use this document

- Slides **1–13** are the timed defense flow — rehearse these to the clock.
- Slide **14** is a divider — skip it in the timed run-through.
- Slides **15–19** are **appendix / Q&A backup** — only open these if a reviewer asks about that specific mechanism. Don't present them proactively.
- Slide **20** (Thank You) closes the timed flow and opens the floor.
- Each slide below lists: presenter, time budget, what's on the slide, and the full speaker notes (already embedded in the file's Notes panel — open Presenter View to see them live).

---

## TIMED FLOW (Slides 1–13, ~13 minutes)

### Slide 1 — Title
**Presenter:** Whole team (Person 1 opens) · **Time:** ~30 sec

- Dark navy split-panel title slide
- "PRIMARY SCHOOL MANAGEMENT SYSTEM"
- Subtitle: "An offline-first management platform for a Cambodian primary school"
- "THESIS DEFENSE · National University of Battambang · 2026"
- Team card on the right — **placeholder names to fill in**: `[ Team Member 1 / 2 / 3 ]`

**Say:** Your names, university, and one sentence on what the system is.

**Before defense day:** Replace the 3 placeholder names with real ones (also on Slide 20).

---

### Slide 2 — The Problem
**Presenter:** Person 1 · **Time:** ~45 sec

- Title: "School records are still paper-based and disconnected"
- 4 problem bullets: no parent visibility, fragile record-keeping, unreliable rural internet, no cross-role visibility
- **Image placeholder** (right side): photo of paper record books / rural classroom — swap in a real photo

**Say:** Ground the problem in the real Battambang school context before jumping to the solution.

---

### Slide 3 — Core Design Decision
**Presenter:** Person 1 · **Time:** ~60 sec (your most important slide)

- Title: "Every user IS a teacher"
- Left: explanation paragraph + a dark callout box quoting the schema constraint (`teachers.user_id is NOT NULL UNIQUE`)
- Right: vertical flow diagram — `auth.users → public.users → teachers → classes → students`

**Say:** This is your most distinctive architectural choice. Explain *why* (every staff member in a Cambodian school is a teacher by training) before *how* (the schema enforces it, not just the UI). Expect a direct committee question here.

---

### Slide 4 — Tech Stack
**Presenter:** Person 1 · **Time:** ~30 sec

- 6 cards in a 3×2 grid: Vue 3, Vite, Tailwind CSS, Supabase, Pinia, PWA/vite-plugin-pwa
- Each card: colored initial-letter badge + name + one-line purpose

**Say:** Move quickly — this is reference material, not a talking point unless asked.

---

### Slide 5 — System Scope
**Presenter:** Person 1 · **Time:** ~30 sec

- 4 large stat circles: **5** user roles, **28+** database tables, **~80** source files, **1** live school (Battambang)
- Caption line listing all 5 roles by name

**Say:** Let the numbers land — this is a credibility slide, don't rush past it silently.

---

### Slide 6 — Academic Year Navigation Model
**Presenter:** Person 2 · **Time:** ~40 sec

- Horizontal 4-step flow diagram: **Academic Year → Dashboard → Classes → Students**
- Caption: everything downstream (scores, attendance, health) is scoped to the selected academic year

**Say:** Quick model explanation before diving into feature deep dives.

---

### Slide 7 — Offline-First Score Entry
**Presenter:** Person 2 · **Time:** ~60 sec (your strongest technical story)

- Left: explanation of why (rural teachers lose connectivity mid-class) + 3 supporting bullets (banner, auto-sync, deliberately scoped)
- Right: **image placeholder** — swap in a screenshot of the offline banner + score entry grid

**Say:** Explain the *why* (rural connectivity) before the *how*. This is your best differentiator — don't undersell it.

---

### Slide 8 — Parent Portal Approval Flow
**Presenter:** Person 2 · **Time:** ~50 sec

- Horizontal 4-step flow: **Teacher requests → Admin reviews → Link unlocks → Parent views**
- Caption: health/growth/vaccination data is never exposed through this link
- **Image placeholder** below: parent report card with signature + stamp footer

**Say:** Emphasize the privacy boundary — committees respond well to hearing you thought about data exposure deliberately.

---

### Slide 9 — Live Demo / Screenshots
**Presenter:** Person 2 · **Time:** ~60–90 sec

- 2×2 grid of **image placeholders**: score entry (compact mode), parent report card, notification bell + approvals, offline banner + sync toast

**Say/Do:** Either click through the real app live here, or use these screenshots if Wi-Fi is a risk on the day.

**Before defense day:** Fill all 4 placeholders with real screenshots, or delete this slide if doing a live click-through instead.

---

### Slide 10 — Role-Based Security
**Presenter:** Person 3 · **Time:** ~50 sec

- 4 checkmark rows: Row-Level Security, role scoping (teacher sees own class only), narrow anon access (scoped to `report_link_id`), pending/rejected links hidden from anon
- **Image placeholder** (right): diagram of RLS policy scoping roles/anon

**Say:** Expect a question on what stops a teacher from seeing another class's data — this slide is your answer. (Deliberately scoped to *role-based* security, not multi-school isolation — see note on Slide 13.)

---

### Slide 11 — Engineering Maturity (Before/After)
**Presenter:** Person 3 · **Time:** ~55 sec

- Two-column comparison card
- **Before** (red-tinted): 28 duplicate toast implementations, silent PWA auto-update, session lost on restart, offline queue unscoped across attendance + scores
- **After** (navy): single `useToast` composable, prompt-based update flow, session persistence fix, offline queue scoped deliberately to scores

**Say:** This slide shows judgment, not just feature count. Walk through *why* each fix mattered, not just what changed.

---

### Slide 12 — Current Status
**Presenter:** Person 3 · **Time:** ~25 sec

- Dark full-bleed statement slide: "Live and in active testing at a real primary school in Battambang."
- Subtext: Phase 8 — Stabilize & Polish; real teachers using the offline-aware workflow

**Say:** Say this plainly and let it land. "Live at a real school" is your single strongest credibility line — don't rush it.

---

### Slide 13 — Honest Roadmap
**Presenter:** Person 3 · **Time:** ~40 sec

- 4 arrow-bullet gaps: form validation consistency, extending the offline queue to more modules, offline conflict resolution, mobile/tablet polish
- Navy **"Looking Ahead"** callout box: the system is built for one school today; multi-school support is a deliberate future scaling step, not a current gap (the schema was designed with it in mind)

**Say:** Be upfront — committees respect honesty about what's unfinished far more than pretending it's done. The closing line frames multi-school support as a *choice*, not something you failed to finish.

---

## APPENDIX (Slides 14–19 — Q&A backup only)

### Slide 14 — Appendix Divider
Dark slide marking the transition. Skip in the timed run-through.

---

### Slide 15 — How the Report Link Works
**Open if asked:** "How does the parent link actually work / how is it secured?"

- 5-point mechanism walkthrough: request → DB trigger → notification → approval → UUID-as-token → RLS enforcement
- Code block: the actual RLS policy (SQL) restricting anon reads to `status = 'approved'`
- Pre-loaded honest answer: forwarding the link still works — no expiry/PIN yet, same tradeoff as a private video link

---

### Slide 16 — How Offline Auth Works
**Open if asked:** "How does the app stay logged in without internet?"

- 4-point walkthrough: session stored in `localStorage` → `INITIAL_SESSION` event on boot → the bug (event was ignored, timing gap) → the fix (handle it directly)
- Code block: the corrected `handleAuthEvent` function
- Pre-loaded honest answer: survives an app restart, not an expired token with no network

---

### Slide 17 — How the Offline Score Queue Works
**Open if asked:** "How does offline score saving work technically?"

- 5-point walkthrough: `useNetworkStatus` → `mutate()` wrapper → online passthrough vs. offline enqueue → FIFO sync on reconnect
- Code block: the `mutate()` function's online/offline branch
- Pre-loaded honest answer: same record edited offline on two devices isn't resolved yet — listed roadmap gap

---

### Slide 18 — How Voice Replies Work
**Open if asked:** "How do the voice messages work?"

- 5-point walkthrough: `MediaRecorder` API → `.webm` Blob → Storage upload → saved into `report_messages` → same composable for teacher notes and parent replies
- Code block: the recorder composable's stop/upload logic
- Note on *why*: removes the typing barrier for parents uncomfortable writing about their child's schoolwork

---

### Slide 19 — How the PWA Install Works
**Open if asked:** "Is this a real app? How does the download/install work?"

- 5-point walkthrough: `vite-plugin-pwa` generates manifest + service worker → installable from browser → app shell precached → Storage assets cached 30 days → updates require explicit user click (`registerType: 'prompt'`)
- Code block: the Vite PWA config + update-prompt hook
- Pre-loaded honest answer: it's a PWA, not a native app — installable from the browser, no app store, no APK to distribute

---

## Slide 20 — Thank You / Q&A
**Presenter:** Whole team · **Time:** open floor

- Dark split-panel closing slide, mirrors Slide 1
- "Thank You" / "Questions & Discussion"
- Team names — **same placeholders to fill in**

**Routing:** Architecture questions → Person 1. Feature/UX questions → Person 2. Security/engineering questions → Person 3.

**Speaker notes include a pre-loaded answer** for "Why Supabase over a custom Node/Express backend?" — RLS gives database-level security without hand-writing auth middleware, and it fit a realistic solo/small-team build timeline.

---

## Before defense day — checklist

- [ ] Replace `[ Team Member 1/2/3 ]` placeholders on Slides 1 and 20
- [ ] Replace 8 dashed image placeholders with real screenshots/photos (Slides 2, 7, 8, 9 ×4, 10)
- [ ] Apply a transition in PowerPoint: **Design → Transitions → Fade or Morph → Apply to All**
- [ ] Rehearse Slides 1–13 to the clock (~13 min, leaves ~2 min buffer)
- [ ] Skim Slides 15–19 once so you can navigate to the right one quickly if asked — you don't need to memorize the code verbatim, just recognize your own architecture
- [ ] Confirm who's answering what before walking in (see routing note under Slide 20)
